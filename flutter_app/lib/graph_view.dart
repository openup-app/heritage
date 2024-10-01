import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';

part 'graph_view.freezed.dart';

class GraphView<T extends GraphNode> extends StatefulWidget {
  final Id focalNodeId;
  final List<(T, Key)> nodeKeys;
  final Spacing spacing;
  final Widget Function(
      BuildContext context, Map<Id, LinkedNode<T>> nodes, Widget child) builder;
  final Widget Function(
          BuildContext context, T data, Key key, Relatedness relatedness)
      nodeBuilder;

  const GraphView({
    super.key,
    required this.focalNodeId,
    required this.nodeKeys,
    required this.spacing,
    required this.builder,
    required this.nodeBuilder,
  });

  @override
  State<GraphView<T>> createState() => _GraphViewState<T>();
}

class _GraphViewState<T extends GraphNode> extends State<GraphView<T>> {
  late Map<Id, Key> _idToKey;
  late Couple<T> _focalCouple;
  late List<Couple<T>> _downRoots;
  late Map<Id, LinkedNode<T>> _linkedNodes;

  @override
  void initState() {
    super.initState();
    _rebuildGraph();
  }

  void _rebuildGraph() {
    _idToKey =
        Map.fromEntries(widget.nodeKeys.map((e) => MapEntry(e.$1.id, e.$2)));
    final nodes = widget.nodeKeys.map((e) => e.$1);
    final (focalCouple, idToCouple, downRoots) =
        _createCouples(nodes, widget.focalNodeId);
    _focalCouple = focalCouple;
    _downRoots = downRoots;
  }

  @override
  Widget build(BuildContext context) {
    // At most two upRoots, the couple grandparent on each side
    final upRoots = _focalCouple.parents.expand((e) => e.parents).toList();
    return widget.builder(
      context,
      _linkedNodes,
      _MultiTreeWidget(
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
                      final key = _idToKey[node.id];
                      if (key == null) {
                        throw 'Missing key';
                      }
                      return RepaintBoundary(
                        child: widget.nodeBuilder(
                          context,
                          node.data,
                          key,
                          Relatedness(
                            isBloodRelative: node.isBloodRelative,
                            isAncestor: node.isAncestor,
                            relativeLevel: node.relativeLevel,
                          ),
                        ),
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
                    final key = _idToKey[node.id];
                    if (key == null) {
                      throw 'Missing key';
                    }
                    return RepaintBoundary(
                      child: widget.nodeBuilder(
                        context,
                        node.data,
                        key,
                        Relatedness(
                          isBloodRelative: node.isBloodRelative,
                          isAncestor: node.isAncestor,
                          relativeLevel: node.relativeLevel,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  (Couple<T>, Map<Id, Couple<T>>, List<Couple<T>>) _createCouples(
      Iterable<T> unlinkedNodes, Id focalNodeId) {
    final linkedNodes = linkNodes(unlinkedNodes);
    _linkedNodes = linkedNodes;
    final focalNode = linkedNodes[focalNodeId];
    if (focalNode == null) {
      throw 'Missing node with focalNodeId';
    }
    _organizeSides(focalNode);
    final (focalCouple, idToCouple) = createCoupleTree(focalNode);
    markRelatives(focalNode);
    markLevelsAndAncestors(focalNode);

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
              crossAxisAlignment: (parent.node.children.first.isBloodRelative &&
                          parent.parents.isNotEmpty) ||
                      parent.node.children.first.shouldBeRightChild
                  ? CrossAxisAlignment.end
                  : (parent.node.children.last.isBloodRelative &&
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
                                      (!spouse.isBloodRelative ||
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
        spouse != null && (!spouse.isBloodRelative ? true : spouse < node);
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
      final horizontalOffset = !upShouldShiftToPivot
          ? 0.0
          : (leftWidth + mainRootSize.width) / 2 - up1Size.width / 2;
      final verticalOffset = upHeight - up1Size.height;
      final up1Child = childMap[up1.id];
      if (up1Child != null) {
        final childParentData = (up1Child.parentData as _TreeParentData);
        childParentData.offset = Offset(horizontalOffset, verticalOffset);
        upLeft = childParentData.offset.dx;
        upRight = up2 == null ? upLeft + up1Size.width : null;
      }
    }

    if (up2 != null) {
      final horizontalOffset = !upShouldShiftToPivot
          ? up1Size.width
          : (rightWidth + mainRootSize.width) / 2 + up2Size.width / 2;
      final verticalOffset = upHeight - up2Size.height;
      final up2child = childMap[up2.id];
      if (up2child != null) {
        final childParentData = (up2child.parentData as _TreeParentData);
        childParentData.offset = Offset(horizontalOffset, verticalOffset);
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

@freezed
class Spacing with _$Spacing {
  const factory Spacing({
    required double level,
    required double sibling,
    required double spouse,
  }) = _Spacing;
}

@freezed
class Relatedness with _$Relatedness {
  const factory Relatedness({
    required bool isBloodRelative,
    required bool isAncestor,
    required int relativeLevel,
  }) = _Relatedness;

  const Relatedness._();

  bool get isGrandparentLevelOrHigher => relativeLevel <= -2;
}
