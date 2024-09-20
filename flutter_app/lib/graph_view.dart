import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';

class GraphView<T extends GraphNode> extends StatefulWidget {
  final String focalNodeId;
  final List<T> nodes;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, T node, bool isInBloodLine)
      nodeBuilder;

  const GraphView({
    super.key,
    required this.focalNodeId,
    required this.nodes,
    required this.levelGap,
    required this.siblingGap,
    required this.spouseGap,
    required this.nodeBuilder,
  });

  @override
  State<GraphView<T>> createState() => _GraphViewState<T>();
}

class _GraphViewState<T extends GraphNode> extends State<GraphView<T>> {
  // late final Map<String, Couple> _nodeToCouple;
  // late final List<(Couple, int)> _rootCoupleHeights;
  late List<LevelGroupCouples<T>> _levelGroupCouples;
  late Key _levelsKey;

  @override
  void initState() {
    super.initState();
    _initCouples(widget.nodes);
    // if (_focalCouple.parents.isNotEmpty) {
    //   final individualRootHeights = getRootHeights(widget.focal);
    //   final rootCoupleHeights = individualRootHeights.map((e) {
    //     final couple = _nodeToCouple[e.$1.id];
    //     if (couple == null) {
    //       throw 'Missing couple for root Node';
    //     }
    //     return (couple, e.$2);
    //   }).toList();
    //   _rootCoupleHeights = rootCoupleHeights;
    // } else {
    //   _rootCoupleHeights = [];
    // }
  }

  @override
  void didUpdateWidget(covariant GraphView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const DeepCollectionEquality.unordered()
        .equals(oldWidget.nodes, widget.nodes)) {
      _initCouples(widget.nodes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GraphLevelView<T>(
      key: _levelsKey,
      levelGroupCouples: _levelGroupCouples,
      parentId: null,
      isFirstCoupleInLevel: true,
      level: 0,
      levelGap: widget.levelGap,
      siblingGap: widget.siblingGap,
      spouseGap: widget.spouseGap,
      nodeBuilder: widget.nodeBuilder,
    );
  }

  void _initCouples(Iterable<T> unlinkedNodes) {
    final linkedNodes = _linkNodes(unlinkedNodes);
    final focalNode = linkedNodes[widget.focalNodeId];
    if (focalNode == null) {
      throw 'Missing node with focalNodeId';
    }
    final (focalCouple, nodeToCouple) = createCoupleTree(focalNode);
    final levelGroupCouples = getLevelsBySiblingCouples(focalCouple);
    _levelGroupCouples = levelGroupCouples;
    _levelsKey = UniqueKey();
  }

  Map<Id, LinkedNode<T>> _linkNodes(Iterable<T> unlinkedNodes) {
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

  LinkedNode<T> _emptyLinkedNode(String id, T data) {
    return LinkedNode<T>(
      id: data.id,
      parents: [],
      spouses: [],
      children: [],
      data: data,
    );
  }
}

class _GraphLevelView<T extends GraphNode> extends StatelessWidget {
  final List<LevelGroupCouples<T>> levelGroupCouples;
  final String? parentId;
  final bool isFirstCoupleInLevel;
  final int level;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, T node, bool isInBloodLine)
      nodeBuilder;

  const _GraphLevelView({
    super.key,
    required this.levelGroupCouples,
    required this.parentId,
    required this.isFirstCoupleInLevel,
    required this.level,
    required this.levelGap,
    required this.siblingGap,
    required this.spouseGap,
    required this.nodeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final currentLevel = levelGroupCouples.first;
    final siblingGroups = currentLevel
        // Only siblings
        .where((e) =>
            parentId == null ||
            e.first.firstParentId == parentId ||
            e.first.firstParentId == null)
        // Only first couple in level can add niblings
        .where((e) =>
            e.first.firstParentId != null ||
            (e.first.firstParentId == null && isFirstCoupleInLevel));
    if (siblingGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (level != 0)
          SizedBox(
            height: levelGap,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (coupleIndex, couples) in siblingGroups.indexed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, couple) in couples.indexed)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: siblingGap / 2),
                      child: Column(
                        children: [
                          _CoupleView<T>(
                            couple: couple,
                            spouseGap: spouseGap,
                            nodeBuilder: nodeBuilder,
                          ),
                          if (levelGroupCouples.length > 1)
                            Builder(
                              builder: (context) {
                                final first = index == 0 && coupleIndex == 0;
                                return _GraphLevelView(
                                  levelGroupCouples:
                                      levelGroupCouples.sublist(1),
                                  parentId: couple.id,
                                  isFirstCoupleInLevel: first,
                                  level: level + 1,
                                  levelGap: levelGap,
                                  siblingGap: siblingGap,
                                  spouseGap: spouseGap,
                                  nodeBuilder: nodeBuilder,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
        // if (levelGroupCouples.length > 1)
        //   Row(
        //     children: [
        //       for (final couple in siblings in levelGroupCouples.first.where((e) => e.first.firstParentId)))

        //     ],
        //   ),
      ],
    );
  }
}

class _CoupleView<T extends GraphNode> extends StatelessWidget {
  final Couple<T> couple;
  final double spouseGap;
  final Widget Function(BuildContext context, T node, bool isInBloodLine)
      nodeBuilder;

  const _CoupleView({
    super.key,
    required this.couple,
    required this.spouseGap,
    required this.nodeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final spouse = couple.spouse;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spouse != null)
          Padding(
            padding: EdgeInsets.only(right: spouseGap),
            child: nodeBuilder(context, spouse.data, spouse.leadsToFocalNode),
          ),
        nodeBuilder(context, couple.node.data, true),
      ],
    );
  }
}
