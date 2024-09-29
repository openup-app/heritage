import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/util.dart';

part 'graph_view.freezed.dart';

@freezed
class Spacing with _$Spacing {
  const factory Spacing({
    required double level,
    required double sibling,
    required double spouse,
  }) = _Spacing;
}

class GraphView<T extends GraphNode> extends StatefulWidget {
  final Id focalNodeId;
  final List<T> nodes;
  final Spacing spacing;
  final Widget Function(
    BuildContext context,
    T data,
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
  State<GraphView<T>> createState() => GraphViewState<T>();
}

class GraphViewState<T extends GraphNode> extends State<GraphView<T>> {
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
        _createCouples(widget.nodes, widget.focalNodeId);
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
    return _Edges(
      nodeMap: _nodeMap,
      spacing: widget.spacing,
      child: _MultiTreeWidget(
        parentFocalId: _focalCouple.parents.isEmpty
            ? _focalCouple.node.id
            : _focalCouple.parents.first.id,
        leftGrandparent: upRoots.firstOrNull,
        rightGrandparent: upRoots.length > 1 ? upRoots[1] : null,
        parentLevelRoots: _downRoots,
        children: [
          for (final node in upRoots)
            _TreeRootIdWidget(
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
                      return RepaintBoundary(
                        child: widget.nodeBuilder(context, node.data, key),
                      );
                    },
                  ),
                ),
              ),
            ),
          for (final node in _downRoots)
            _TreeRootIdWidget(
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
                    return RepaintBoundary(
                      child: widget.nodeBuilder(context, node.data, key),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  GlobalKey? getKeyForNode(Id id) => _nodeKeys[id];

  (Couple<T>, Map<Id, Couple<T>>, List<Couple<T>>) _createCouples(
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
    for (var i = downRoots.length - 1; i >= 0; i--) {
      final couple = downRoots[i];
      if (unique.contains(couple.id)) {
        downRoots.removeAt(i);
      } else {
        unique.add(couple.id);
      }
    }

    // Graphs with only one or two levels
    if (downRoots.isEmpty) {
      if (focalCouple.parents.isNotEmpty) {
        downRoots.addAll(focalCouple.parents);
      } else {
        downRoots.add(focalCouple);
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
                child: Padding(
                  padding: EdgeInsets
                      .zero, //EdgeInsets.only(right: node.children.length == 1 ? 310.0 : 0),
                  child: SimpleTree(
                    node: child,
                    reverse: reverse,
                    spacing: spacing,
                    nodeBuilder: nodeBuilder,
                  ),
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

/// Positions its down roots below its up roots, and sized to contain them all.
class _MultiTreeRenderBox<T extends GraphNode> extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TreeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TreeParentData> {
  _MultiTreeRenderBox({
    required Id focalDownRootId,
    required Couple<T>? leftUpRoot,
    required Couple<T>? rightUpRoot,
    required List<Couple<T>> downRoots,
  })  : _focalDownRootId = focalDownRootId,
        _leftUpRoot = leftUpRoot,
        _rightUpRoot = rightUpRoot,
        _downRoots = downRoots;

  Id get focalDownRootId => _focalDownRootId;
  Id _focalDownRootId;
  set focalDownRootId(Id value) {
    if (value == _focalDownRootId) {
      return;
    }
    _focalDownRootId = value;
    markNeedsLayout();
  }

  Couple<T>? get leftUpRoot => _leftUpRoot;
  Couple<T>? _leftUpRoot;
  set leftUpRoot(Couple<T>? value) {
    if (value == _leftUpRoot) {
      return;
    }
    _leftUpRoot = value;
    markNeedsLayout();
  }

  Couple<T>? get rightUpRoot => _rightUpRoot;
  Couple<T>? _rightUpRoot;
  set rightUpRoot(Couple<T>? value) {
    if (value == _rightUpRoot) {
      return;
    }
    _rightUpRoot = value;
    markNeedsLayout();
  }

  List<Couple<T>> get downRoots => _downRoots;
  List<Couple<T>> _downRoots;
  set downRoots(List<Couple<T>> value) {
    if (value == _downRoots) {
      return;
    }
    _downRoots = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TreeParentData) {
      child.parentData = _TreeParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints.loosen();

    // Layout all children
    final childMap = <Id, RenderBox>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as _TreeParentData;
      child.layout(constraints, parentUsesSize: true);
      childMap[childParentData.id] = child;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    // Calculate position of the focal down root relative to first down root
    Offset relativeFocalDownRootOffset = Offset.zero;
    int mainRootIndex = 0;
    Size mainRootSize = Size.zero;
    final downRootSizes = <Id, Size>{};
    for (var couple in downRoots) {
      final child = childMap[couple.id];
      if (child != null) {
        downRootSizes[couple.id] = child.size;
      }
    }
    for (var index = 0; index < downRoots.length; index++) {
      final id = downRoots[index].id;
      final downRootSize = downRootSizes[id] ?? Size.zero;
      if (id == focalDownRootId) {
        mainRootSize = downRootSize;
        mainRootIndex = index;
        break;
      }
      relativeFocalDownRootOffset += Offset(downRootSize.width, 0);
    }

    // Up roots
    final up1 = leftUpRoot;
    final up2 = rightUpRoot;
    final up1Size =
        up1 == null ? Size.zero : childMap[up1.id]?.size ?? Size.zero;
    final up2Size =
        up2 == null ? Size.zero : childMap[up2.id]?.size ?? Size.zero;
    final upHeight = max(up1Size.height, up2Size.height);
    final upPivot = up1Size.width;
    final downPivot = relativeFocalDownRootOffset.dx + mainRootSize.width / 2;
    final upShouldShiftToPivot = upPivot < downPivot;
    final downRootsHorizontalShift =
        upShouldShiftToPivot ? Offset.zero : Offset(upPivot - downPivot, 0);
    final upRootsHorizontalShift =
        !upShouldShiftToPivot ? Offset.zero : Offset(downPivot - upPivot, 0);

    // Position the parent roots
    final downLeft = downRootsHorizontalShift.dx;
    double downRight = downRootsHorizontalShift.dx;
    Offset downRootOffset = downRootsHorizontalShift + Offset(0, upHeight);
    for (var id in downRootSizes.keys) {
      final child = childMap[id];
      if (child != null) {
        (child.parentData as _TreeParentData).offset = downRootOffset;
        downRootOffset += Offset(child.size.width, 0);
        downRight += child.size.width;
      }
    }

    final sizeEntries = downRootSizes.entries.toList();
    final leftWidth = sizeEntries
        .take(max(0, mainRootIndex - 1))
        .fold(0.0, (p, e) => p + e.value.width);
    final rightWidth = sizeEntries
        .skip(mainRootIndex + 1)
        .fold(0.0, (p, e) => p + e.value.width);

    // Position the grandparents
    double? upLeft;
    double? upRight;
    if (up1 != null) {
      final centerAboveLeft = !upShouldShiftToPivot
          ? Offset.zero
          : Offset(up1Size.width / 2, 0) +
              Offset(-(leftWidth + mainRootSize.width), 0) / 2 +
              Offset(mainRootSize.width / 2, 0);
      final up1Child = childMap[up1.id];
      if (up1Child != null) {
        final childParentData = (up1Child.parentData as _TreeParentData);
        childParentData.offset = upRootsHorizontalShift +
            Offset(0, upHeight) +
            Offset(0, -up1Size.height) +
            centerAboveLeft;
        upLeft = childParentData.offset.dx;
        upRight = up2 == null ? upLeft + up1Size.width : null;
      }
    }

    if (up2 != null) {
      final centerAboveRight = !upShouldShiftToPivot
          ? Offset.zero
          : Offset(-up2Size.width / 2, 0) +
              Offset(rightWidth + mainRootSize.width / 2, 0) / 2;
      final up2child = childMap[up2.id];
      if (up2child != null) {
        final childParentData = (up2child.parentData as _TreeParentData);
        childParentData.offset = upRootsHorizontalShift +
            Offset(up1Size.width, 0) +
            Offset(0, upHeight) +
            Offset(0, -up2Size.height) +
            centerAboveRight;
        upLeft = up1 == null ? childParentData.offset.dx : upLeft;
        upRight = childParentData.offset.dx + up2Size.width;
      }
    }

    final upSize = upLeft == null && upRight == null
        ? Size.zero
        : Size(upRight! - upLeft!, upHeight);
    final downSize = Size(downRight - downLeft, mainRootSize.height);
    // Size the parent
    if (up1 == null && up2 == null) {
      size = downSize;
    } else {
      size = Size(
        max(upSize.width, downSize.width),
        upSize.height + downSize.height,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as _TreeParentData;
      context.paintChild(child, offset + childParentData.offset);
      child = childParentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final childParentData = child.parentData as _TreeParentData;
      if (child.hitTest(result, position: position - childParentData.offset)) {
        return true;
      }
      child = childParentData.previousSibling;
    }
    return false;
  }
}

class _TreeParentData extends ContainerBoxParentData<RenderBox> {
  Id id = 'ID has not been set';
}

/// Contains tree-shaped children, and renders them with [_MultiTreeRenderBox].
class _MultiTreeWidget<T extends GraphNode>
    extends MultiChildRenderObjectWidget {
  final Id parentFocalId;
  final Couple<T>? leftGrandparent;
  final Couple<T>? rightGrandparent;
  final List<Couple<T>> parentLevelRoots;

  const _MultiTreeWidget({
    super.key,
    required this.parentFocalId,
    this.leftGrandparent,
    this.rightGrandparent,
    required this.parentLevelRoots,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MultiTreeRenderBox<T>(
      focalDownRootId: parentFocalId,
      leftUpRoot: leftGrandparent,
      rightUpRoot: rightGrandparent,
      downRoots: parentLevelRoots,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _MultiTreeRenderBox<T> renderObject) {
    renderObject
      ..focalDownRootId = parentFocalId
      ..leftUpRoot = leftGrandparent
      ..rightUpRoot = rightGrandparent
      ..downRoots = parentLevelRoots;
  }

  @override
  MultiChildRenderObjectElement createElement() {
    return MultiChildRenderObjectElement(this);
  }
}

/// Identifies each child in a [GraphView] so that [_MultiTreeRenderBox] can
/// position them according to their purpose defined by [_MultiTreeWidget].
class _TreeRootIdWidget extends ParentDataWidget<_TreeParentData> {
  final Id id;

  const _TreeRootIdWidget({
    super.key,
    required this.id,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData as _TreeParentData;
    if (parentData.id != id) {
      parentData.id = id;
      final targetParent = renderObject.parent;
      targetParent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _MultiTreeWidget;
}

class _Edges<T extends GraphNode> extends StatefulWidget {
  final Map<Id, (LinkedNode<T>, GlobalKey)> nodeMap;
  final Spacing spacing;
  final Widget child;

  const _Edges({
    super.key,
    required this.nodeMap,
    required this.spacing,
    required this.child,
  });

  @override
  State<_Edges> createState() => _EdgesState();
}

class _EdgesState<T extends GraphNode> extends State<_Edges<T>> {
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
      foregroundPainter: _EdgePainter(
        nodeRects: _nodeRects,
        spacing: widget.spacing,
      ),
      child: widget.child,
    );
  }
}

class _EdgePainter<T extends GraphNode> extends CustomPainter {
  final Map<Id, (LinkedNode<T>, Rect)> nodeRects;
  final Spacing spacing;

  _EdgePainter({
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
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return const DeepCollectionEquality.unordered()
            .equals(oldDelegate.nodeRects, nodeRects) ||
        spacing != oldDelegate.spacing;
  }
}
