import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:heritage/tree.dart';

class FamilyTreeDisplay extends StatefulWidget {
  final Node focal;

  const FamilyTreeDisplay({
    super.key,
    required this.focal,
  });

  @override
  State<FamilyTreeDisplay> createState() => _FamilyTreeDisplayState();
}

class _FamilyTreeDisplayState extends State<FamilyTreeDisplay> {
  late final List<(Node, int)> _rootHeights;

  @override
  void initState() {
    super.initState();
    if (widget.focal.parents.isNotEmpty) {
      final rootHeights = _getRootHeights(widget.focal);
      setState(() => _rootHeights = rootHeights);
    } else {
      setState(() {
        _rootHeights = [];
      });
    }
  }

  List<(Node, int)> _getRootHeights(Node parent) {
    final roots = findRoots(parent);
    final rootsWithoutSpouses = withoutSpouses(roots);
    final rootsWithSpousesAndDistance =
        findRootsIncludingSpousesWithDistance(widget.focal);
    final treeHeight = rootsWithSpousesAndDistance.map((a) => a.$2).reduce(max);
    final realRootsAndDistances = rootsWithSpousesAndDistance
        .where((e) => rootsWithoutSpouses.contains(e.$1));

    return realRootsAndDistances.map((e) => (e.$1, treeHeight - e.$2)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 4,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(),
                ),
                child: FamilyTreeWidgets(
                  rootHeights: _rootHeights,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FamilyTreeWidgets extends StatelessWidget {
  final List<(Node, int)> rootHeights;

  const FamilyTreeWidgets({super.key, required this.rootHeights});

  @override
  Widget build(BuildContext context) {
    final level0Roots = rootHeights.where((e) => e.$2 == 0);
    final fakeRoot = Node(
      id: 'fake0',
      parents: [],
      spouses: [],
      children: [...level0Roots.where((e) => e.$2 == 0).map((e) => e.$1)],
      leadsToFocalNode: true,
      shouldTraverseChildren: true,
    );
    print(rootHeights);
    return Row(
      children: [
        for (final root in level0Roots)
          TreeDisplay(
            level: 0,
            node: root.$1,
            rootsWithDistance: rootHeights,
            builder: (context, child) => child,
          ),
      ],
    );
    // return TreeDisplay(
    //   level: -1,
    //   node: fakeRoot,
    //   rootsWithDistance: rootHeights,
    //   builder: (context, child) => child,
    // );
  }
}

class TreeDisplay extends StatelessWidget {
  final int level;
  final Node node;
  final List<(Node, int)> rootsWithDistance;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget Function(BuildContext context, Widget subtree) builder;

  const TreeDisplay({
    super.key,
    required this.level,
    required this.node,
    required this.rootsWithDistance,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final niblingRoots = rootsWithDistance.where(((e) => e.$2 == level + 1));
    final nextLevel = <Node>[];
    for (final child in node.children) {
      final spouse = child.spouses.firstOrNull;
      if (spouse == null || spouse.parents.isEmpty) {
        nextLevel.add(child);
      } else if (child.id.compareTo(spouse.id) == -1) {
        nextLevel.add(child);
      }
    }

    // TODO: This will duplicate roots
    // nextLevel.addAll(niblingRoots.map((e) => e.$1));

    final index = nextLevel.indexWhere((e) => e.leadsToFocalNode);
    if (index != -1) {
      final ancestor = nextLevel.removeAt(index);
      nextLevel.insert(
          !ancestor.shouldBeRightChild ? 0 : nextLevel.length, ancestor);
    }

    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.red,
      Colors.black,
      Colors.lightBlue,
      Colors.amber,
      Colors.green,
      Colors.cyan,
      Colors.brown,
      Colors.teal
    ];
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node.spouses.isNotEmpty &&
                node.shouldTraverseChildren &&
                node.spouses.first.shouldTraverseChildren)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: NodeDisplay(node: node.spouses.first),
              ),
            NodeDisplay(
              node: node,
            ),
          ],
        ),
        if (nextLevel.isNotEmpty)
          Builder(
            builder: (context) {
              final color = colors[
                  Random(nextLevel.firstOrNull?.id.hashCode ?? 0)
                      .nextInt(colors.length)];
              return builder(
                context,
                Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    border: Border.all(
                      width: 2,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, node) in nextLevel.indexed)
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            const SizedBox(
                              height: 20,
                              child: VerticalDivider(
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final isFirst = index == 0;
                                final isLast = index == nextLevel.length - 1;
                                final hasChildren = node.children.isNotEmpty;
                                final spouse = node.spouses.firstOrNull;
                                final hasLineage =
                                    (!node.shouldTraverseChildren ||
                                            spouse?.shouldTraverseChildren ==
                                                false) &&
                                        hasChildren;

                                const siblingGap = 16.0;
                                final siblingPadding = EdgeInsets.only(
                                  left: isFirst ? 0 : siblingGap / 2,
                                  right: isLast ? 0 : siblingGap / 2,
                                );

                                final lineageSpousePadding = !node
                                        .leadsToFocalNode
                                    ? EdgeInsets.zero
                                    : EdgeInsets.only(
                                        left:
                                            node.shouldBeRightChild ? 0 : 4 / 2,
                                        right:
                                            node.shouldBeRightChild ? 4 / 2 : 0,
                                      );

                                return Padding(
                                  padding:
                                      siblingPadding + lineageSpousePadding,
                                  child: TreeDisplay(
                                    level: level + 1,
                                    node: node,
                                    rootsWithDistance: rootsWithDistance,
                                    crossAxisAlignment: !hasLineage
                                        ? CrossAxisAlignment.center
                                        : node.shouldBeRightChild
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                    builder: (context, child) {
                                      if (hasLineage) {
                                        // return HalfSizeWidget(
                                        //   child: child,
                                        // );
                                        return child;
                                      }
                                      return child;
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class HalfSizeWidget extends SingleChildRenderObjectWidget {
  const HalfSizeWidget({
    super.key,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHalfSize();
  }
}

class _RenderHalfSize extends RenderProxyBox {
  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      // Report half of the child's width and full height to the parent
      size = Size(child!.size.width / 2, child!.size.height);
    } else {
      size = Size.zero;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint the child normally using its full size
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}

class NodeDisplay extends StatelessWidget {
  final Node node;
  const NodeDisplay({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(),
        color: Colors.blue.shade200,
      ),
      child: Text(node.id),
    );
  }
}
