import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:heritage/api.dart';

abstract class GraphNode {
  Id get id;
  List<Id> get parents;
  List<Id> get spouses;
  List<Id> get children;

  bool operator <(GraphNode other);
}

class LinkedNode<T extends GraphNode> {
  final Id id;
  final List<LinkedNode<T>> parents;
  final List<LinkedNode<T>> spouses;
  final List<LinkedNode<T>> children;
  final T data;
  bool isBloodRelative;
  bool isDirectRelativeOrSpouse;
  bool isAncestor;
  bool isSibling;
  int relativeLevel;
  LinkedNode<T>? ancestorOnLevel;
  bool shouldBeRightChild;

  LinkedNode({
    required this.id,
    required this.parents,
    required this.spouses,
    required this.children,
    required this.data,
    this.isBloodRelative = false,
    this.isDirectRelativeOrSpouse = false,
    this.isAncestor = false,
    this.isSibling = false,
    this.relativeLevel = 0,
    this.ancestorOnLevel,
    this.shouldBeRightChild = true,
  });

  LinkedNode<T>? get spouse => spouses.firstOrNull;

  @override
  String toString() => 'LinkedNode $id';

  bool operator <(LinkedNode<T> other) => data < other.data;
}

class Couple<T extends GraphNode> {
  final String id;
  final List<Couple<T>> parents;
  final List<Couple<T>> children;
  final LinkedNode<T> node;
  final LinkedNode<T>? spouse;

  Couple({
    required this.id,
    required this.parents,
    required this.children,
    required this.node,
    required this.spouse,
  });

  Couple<T>? get firstParent => parents.isEmpty
      ? null
      : parents.length == 1
          ? parents[0]
          : parents[0] < parents[1]
              ? parents[0]
              : parents[1];

  @override
  String toString() => 'Couple $id/${spouse?.id ?? '-'}';

  bool operator <(Couple<T> other) {
    final a = spouse == null
        ? node
        : node < spouse!
            ? node
            : spouse!;
    final b = other.spouse == null
        ? other.node
        : other.node < other.spouse!
            ? other.node
            : other.spouse!;
    return a < b;
  }
}

Map<Id, LinkedNode<T>> buildLinkedTree<T extends GraphNode>(
    Iterable<T> graphNodes, String focalNodeId) {
  final linkedNodes = linkNodes(graphNodes);
  final focalNode = linkedNodes[focalNodeId];
  if (focalNode == null) {
    throw 'Missing node with focalNodeId';
  }
  organizeAncestorSiblings(focalNode);
  markRelatives(focalNode);
  markDirectRelativesAndSpouses(focalNode);
  markLevelsAndAncestors(focalNode);
  markClosetAncestors(focalNode);
  return linkedNodes;
}

Map<Id, LinkedNode<T>> linkNodes<T extends GraphNode>(
    Iterable<T> unlinkedNodes) {
  final nodes = unlinkedNodes.map((t) => _emptyLinkedNode(t.id, t)).toList();
  final idToNode = Map.fromEntries(nodes.map((e) => MapEntry(e.id, e)));

  for (final (index, unlinkedNode) in unlinkedNodes.indexed) {
    final node = nodes[index];
    for (final parentId in unlinkedNode.parents) {
      final parentNode = idToNode[parentId];
      if (parentNode != null) {
        node.parents.add(parentNode);
      }
    }
    for (final childId in unlinkedNode.children) {
      final childNode = idToNode[childId];
      if (childNode != null) {
        node.children.add(childNode);
      }
    }
    for (final spouseId in unlinkedNode.spouses) {
      final spouseNode = idToNode[spouseId];
      if (spouseNode != null) {
        node.spouses.add(spouseNode);
      }
    }
  }

  return idToNode;
}

LinkedNode<T> _emptyLinkedNode<T extends GraphNode>(String id, T data) {
  return LinkedNode<T>(
    id: data.id,
    parents: [],
    spouses: [],
    children: [],
    data: data,
  );
}

void markLevelsAndAncestors<T extends GraphNode>(LinkedNode<T> focalNode) {
  final fringe = Queue<(LinkedNode<T>, int, bool)>();
  final visited = <Id>{};
  fringe.add((focalNode, 0, false));
  while (fringe.isNotEmpty) {
    final (node, relativeLevel, isAncestor) = fringe.removeFirst();
    if (visited.contains(node.id)) {
      continue;
    }
    node.relativeLevel = relativeLevel;
    node.isAncestor = isAncestor;
    visited.add(node.id);

    final parentIsAncestor = node.id == focalNode.id ? true : isAncestor;
    for (final parent in node.parents) {
      fringe.add((parent, relativeLevel - 1, parentIsAncestor));
    }
    for (final spouse in node.spouses) {
      fringe.add((spouse, relativeLevel, false));
    }
    for (final child in node.children) {
      fringe.add((child, relativeLevel + 1, false));
    }
  }
}

void markClosetAncestors<T extends GraphNode>(LinkedNode<T> focalNode) {
  final fringe = Queue<LinkedNode<T>>();
  final grandparents = focalNode.parents.map((e) => e.parents).expand((e) => e);
  for (final node in grandparents) {
    fringe.add(node);
  }
  while (fringe.isNotEmpty) {
    final node = fringe.removeFirst();
    final ancestorChild = node.children.firstWhere((e) => e.isAncestor);
    for (final child in node.children) {
      child.ancestorOnLevel = ancestorChild;
      child.spouse?.ancestorOnLevel = ancestorChild;
    }
    fringe.addAll(node.parents);
    if (node.parents.isEmpty) {
      node.ancestorOnLevel = node;
    }
  }
}

void organizeAncestorSiblings<T extends GraphNode>(LinkedNode<T> node) {
  if (node.parents.isEmpty) {
    return;
  }
  if (node.parents.last < node.parents.first) {
    node.parents.swap(0, 1);
  }
  final leftP = node.parents.first;
  final rightP = node.parents.last;
  leftP.shouldBeRightChild = true;
  rightP.shouldBeRightChild = false;

  final leftGPs = leftP.parents;
  if (leftGPs.isNotEmpty) {
    // Move sibling to end of siblings
    leftGPs.first.children.remove(leftP);
    leftGPs.first.children.add(leftP);
    leftGPs.last.children.remove(leftP);
    leftGPs.last.children.add(leftP);
  }
  final rightGPs = rightP.parents;
  if (rightGPs.isNotEmpty) {
    // Move sibling to beginning of siblings
    rightGPs.first.children.remove(rightP);
    rightGPs.first.children.insert(0, rightP);
    rightGPs.last.children.remove(rightP);
    rightGPs.last.children.insert(0, rightP);
  }

  organizeAncestorSiblings(leftP);
  organizeAncestorSiblings(rightP);
}

void markRelatives<T extends GraphNode>(LinkedNode<T> focalNode) {
  final rootNodes =
      findRootsIncludingSpousesWithDistance(focalNode).map((e) => e.$1);

  // Breadth-first search marking children, but not spouses
  final fringe = Queue<LinkedNode<T>>();
  final visited = <Id>{};
  fringe.addAll(rootNodes);
  while (fringe.isNotEmpty) {
    final node = fringe.removeFirst();
    if (visited.contains(node.id)) {
      continue;
    }
    visited.add(node.id);
    node.isBloodRelative = true;
    if (node.children.map((e) => e.id).contains(focalNode.id)) {
      for (final node in node.children) {
        if (node.id != focalNode.id) {
          node.isSibling = true;
        }
      }
    }
    fringe.addAll(node.children);
  }
}

void markDirectRelativesAndSpouses<T extends GraphNode>(
    LinkedNode<T> focalNode) {
  final relatives = [
    ...focalNode.parents,
    ...focalNode.spouses,
    ...focalNode.children,
    ...focalNode.parents
        .expand((e) => e.children)
        .where((e) => e.id != focalNode.id),
  ];
  for (final relative in relatives) {
    relative.isDirectRelativeOrSpouse = true;
  }
}

void debugTraverse<T extends GraphNode>(
    Couple<T> focalCouple, void Function(Couple<T> couple) visit) {
  final fringe = Queue<Couple<T>>();
  final visited = <Id>{};
  fringe.add(focalCouple);
  while (fringe.isNotEmpty) {
    final couple = fringe.removeFirst();
    if (visited.contains(couple.id)) {
      continue;
    }
    visited.add(couple.id);
    visit(couple);
    fringe.addAll(couple.parents.map((e) => e));
    fringe.addAll(couple.children.map((e) => e));
  }
}

/// Roots and their distance away from the given [node].
Set<(LinkedNode<T>, int)>
    findRootsIncludingSpousesWithDistance<T extends GraphNode>(
        LinkedNode<T> node) {
  Set<(LinkedNode<T>, int)> traverse(LinkedNode<T> node, int distance) {
    if (node.parents.isEmpty) {
      return {(node, distance)};
    }

    final roots = <(LinkedNode<T>, int)>{};
    for (final parent in node.parents) {
      roots.addAll(traverse(parent, distance + 1));
    }
    return roots;
  }

  return traverse(node, 0);
}

/// Roots and their distance away from the given [couple].
Set<(Couple<T>, int)> findRootCouplesWithDistance<T extends GraphNode>(
    Couple<T> couple) {
  Set<(Couple<T>, int)> traverse(Couple<T> couple, int distance) {
    if (couple.parents.isEmpty) {
      return {(couple, distance)};
    }

    final roots = <(Couple<T>, int)>{};
    for (final parent in couple.parents) {
      roots.addAll(traverse(parent, distance + 1));
    }
    return roots;
  }

  return traverse(couple, 0);
}

/// Set of nodes with no parents.
Set<LinkedNode> findRoots<T>(LinkedNode node) {
  final spouse = node.spouses.firstOrNull;
  if (spouse != null && node.parents.isEmpty && spouse.parents.isEmpty) {
    return {node};
  }

  final roots = <LinkedNode>{};
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

/// The height of the tree starting at [root].
int findHeight(LinkedNode root) {
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
List<List<LinkedNode>> getGraphNodesAtEachLevel(LinkedNode root) {
  final nodesByDepth = <List<LinkedNode>>[];

  void traverse(LinkedNode currentGraphNode, int depth) {
    if (nodesByDepth.length == depth) {
      nodesByDepth.add([]);
    }
    nodesByDepth[depth].add(currentGraphNode);
    for (var child in currentGraphNode.children) {
      traverse(child, depth + 1);
    }
  }

  traverse(root, 0);
  return nodesByDepth;
}

LinkedNode findHighestRoot(LinkedNode focal) {
  final topGraphNodes = findRoots(focal);

  int maxHeight = 0;
  LinkedNode? highestGraphNode;
  for (final node in topGraphNodes) {
    final height = findHeight(node);
    if (height > maxHeight) {
      highestGraphNode = node;
    }
  }
  return highestGraphNode ?? focal;
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

List<LevelGroupCouples<T>> getLevelsBySiblingCouples<T extends GraphNode>(
    Couple<T> focal) {
  final rootsAndDistances = findRootCouplesWithDistance(focal);
  final furthest = rootsAndDistances.reduce((a, b) => a.$2 > b.$2 ? a : b);
  final rootCouple = furthest.$1;
  final maxDistance = furthest.$2;
  final rootCoupleLevels =
      rootsAndDistances.map((e) => (e.$1, maxDistance - e.$2));
  final treeHeight = findCoupleHeight(rootCouple);
  final levelGroups = List.generate(treeHeight, (_) => <GroupCouple<T>>[]);

  void traverseLevel(List<Couple<T>> currentLevelCouples, int level) {
    if (currentLevelCouples.isEmpty) {
      return;
    }

    final groups = <GroupCouple<T>>[];
    final nextLevelCouples = <Couple<T>>[];

    for (final couple in currentLevelCouples) {
      // Adds root couples (no siblings)
      if (couple.parents.isEmpty) {
        levelGroups[level].add([couple]);
      }

      if (couple.children.isNotEmpty) {
        // Adds sibling group couples
        final children = <Couple<T>>[];
        for (final child in couple.children) {
          // Only one parent couple should add this child
          if (child.parents.isNotEmpty && couple < child.firstParent!) {
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

List<LevelSiblings> getLevelsBySiblings(LinkedNode focal) {
  final rootsAndDistances = findRootsIncludingSpousesWithDistance(focal);
  final furthest = rootsAndDistances.reduce((a, b) => a.$2 > b.$2 ? a : b);
  final rootGraphNode = furthest.$1;
  final maxDistance = furthest.$2;
  final rootGraphNodeLevels =
      rootsAndDistances.map((e) => (e.$1, maxDistance - e.$2));
  final realRootGraphNodeLevels = rootGraphNodeLevels.where((e) =>
      e.$1.parents.isEmpty && e.$1.spouses.expand((e) => e.parents).isEmpty);
  final treeHeight = findHeight(rootGraphNode);
  final levelGroups = List.generate(treeHeight, (_) => <Group>[]);

  void traverseLevel(List<LinkedNode> currentLevelGraphNodes, int level) {
    if (currentLevelGraphNodes.isEmpty) {
      return;
    }

    final groups = <Group>[];
    final nextLevelGraphNodes = <LinkedNode>[];

    for (final node in currentLevelGraphNodes) {
      if (node.children.isNotEmpty) {
        groups.add(node.children);
      }
      nextLevelGraphNodes.addAll(node.children);
    }

    if (groups.isNotEmpty) {
      levelGroups[level + 1].addAll(groups);
    }

    // Add root nodes at the next level
    final nextLevelRootGraphNodes = realRootGraphNodeLevels
        .where((e) => e.$2 == level + 1)
        .map((e) => e.$1)
        .toList();
    nextLevelGraphNodes.addAll(nextLevelRootGraphNodes);

    traverseLevel(withoutSpouses(nextLevelGraphNodes), level + 1);
  }

  // Add root nodes at the next level
  const level = 0;
  final level0RootGraphNodes = realRootGraphNodeLevels
      .where((e) => e.$2 == level)
      .map((e) => e.$1)
      .toList();
  final level0RootGraphNodesSingles = withoutSpouses(level0RootGraphNodes);
  traverseLevel(level0RootGraphNodesSingles, level);

  return levelGroups;
}

void markAncestors(LinkedNode node, bool isOnRight) {
  if (node.parents.length != 2) {
    return;
  }

  node.shouldBeRightChild = isOnRight;
  markAncestors(node.parents[0], true);
  markAncestors(node.parents[1], false);
}

List<LinkedNode<T>> withoutSpouses<T extends GraphNode>(
    Iterable<LinkedNode<T>> nodes) {
  final copy = <LinkedNode<T>>[];
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
  final visited = <Id>{};

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

(Couple<T>, Map<Id, Couple<T>>) createCoupleTree<T extends GraphNode>(
    LinkedNode<T> focalNode) {
  final nodeIdToCouple = <Id, Couple<T>>{};
  Couple<T> create(LinkedNode<T> node) {
    final existing = nodeIdToCouple[node.id];
    if (existing != null) {
      return existing;
    }

    final spouse = node.spouse;
    final couple = Couple(
      id: node.id,
      parents: <Couple<T>>[],
      children: <Couple<T>>[],
      node: node,
      spouse: spouse,
    );

    nodeIdToCouple[node.id] = couple;
    if (spouse != null) {
      nodeIdToCouple[spouse.id] = couple;
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

  final focalCouple = create(focalNode);
  return (focalCouple, nodeIdToCouple);
}

typedef Group = List<LinkedNode>;
typedef LevelSiblings = List<Group>;

typedef GroupCouple<T extends GraphNode> = List<Couple<T>>;
typedef LevelGroupCouples<T extends GraphNode> = List<GroupCouple<T>>;
