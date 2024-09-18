import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heritage/api.dart';

class Node {
  final Id id;
  final List<Node> parents;
  final List<Node> spouses;
  final List<Node> children;
  final List<Id> parentIds;
  final List<Id> spouseIds;
  final List<Id> childIds;
  final Id addedBy;
  final Id? ownedBy;
  final DateTime createdAt;
  final Profile profile;
  bool leadsToFocalNode;
  bool shouldBeRightChild;
  bool shouldTraverseChildren;

  Node({
    required this.id,
    required this.parents,
    required this.spouses,
    required this.children,
    required this.parentIds,
    required this.spouseIds,
    required this.childIds,
    required this.addedBy,
    required this.ownedBy,
    required this.createdAt,
    required this.profile,
    this.leadsToFocalNode = false,
    this.shouldBeRightChild = true,
    this.shouldTraverseChildren = true,
  });

  Node? get spouse => spouses.firstOrNull;

  @override
  String toString() => 'Node $id';
}

class Profile {
  final String name;
  final Gender gender;
  final DateTime? birthday;

  Profile({
    required this.name,
    required this.gender,
    required this.birthday,
  });
}

class Couple {
  final String id;
  final List<Couple> parents;
  final List<Couple> children;
  final Node node;
  final Node? spouse;

  Couple({
    required this.id,
    required this.parents,
    required this.children,
    required this.node,
    required this.spouse,
  });

  bool get leadsToFocalNode => node.leadsToFocalNode;

  String? get firstParentId => parents.isEmpty
      ? null
      : parents.length == 1
          ? parents[0].id
          : parents[0].id.compareTo(parents[1].id) == -1
              ? parents[0].id
              : parents[1].id;

  @override
  String toString() => 'Couple $id/${spouse?.id ?? '-'}';
}

/// Roots and their distance away from the given [node].
Set<(Node, int)> findRootsIncludingSpousesWithDistance(Node node) {
  Set<(Node, int)> traverse(Node node, int distance) {
    if (node.parents.isEmpty) {
      return {(node, distance)};
    }

    final roots = <(Node, int)>{};
    for (final parent in node.parents) {
      roots.addAll(traverse(parent, distance + 1));
    }
    return roots;
  }

  return traverse(node, 0);
}

/// Roots and their distance away from the given [couple].
Set<(Couple, int)> findRootCouplesWithDistance(Couple couple) {
  Set<(Couple, int)> traverse(Couple couple, int distance) {
    if (couple.parents.isEmpty) {
      return {(couple, distance)};
    }

    final roots = <(Couple, int)>{};
    for (final parent in couple.parents) {
      roots.addAll(traverse(parent, distance + 1));
    }
    return roots;
  }

  return traverse(couple, 0);
}

/// Set of nodes with no parents.
Set<Node> findRoots(Node node) {
  final spouse = node.spouses.firstOrNull;
  if (spouse != null && node.parents.isEmpty && spouse.parents.isEmpty) {
    return {node};
  }

  final roots = <Node>{};
  for (final parent in node.parents) {
    roots.addAll(findRoots(parent));
  }
  return roots;
}

/// Set of nodes with no parents.
Set<Couple> findCoupleRoots(Couple couple) {
  final roots = <Couple>{};
  for (final parent in couple.parents) {
    roots.addAll(findCoupleRoots(parent));
  }
  return roots;
}

/// Set of nodes with no parents.
void markAncestorCouplesWithSeparateRoots(Node node) {
  final spouse = node.spouses.firstOrNull;
  final alreadyMarkedAsSpouse = node.shouldTraverseChildren == false;
  if (spouse != null &&
      spouse.parents.isNotEmpty &&
      node.parents.isNotEmpty &&
      !alreadyMarkedAsSpouse) {
    spouse.shouldTraverseChildren = false;
  }

  // No more ancestors for either partner
  if (spouse != null && node.parents.isEmpty && spouse.parents.isEmpty) {
    return;
  }

  for (final parent in node.parents) {
    markAncestorCouplesWithSeparateRoots(parent);
  }
}

/// The height of the tree starting at [root].
int findHeight(Node root) {
  if (root.children.isEmpty) {
    return 1;
  }

  int maxChildDepth = 0;
  for (var child in root.children) {
    maxChildDepth = max(maxChildDepth, findHeight(child));
  }
  return 1 + maxChildDepth;
}

/// The height of the tree starting at [root].
int findCoupleHeight(Couple root) {
  if (root.children.isEmpty) {
    return 1;
  }

  int maxChildDepth = 0;
  for (var child in root.children) {
    maxChildDepth = max(maxChildDepth, findCoupleHeight(child));
  }
  return 1 + maxChildDepth;
}

/// The list of nodes at each level, starting from [root].
List<List<Node>> getNodesAtEachLevel(Node root) {
  final nodesByDepth = <List<Node>>[];

  void traverse(Node currentNode, int depth) {
    if (nodesByDepth.length == depth) {
      nodesByDepth.add([]);
    }
    nodesByDepth[depth].add(currentNode);
    for (var child in currentNode.children) {
      traverse(child, depth + 1);
    }
  }

  traverse(root, 0);
  return nodesByDepth;
}

Node findHighestRoot(Node focal) {
  final topNodes = findRoots(focal);

  int maxHeight = 0;
  Node? highestNode;
  for (final node in topNodes) {
    final height = findHeight(node);
    if (height > maxHeight) {
      highestNode = node;
    }
  }
  return highestNode ?? focal;
}

Couple findHighestCoupleRoot(Couple focal) {
  final roots = findCoupleRoots(focal);

  int maxHeight = 0;
  Couple? highest;
  for (final couple in roots) {
    final height = findCoupleHeight(couple);
    if (height > maxHeight) {
      highest = couple;
    }
  }
  return highest ?? focal;
}

List<LevelGroupCouples> getLevelsBySiblingCouples(Couple focal) {
  final rootsAndDistances = findRootCouplesWithDistance(focal);
  final furthest = rootsAndDistances.reduce((a, b) => a.$2 > b.$2 ? a : b);
  final rootCouple = furthest.$1;
  final maxDistance = furthest.$2;
  final rootCoupleLevels =
      rootsAndDistances.map((e) => (e.$1, maxDistance - e.$2));
  final treeHeight = findCoupleHeight(rootCouple);
  final levelGroups = List.generate(treeHeight, (_) => <GroupCouple>[]);

  void traverseLevel(List<Couple> currentLevelCouples, int level) {
    if (currentLevelCouples.isEmpty) {
      return;
    }

    final groups = <GroupCouple>[];
    final nextLevelCouples = <Couple>[];

    for (final couple in currentLevelCouples) {
      // Adds root couples (no siblings)
      if (couple.parents.isEmpty) {
        levelGroups[level].add([couple]);
      }

      if (couple.children.isNotEmpty) {
        // Adds sibling group couples
        final children = <Couple>[];
        for (final child in couple.children) {
          // Only one parent couple should add this child
          if (child.parents.isNotEmpty &&
              couple.id.compareTo(child.firstParentId!) <= 0) {
            children.add(child);
          }
        }
        groups.add(children);
        nextLevelCouples.addAll(children);
      }
    }

    if (groups.isNotEmpty) {
      levelGroups[level + 1].addAll(groups);
    }

    // Add root nodes at the next level
    final niblingCouples = rootCoupleLevels
        .where((e) => e.$2 == level + 1)
        .map((e) => e.$1)
        .toList();
    nextLevelCouples.addAll(niblingCouples);

    traverseLevel(nextLevelCouples, level + 1);
  }

  // Add root nodes at the next level
  const level = 0;
  final level0RootCouples =
      rootCoupleLevels.where((e) => e.$2 == level).map((e) => e.$1).toList();
  traverseLevel(level0RootCouples, level);

  return levelGroups;
}

List<LevelSiblings> getLevelsBySiblings(Node focal) {
  final rootsAndDistances = findRootsIncludingSpousesWithDistance(focal);
  final furthest = rootsAndDistances.reduce((a, b) => a.$2 > b.$2 ? a : b);
  final rootNode = furthest.$1;
  final maxDistance = furthest.$2;
  final rootNodeLevels =
      rootsAndDistances.map((e) => (e.$1, maxDistance - e.$2));
  final realRootNodeLevels = rootNodeLevels.where((e) =>
      e.$1.parents.isEmpty && e.$1.spouses.expand((e) => e.parents).isEmpty);
  final treeHeight = findHeight(rootNode);
  final levelGroups = List.generate(treeHeight, (_) => <Group>[]);

  void traverseLevel(List<Node> currentLevelNodes, int level) {
    if (currentLevelNodes.isEmpty) {
      return;
    }

    final groups = <Group>[];
    final nextLevelNodes = <Node>[];

    for (final node in currentLevelNodes) {
      if (node.children.isNotEmpty) {
        groups.add(node.children);
      }
      nextLevelNodes.addAll(node.children);
    }

    if (groups.isNotEmpty) {
      levelGroups[level + 1].addAll(groups);
    }

    // Add root nodes at the next level
    final nextLevelRootNodes = realRootNodeLevels
        .where((e) => e.$2 == level + 1)
        .map((e) => e.$1)
        .toList();
    nextLevelNodes.addAll(nextLevelRootNodes);

    traverseLevel(withoutSpouses(nextLevelNodes), level + 1);
  }

  // Add root nodes at the next level
  const level = 0;
  final level0RootNodes =
      realRootNodeLevels.where((e) => e.$2 == level).map((e) => e.$1).toList();
  final level0RootNodesSingles = withoutSpouses(level0RootNodes);
  traverseLevel(level0RootNodesSingles, level);

  return levelGroups;
}

void markAncestors(Node node, bool isOnRight) {
  if (node.parents.length != 2) {
    return;
  }

  node.leadsToFocalNode = true;
  node.shouldBeRightChild = isOnRight;
  markAncestors(node.parents[0], true);
  markAncestors(node.parents[1], false);
}

List<Node> withoutSpouses(Iterable<Node> nodes) {
  final copy = <Node>[];
  final spouseIds = <String>{};
  for (final node in nodes) {
    if (spouseIds.contains(node.id)) {
      continue;
    }
    copy.add(node);
    spouseIds.addAll(node.spouses.map((e) => e.id));
  }
  return copy;
}

void dumpCoupleTree(Couple couple) {
  final visited = <String>{};

  void visit(Couple couple) {
    if (visited.contains(couple.id)) {
      return;
    }
    visited.add(couple.id);
    debugPrint('Couple: $couple');
    for (final relative in [...couple.parents, ...couple.children]) {
      visit(relative);
    }
  }

  visit(couple);
}

(Couple, Map<String, Couple>) createCoupleTree(Node focalNode) {
  final nodeToCouple = <String, Couple>{};

  Couple create(Node node) {
    final existing = nodeToCouple[node.id];
    if (existing != null) {
      return existing;
    }

    final spouse = node.spouse;
    final couple = Couple(
      id: node.id,
      parents: [],
      children: [],
      node: node,
      spouse: spouse,
    );

    nodeToCouple[node.id] = couple;
    if (spouse != null) {
      nodeToCouple[spouse.id] = couple;
    }

    if (node.parents.isNotEmpty) {
      couple.parents.add(create(node.parents[0]));
    }

    if (spouse != null && spouse.parents.isNotEmpty) {
      couple.parents.add(create(spouse.parents[0]));
    }

    for (final child in node.children) {
      couple.children.add(create(child));
    }

    return couple;
  }

  final focusCouple = create(focalNode);
  return (focusCouple, nodeToCouple);
}

typedef Group = List<Node>;
typedef LevelSiblings = List<Group>;

typedef GroupCouple = List<Couple>;
typedef LevelGroupCouples = List<GroupCouple>;
