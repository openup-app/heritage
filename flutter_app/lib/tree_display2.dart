import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/tree.dart';

class FamilyTreeDisplay2 extends StatefulWidget {
  final Node focal;

  const FamilyTreeDisplay2({
    super.key,
    required this.focal,
  });

  @override
  State<FamilyTreeDisplay2> createState() => _FamilyTreeDisplay2State();
}

class _FamilyTreeDisplay2State extends State<FamilyTreeDisplay2> {
  late final Couple _focalCouple;
  // late final Map<String, Couple> _nodeToCouple;
  // late final List<(Couple, int)> _rootCoupleHeights;
  late final List<LevelGroupCouples> _levelGroupCouples;

  @override
  void initState() {
    super.initState();
    final (focalCouple, nodeToCouple) = createCoupleTree(widget.focal);
    setState(() {
      _focalCouple = focalCouple;
      // _nodeToCouple = nodeToCouple;
    });

    final levelGroupCouples = getLevelsBySiblingCouples(focalCouple);
    _levelGroupCouples = levelGroupCouples;
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
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      maxScale: 4,
      minScale: 0.4,
      boundaryMargin: const EdgeInsets.all(500),
      child: FamilyTreeLevels(
        levelGroupCouples: _levelGroupCouples,
        parentId: null,
        isFirstCoupleInLevel: true,
        level: 0,
      ),
    );
  }
}

class FamilyTreeLevels extends StatelessWidget {
  final List<LevelGroupCouples> levelGroupCouples;
  final String? parentId;
  final bool isFirstCoupleInLevel;
  final int level;

  const FamilyTreeLevels({
    super.key,
    required this.levelGroupCouples,
    required this.parentId,
    required this.isFirstCoupleInLevel,
    required this.level,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(),
        color: Colors.amber.shade100,
      ),
      child: Column(
        children: [
          if (level != 0) const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (coupleIndex, couples) in siblingGroups.indexed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, couple) in couples.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            CoupleDisplay(
                              couple: couple,
                            ),
                            if (levelGroupCouples.length > 1)
                              Builder(
                                builder: (context) {
                                  final first = index == 0 && coupleIndex == 0;
                                  return FamilyTreeLevels(
                                    levelGroupCouples:
                                        levelGroupCouples.sublist(1),
                                    parentId: couple.id,
                                    isFirstCoupleInLevel: first,
                                    level: level + 1,
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
      ),
    );
  }
}

class FamilyTreeWidgets extends StatelessWidget {
  final List<(Couple, int)> rootCoupleHeights;

  const FamilyTreeWidgets({super.key, required this.rootCoupleHeights});

  @override
  Widget build(BuildContext context) {
    final level0Roots = rootCoupleHeights.where((e) => e.$2 == 0);
    final idWhichAddsNiblings = level0Roots.firstOrNull?.$1.id;
    print(rootCoupleHeights);
    return Row(
      children: [
        for (final root in level0Roots)
          TreeDisplay(
            level: 0,
            couple: root.$1,
            addsNiblings: root.$1.id == idWhichAddsNiblings,
            rootsWithHeights: rootCoupleHeights,
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
  final Couple couple;
  final bool addsNiblings;
  final List<(Couple, int)> rootsWithHeights;
  final Widget Function(BuildContext context, Widget subtree) builder;

  const TreeDisplay({
    super.key,
    required this.level,
    required this.couple,
    required this.addsNiblings,
    required this.rootsWithHeights,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final nextLevel = <Couple>[
      ...couple.children,
      if (addsNiblings)
        ...rootsWithHeights.where(((e) => e.$2 == level + 1)).map((e) => e.$1),
    ];

    // final index = nextLevel.indexWhere((e) => e.leadsToFocalNode);
    // if (index != -1) {
    //   final ancestor = nextLevel.removeAt(index);
    //   nextLevel.insert(
    //       !ancestor.shouldBeRightChild ? 0 : nextLevel.length, ancestor);
    // }

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CoupleDisplay(
          couple: couple,
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
                      for (final (index, couple) in nextLevel.indexed)
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
                                // final hasChildren = couple.children.isNotEmpty;
                                // final spouse = couple.spouse;
                                // final hasLineage =
                                //     (!couple.shouldTraverseChildren ||
                                //             spouse?.shouldTraverseChildren ==
                                //                 false) &&
                                //         hasChildren;

                                const siblingGap = 16.0;
                                final siblingPadding = EdgeInsets.only(
                                  left: isFirst ? 0 : siblingGap / 2,
                                  right: isLast ? 0 : siblingGap / 2,
                                );

                                // final lineageSpousePadding =
                                //     !couple.leadsToFocalNode
                                //         ? EdgeInsets.zero
                                //         : EdgeInsets.only(
                                //             left: couple.shouldBeRightChild
                                //                 ? 0
                                //                 : 4 / 2,
                                //             right: couple.shouldBeRightChild
                                //                 ? 4 / 2
                                //                 : 0,
                                //           );

                                return Padding(
                                  padding:
                                      siblingPadding, // + lineageSpousePadding,
                                  child: TreeDisplay(
                                    level: level + 1,
                                    couple: couple,
                                    addsNiblings:
                                        addsNiblings && couple.leadsToFocalNode,
                                    rootsWithHeights: rootsWithHeights,
                                    builder: (context, child) {
                                      // if (hasLineage) {
                                      //   // return HalfSizeWidget(
                                      //   //   child: child,
                                      //   // );
                                      //   return child;
                                      // }
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

class CoupleDisplay extends StatelessWidget {
  final Couple couple;

  const CoupleDisplay({
    super.key,
    required this.couple,
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
            padding: const EdgeInsets.only(right: 4.0),
            child: NodeDisplay(node: spouse),
          ),
        NodeDisplay(
          node: couple.node,
        ),
      ],
    );
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
    return Consumer(
      builder: (context, ref, child) {
        return FilledButton(
          onPressed: () => _sendTest(context, ref),
          style: FilledButton.styleFrom(
            fixedSize: const Size(80, 80),
          ),
          child: Text(node.id),
        );
      },
    );
  }

  void _sendTest(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final result = await api.getTest();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: result.isRight() ? Colors.green : Colors.red,
        content: Builder(
          builder: (context) {
            return result.fold(
              (l) => Text('Network request failed: $l'),
              (r) => const Text('Network request succeeded'),
            );
          },
        ),
      ),
    );
  }
}
