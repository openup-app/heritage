import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/util.dart';

class Spacing {
  final double level;
  final double sibling;
  final double spouse;

  const Spacing({
    required this.level,
    required this.sibling,
    required this.spouse,
  });
}

class GraphView<T extends GraphNode> extends StatefulWidget {
  final String focalNodeId;
  final List<T> nodes;
  final Spacing spacing;
  final Widget Function(
    BuildContext context,
    LinkedNode<T> node,
    Key key,
  ) nodeBuilder;

  const GraphView({
    super.key,
    required this.focalNodeId,
    required this.nodes,
    required this.spacing,
    required this.nodeBuilder,
  });

  @override
  State<GraphView<T>> createState() => _GraphViewState<T>();
}

class _GraphViewState<T extends GraphNode> extends State<GraphView<T>> {
  final _nodeMap = <Id, (LinkedNode<T>, GlobalKey)>{};
  late Couple<T> _focalCouple;
  late List<Couple<T>> _downRoots;
  late Map<Id, GlobalKey> _nodeKeys;
  late Key _graphKey;

  @override
  void initState() {
    super.initState();
    _rebuildGraph();
  }

  @override
  void didUpdateWidget(covariant GraphView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    const unordered = DeepCollectionEquality.unordered();
    final oldIds = oldWidget.nodes.map((e) => e.id);
    final newIds = widget.nodes.map((e) => e.id);
    if (!unordered.equals(oldIds, newIds)) {
      _rebuildGraph();
    } else if (!unordered.equals(oldWidget.nodes, widget.nodes)) {
      _rebuildGraph();
    }
  }

  void _rebuildGraph() {
    _graphKey = UniqueKey();
    final (focalCouple, idToCouple, downRoots) =
        createCouples(widget.nodes, widget.focalNodeId);
    _focalCouple = focalCouple;
    _downRoots = downRoots;
    _nodeKeys =
        Map.fromEntries(idToCouple.keys.map((e) => MapEntry(e, GlobalKey())));

    for (final entry in idToCouple.entries) {
      final (id, couple) = (entry.key, entry.value);
      final spouse = couple.spouse;
      final nodeKey = _nodeKeys[couple.node.id];
      final spouseKey = spouse == null ? null : _nodeKeys[spouse.id];
      if (nodeKey == null) {
        throw 'Missing key for node';
      }
      _nodeMap[couple.id] = (couple.node, nodeKey);
      if (spouse != null) {
        if (spouseKey == null) {
          throw 'Missing key for spouse';
        }
        _nodeMap[spouse.id] = (spouse, spouseKey);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // At most two upRoots, the couple grandparent on each side
    final upRoots = _focalCouple.parents.expand((e) => e.parents).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(width: 10),
      ),
      child: _GraphLines(
        key: _graphKey,
        spacing: widget.spacing,
        nodeMap: _nodeMap,
        child: CustomMultiChildLayout(
          delegate: _GraphDelegate(
            parentFocalId: _focalCouple.parents.isEmpty
                ? ''
                : _focalCouple.parents.first.id,
            leftGrandparent: upRoots.firstOrNull,
            rightGrandparent: upRoots.length > 1 ? upRoots[1] : null,
            parentLevelRoots: _downRoots,
          ),
          children: [
            for (final node in upRoots)
              LayoutId(
                id: node.id,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: widget.spacing.sibling),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: widget.spacing.level),
                    child: SimpleTree(
                      node: node,
                      reverse: true,
                      spacing: widget.spacing,
                      nodeBuilder: (context, node) {
                        final key = _nodeKeys[node.id];
                        if (key == null) {
                          throw 'Missing key';
                        }
                        return widget.nodeBuilder(context, node, key);
                      },
                    ),
                  ),
                ),
              ),
            for (final node in _downRoots)
              LayoutId(
                id: node.id,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: widget.spacing.sibling),
                  child: SimpleTree(
                    node: node,
                    spacing: widget.spacing,
                    nodeBuilder: (context, node) {
                      final key = _nodeKeys[node.id];
                      if (key == null) {
                        throw 'Missing key';
                      }
                      return widget.nodeBuilder(context, node, key);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (Couple<T>, Map<Id, Couple<T>>, List<Couple<T>>) createCouples(
      Iterable<T> unlinkedNodes, Id focalNodeId) {
    final linkedNodes = linkNodes(unlinkedNodes);
    final focalNode = linkedNodes[focalNodeId];
    if (focalNode == null) {
      throw 'Missing node with focalNodeId';
    }
    _organizeSides(focalNode);
    final (focalCouple, idToCouple) = createCoupleTree(focalNode);
    markRelatives(focalCouple);

    // Maintains the child ordering from `_organizeSides`,
    final downRoots = focalCouple.parents
        .map((e) => e.parents)
        .expand((e) => e)
        .map((e) => e.children)
        .expand((e) => e)
        .toList();

    // Remove duplicate down roots
    final unique = <Id>{};
    for (var i = downRoots.length - 1; i > 0; i--) {
      final couple = downRoots[i];
      if (unique.contains(couple.id)) {
        downRoots.removeAt(i);
      } else {
        unique.add(couple.id);
      }
    }

    return (focalCouple, idToCouple, downRoots);
  }

  void _organizeSides(LinkedNode<T> node) {
    if (node.parents.isEmpty) {
      return;
    }

    final p1 = node.parents.first;
    final p2 = node.parents.last;
    if (p1 < p2) {
      p1.shouldBeRightChild = true;
      p2.shouldBeRightChild = false;
      // P1 right-most sibling, P2 left-most sibling
      if (p1.parents.isNotEmpty) {
        p1.parents.first.children.remove(p1);
        p1.parents.first.children.add(p1);
      }
      if (p2.parents.isNotEmpty) {
        p2.parents.first.children.remove(p2);
        p2.parents.first.children.insert(0, p2);
      }
    } else {
      p1.shouldBeRightChild = false;
      p2.shouldBeRightChild = true;
      // P1 left-most sibling, P2 right-most sibling
      if (p1.parents.isNotEmpty) {
        p1.parents.first.children.remove(p1);
        p1.parents.first.children.insert(0, p1);
      }
      if (p2.parents.isNotEmpty) {
        p2.parents.first.children.remove(p2);
        p2.parents.first.children.add(p2);
      }
    }
    _organizeSides(p1);
    _organizeSides(p2);
  }
}

class SimpleTree<T extends GraphNode> extends StatelessWidget {
  final Couple<T> node;
  final bool reverse;
  final Spacing spacing;
  final Widget Function(BuildContext context, LinkedNode<T> node) nodeBuilder;

  const SimpleTree({
    super.key,
    required this.node,
    this.reverse = false,
    required this.spacing,
    required this.nodeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final spouse = node.spouse;

    if (reverse) {
      if (node.parents.isEmpty) {
        return _NodeAndSpouse(
          node: node.node,
          spouse: spouse,
          spacing: spacing,
          nodeBuilder: nodeBuilder,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final parent in node.parents)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: (parent.node.children.first.isRelative &&
                          parent.parents.isNotEmpty) ||
                      parent.node.children.first.shouldBeRightChild
                  ? CrossAxisAlignment.end
                  : (parent.node.children.last.isRelative &&
                              parent.parents.isNotEmpty) ||
                          !parent.node.children.first.shouldBeRightChild
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sibling),
                  child: SimpleTree(
                    node: parent,
                    reverse: reverse,
                    spacing: spacing,
                    nodeBuilder: nodeBuilder,
                  ),
                ),
                SizedBox(height: spacing.level),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, singleSibling)
                        in parent.node.children.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : spacing.sibling,
                          right: index == parent.node.children.length - 1
                              ? 0
                              : spacing.sibling,
                        ),
                        child: Builder(
                          builder: (context) {
                            final spouse = singleSibling.spouse;
                            return _NodeAndSpouse(
                              node: singleSibling,
                              // Checks if there is any other branch that can lead to the spouse
                              spouse: spouse != null &&
                                      (!spouse.isRelative ||
                                          spouse.parents.isEmpty)
                                  ? spouse
                                  : null,
                              spacing: spacing,
                              nodeBuilder: nodeBuilder,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _NodeAndSpouse(
          node: node.node,
          spouse: spouse,
          spacing: spacing,
          nodeBuilder: nodeBuilder,
        ),
        SizedBox(height: spacing.level),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, child) in node.children.indexed)
              Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : spacing.sibling,
                  right:
                      index == node.children.length - 1 ? 0 : spacing.sibling,
                ),
                child: SimpleTree(
                  node: child,
                  reverse: reverse,
                  spacing: spacing,
                  nodeBuilder: nodeBuilder,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NodeAndSpouse<T extends GraphNode> extends StatelessWidget {
  final LinkedNode<T> node;
  final LinkedNode<T>? spouse;
  final Spacing spacing;
  final Widget Function(BuildContext context, LinkedNode<T> node) nodeBuilder;

  const _NodeAndSpouse({
    super.key,
    required this.node,
    this.spouse,
    required this.spacing,
    required this.nodeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final spouse = this.spouse;
    final spouseOnLeft =
        spouse != null && (!spouse.isRelative ? true : spouse < node);
    final isLeftAndHasExternalSpouse =
        spouse == null && node.spouse != null && node < node.spouse!;
    // Only left side adds spacing between the couple
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spouse != null && spouseOnLeft) ...[
          nodeBuilder(context, spouse),
          SizedBox(width: spacing.spouse),
        ],
        nodeBuilder(context, node),
        if ((spouse != null && !spouseOnLeft) || isLeftAndHasExternalSpouse)
          SizedBox(width: spacing.spouse),
        if (spouse != null && !spouseOnLeft) nodeBuilder(context, spouse),
      ],
    );
  }
}

class _GraphDelegate<T extends GraphNode> extends MultiChildLayoutDelegate {
  final Id parentFocalId;
  final Couple<T>? leftGrandparent;
  final Couple<T>? rightGrandparent;
  final List<Couple<T>> parentLevelRoots;

  _GraphDelegate({
    required this.parentFocalId,
    required this.leftGrandparent,
    required this.rightGrandparent,
    required this.parentLevelRoots,
  });

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(size);

    final gp1 = leftGrandparent;
    final gp2 = rightGrandparent;
    final gp1Size = gp1 == null ? Size.zero : layoutChild(gp1.id, constraints);
    final gp2Size = gp2 == null ? Size.zero : layoutChild(gp2.id, constraints);
    final grandparentHeight = max(gp1Size.height, gp2Size.height);
    final grandparentVerticalShift = Offset(0, grandparentHeight);

    final parentLevelSizes = Map.fromEntries(parentLevelRoots
        .map((e) => MapEntry(e.id, layoutChild(e.id, constraints))));

    // Compute just the main root offset relative to itself
    Offset relativeMainRootOffset = Offset.zero;
    int mainRootIndex = 0;
    Size mainRootSize = Size.zero;
    Offset tempOffset = Offset.zero;
    for (final (index, entry) in parentLevelSizes.entries.indexed) {
      final (id, size) = (entry.key, entry.value);
      if (id == parentFocalId) {
        relativeMainRootOffset = tempOffset;
        mainRootSize = size;
        mainRootIndex = index;
        break;
      }
      tempOffset += Offset(size.width, 0);
    }

    final grandparentPivotWidth = gp1Size.width;
    final parentPivotWidth = relativeMainRootOffset.dx + mainRootSize.width / 2;
    final grandparentsShiftToPivot = grandparentPivotWidth < parentPivotWidth;
    final parentShift = grandparentsShiftToPivot
        ? Offset.zero
        : Offset(grandparentPivotWidth - parentPivotWidth, 0);
    final grandparentHorizontalShift = !grandparentsShiftToPivot
        ? Offset.zero
        : Offset(parentPivotWidth - grandparentPivotWidth, 0);

    // Position the down root trees
    Offset parentRootOffset = parentShift + grandparentVerticalShift;
    for (final id in parentLevelSizes.keys) {
      final childSize = parentLevelSizes[id];
      positionChild(id, parentRootOffset);
      parentRootOffset += Offset(childSize?.width ?? 0, 0);
    }

    final sizeEntries = parentLevelSizes.entries.toList();
    final leftWidth = sizeEntries
        .take(max(0, mainRootIndex - 1))
        .fold(0.0, (p, e) => p + e.value.width);
    final rightWidth = sizeEntries
        .skip(mainRootIndex + 1)
        .fold(0.0, (p, e) => p + e.value.width);

    // Position the up root trees
    if (gp1 != null) {
      final centerAboveLeft = !grandparentsShiftToPivot
          ? Offset.zero
          : Offset(gp1Size.width / 2, 0) +
              Offset(-(leftWidth + mainRootSize.width), 0) / 2;
      positionChild(
        gp1.id,
        grandparentHorizontalShift +
            grandparentVerticalShift +
            Offset(0, -gp1Size.height) +
            centerAboveLeft,
      );
    }
    if (gp2 != null) {
      final centerAboveRight = !grandparentsShiftToPivot
          ? Offset.zero
          : Offset(-gp2Size.width / 2, 0) +
              Offset(rightWidth + mainRootSize.width / 2, 0) / 2;
      positionChild(
        gp2.id,
        grandparentHorizontalShift +
            Offset(gp1Size.width, 0) +
            grandparentVerticalShift +
            Offset(0, -gp2Size.height) +
            centerAboveRight,
      );
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    return true;
  }
}

class _GraphLines<T extends GraphNode> extends StatefulWidget {
  final Map<Id, (LinkedNode<T>, GlobalKey)> nodeMap;
  final Spacing spacing;
  final Widget child;

  const _GraphLines({
    super.key,
    required this.nodeMap,
    required this.spacing,
    required this.child,
  });

  @override
  State<_GraphLines> createState() => _GraphLinesState();
}

class _GraphLinesState<T extends GraphNode> extends State<_GraphLines<T>> {
  final _nodeRects = <Id, (LinkedNode<T>, Rect)>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (!mounted) {
        return;
      }
      _locateNodes();
    });
  }

  void _locateNodes() {
    setState(() {
      for (final entry in widget.nodeMap.entries) {
        final (id, value) = (entry.key, entry.value);
        final node = value.$1;
        final key = value.$2;
        _nodeRects[id] = (node, locateWidget(key) ?? Rect.zero);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _LinePainter(
        nodeRects: _nodeRects,
        spacing: widget.spacing,
      ),
      child: widget.child,
    );
  }
}

class _LinePainter<T extends GraphNode> extends CustomPainter {
  final Map<Id, (LinkedNode<T>, Rect)> nodeRects;
  final Spacing spacing;

  _LinePainter({
    required this.nodeRects,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Only the left node in nodes with spouses
    final leftNodeInCouples = nodeRects.values.where((e) {
      final node = e.$1;
      final spouse = node.spouse;
      if (spouse == null) {
        return false;
      }
      return node.isRelative && spouse.isRelative
          ? node < spouse
          : !node.isRelative;
    });
    for (final (fromNode, fromRect) in leftNodeInCouples) {
      for (final toNode in fromNode.children) {
        final (_, toRect) = nodeRects[toNode.id]!;
        final s = Offset(
          fromRect.bottomRight.dx + spacing.spouse / 2,
          fromRect.bottomRight.dy,
        );
        final e = toRect.topCenter;
        final path = Path()
          ..moveTo(s.dx, s.dy)
          ..lineTo(s.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, e.dy);
        canvas.drawPath(
          path,
          Paint()
            ..strokeWidth = 4
            ..style = PaintingStyle.stroke
            ..color = Colors.black,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
