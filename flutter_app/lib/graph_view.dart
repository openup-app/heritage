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
      BuildContext context, T data, LinkedNode<T> node, Key key) nodeBuilder;

  const GraphView({
    super.key,
    required this.focalNodeId,
    required this.nodeKeys,
    required this.spacing,
    required this.builder,
    required this.nodeBuilder,
  });

  @override
  State<GraphView<T>> createState() => GraphViewState<T>();
}

class GraphViewState<T extends GraphNode> extends State<GraphView<T>> {
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
    final parent = _focalCouple.parents.firstOrNull;
    final singleUpRootIsRight =
        upRoots.length == 1 && upRoots.first.id == parent?.parents.last.id;
    return widget.builder(
      context,
      _linkedNodes,
      _MultiTreeWidget(
        parentFocalId: _focalCouple.parents.isEmpty
            ? _focalCouple.node.id
            : _focalCouple.parents.first.id,
        leftGrandparent: upRoots.length > 1
            ? upRoots.first
            : singleUpRootIsRight
                ? null
                : upRoots.firstOrNull,
        rightGrandparent: upRoots.length > 1
            ? upRoots[1]
            : singleUpRootIsRight
                ? upRoots.firstOrNull
                : null,
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
                          node,
                          key,
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
                        node,
                        key,
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
    _organizeAncestorSiblings(focalNode);
    final (focalCouple, idToCouple) = createCoupleTree(focalNode);
    markRelatives(focalNode);
    markDirectRelativesAndSpouses(focalNode);
    markLevelsAndAncestors(focalNode);
    markClosetAncestors(focalNode);

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

  void _organizeAncestorSiblings(LinkedNode<T> node) {
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

    _organizeAncestorSiblings(leftP);
    _organizeAncestorSiblings(rightP);
  }

  LinkedNode<T>? linkedNodeForId(Id id) => _linkedNodes[id];
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
    final idToRenderBox = _sizeAllChildren();
    final (downRootLeftHalfWidth, downRootRightHalfWidth) =
        _getDownRootBilateralWidths(idToRenderBox, downRoots);

    // Up roots
    final up1Size = leftUpRoot == null
        ? Size.zero
        : idToRenderBox[leftUpRoot!.id]?.size ?? Size.zero;
    final up2Size = rightUpRoot == null
        ? Size.zero
        : idToRenderBox[rightUpRoot!.id]?.size ?? Size.zero;
    final upRootsHeight = max(up1Size.height, up2Size.height);
    final upPivot = up1Size.width;
    final downPivot1 = downRootLeftHalfWidth;
    final up1WiderThanDownPivot = upPivot > downPivot1;

    // Position the down roots
    final downHorizontalOffset =
        up1WiderThanDownPivot ? up1Size.width - downRootLeftHalfWidth : 0.0;
    Offset downRootOffset = Offset(downHorizontalOffset, upRootsHeight);
    for (var couple in downRoots) {
      final id = couple.id;
      final child = idToRenderBox[id];
      if (child != null) {
        (child.parentData as _TreeParentData).offset = downRootOffset;
        downRootOffset += Offset(child.size.width, 0);
      }
    }

    // Position the up roots
    double upStartHorizontalOffset =
        leftUpRoot == null && rightUpRoot != null ? downRootLeftHalfWidth : 0;
    for (final couple in [leftUpRoot, rightUpRoot].whereNotNull()) {
      final id = couple.id;
      final isOnLeft = couple == leftUpRoot;
      final child = idToRenderBox[id];
      if (child != null) {
        final bottomWidth =
            isOnLeft ? downRootLeftHalfWidth : downRootRightHalfWidth;
        final isWiderThanBottomHalf = child.size.width > bottomWidth;
        final horizontalOffset = upStartHorizontalOffset +
            (isWiderThanBottomHalf
                ? 0.0
                : (bottomWidth / 2 - child.size.width / 2));
        final verticalOffset = upRootsHeight - child.size.height;
        final childParentData = (child.parentData as _TreeParentData);
        childParentData.offset = Offset(horizontalOffset, verticalOffset);
        upStartHorizontalOffset += isWiderThanBottomHalf
            ? horizontalOffset + child.size.width
            : bottomWidth;
      }
    }

    size = _sizeToShrinkWrapAllChildren();
  }

  Map<Id, RenderBox> _sizeAllChildren() {
    final constraints = this.constraints.loosen();
    final idToRenderBox = <Id, RenderBox>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as _TreeParentData;
      child.layout(constraints, parentUsesSize: true);
      idToRenderBox[childParentData.id] = child;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    return idToRenderBox;
  }

  (double downRootLeftHalfWidth, double downRootRightHalfWidth)
      _getDownRootBilateralWidths(
          Map<Id, RenderBox> idToRenderBox, List<Couple<T>> downRoots) {
    double leftWidth = 0;
    double rightWidth = 0;
    bool isOnLeft = true;
    for (final id in downRoots.map((e) => e.id)) {
      final renderBox = idToRenderBox[id];
      if (renderBox == null) {
        continue;
      }
      if (isOnLeft) {
        if (id != focalDownRootId) {
          leftWidth += renderBox.size.width;
        } else {
          isOnLeft = false;
          leftWidth += renderBox.size.width / 2;
          rightWidth += renderBox.size.width / 2;
        }
      } else {
        rightWidth += renderBox.size.width;
      }
    }
    return (leftWidth, rightWidth);
  }

  Size _sizeToShrinkWrapAllChildren() {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as _TreeParentData;
      final rect = childParentData.offset & child.size;
      left = rect.left < left ? rect.left : left;
      top = rect.top < top ? rect.top : top;
      right = rect.right > right ? rect.right : right;
      bottom = rect.bottom > bottom ? rect.bottom : bottom;
      child = childParentData.nextSibling;
    }
    return Size(right - left, bottom - top);
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
    required bool isDirectRelativeOrSpouse,
    required bool isAncestor,
    required bool isSibling,
    required int relativeLevel,
    required String description,
  }) = _Relatedness;

  const Relatedness._();

  bool get isGrandparentLevelOrHigher => relativeLevel <= -2;
}
