import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:heritage/api.dart';
import 'package:heritage/tree.dart';
import 'package:heritage/tree_test_page.dart';

final _transformationController = TransformationController();

class FamilyTreeDisplay2 extends StatefulWidget {
  final Node focal;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;
  final void Function(Node node, Relationship relationship)
      onAddConnectionPressed;

  const FamilyTreeDisplay2({
    super.key,
    required this.focal,
    required this.levelGap,
    required this.siblingGap,
    required this.spouseGap,
    required this.nodeBuilder,
    required this.onAddConnectionPressed,
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
      transformationController: _transformationController,
      constrained: false,
      maxScale: 4,
      minScale: 0.1,
      boundaryMargin: const EdgeInsets.all(500),
      child: FamilyTreeLevels(
        levelGroupCouples: _levelGroupCouples,
        parentId: null,
        isFirstCoupleInLevel: true,
        level: 0,
        levelGap: widget.levelGap,
        siblingGap: widget.siblingGap,
        spouseGap: widget.spouseGap,
        nodeBuilder: widget.nodeBuilder,
        onAddConnectionPressed: widget.onAddConnectionPressed,
      ),
    );
  }
}

class OverlayControllerBuilder extends StatefulWidget {
  final Widget Function(BuildContext context,
      OverlayPortalController controller, GlobalKey childKey) builder;

  const OverlayControllerBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<OverlayControllerBuilder> createState() =>
      _OverlayControllerBuilderState();
}

class _OverlayControllerBuilderState extends State<OverlayControllerBuilder> {
  final _controller = OverlayPortalController();
  final _childKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _controller,
      _childKey,
    );
  }
}

class MouseHoverAnimation extends StatefulWidget {
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;
  final VoidCallback onHoverAnimationEnd;
  final Widget child;

  const MouseHoverAnimation({
    super.key,
    required this.onMouseEnter,
    required this.onMouseExit,
    required this.onHoverAnimationEnd,
    required this.child,
  });

  @override
  State<MouseHoverAnimation> createState() => _MouseHoverAnimationState();
}

class _MouseHoverAnimationState extends State<MouseHoverAnimation> {
  bool _isScaling = false;

  @override
  Widget build(BuildContext context) {
    return Scaler(
      duration: const Duration(milliseconds: 300),
      isScaling: _isScaling,
      scale: 1.5,
      onEnd: () {
        if (!_isScaling) {
          widget.onHoverAnimationEnd();
        }
      },
      child: MouseRegion(
        opaque: false,
        onEnter: (_) {
          setState(() => _isScaling = true);
          widget.onMouseEnter();
        },
        onExit: (_) {
          setState(() => _isScaling = false);
          widget.onMouseExit();
        },
        child: widget.child,
      ),
    );
  }
}

class Scaler extends StatefulWidget {
  final Duration duration;
  final bool isScaling;
  final double scale;
  final VoidCallback onEnd;
  final Widget child;

  const Scaler({
    super.key,
    required this.duration,
    required this.isScaling,
    required this.scale,
    required this.onEnd,
    required this.child,
  });

  @override
  State<Scaler> createState() => _HoverState();
}

class _HoverState extends State<Scaler> {
  var _targetScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (widget.isScaling) {
          setState(() => _targetScale = widget.scale);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant Scaler oldWidget) {
    if (widget.isScaling != oldWidget.isScaling) {
      _targetScale = widget.isScaling ? widget.scale : 1.0;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: widget.duration,
      curve: Curves.easeOutQuart,
      scale: _targetScale,
      onEnd: () {
        if (!widget.isScaling) {
          widget.onEnd();
        }
      },
      child: widget.child,
    );
  }
}

class FamilyTreeLevels extends StatelessWidget {
  final List<LevelGroupCouples> levelGroupCouples;
  final String? parentId;
  final bool isFirstCoupleInLevel;
  final int level;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;
  final void Function(Node node, Relationship relationship)
      onAddConnectionPressed;

  const FamilyTreeLevels({
    super.key,
    required this.levelGroupCouples,
    required this.parentId,
    required this.isFirstCoupleInLevel,
    required this.level,
    required this.levelGap,
    required this.siblingGap,
    required this.spouseGap,
    required this.nodeBuilder,
    required this.onAddConnectionPressed,
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
                          CoupleDisplay(
                            couple: couple,
                            spouseGap: spouseGap,
                            nodeBuilder: (context, node) {
                              return MouseHover(
                                onAddConnectionPressed: (relationship) =>
                                    onAddConnectionPressed(node, relationship),
                                builder: (context, hovering) {
                                  return nodeBuilder(context, node);
                                },
                              );
                            },
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
                                  levelGap: levelGap,
                                  siblingGap: siblingGap,
                                  spouseGap: spouseGap,
                                  nodeBuilder: nodeBuilder,
                                  onAddConnectionPressed:
                                      onAddConnectionPressed,
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
          spouseGap: 4,
          nodeBuilder: (context, node) => NodeDisplay(node: node),
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
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;

  const CoupleDisplay({
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
            child: nodeBuilder(context, spouse),
          ),
        nodeBuilder(context, couple.node),
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
    return SizedBox(
      width: 80,
      height: 80,
      child: Text(node.id),
    );
  }
}

class MouseHover extends StatefulWidget {
  final void Function(Relationship relationship) onAddConnectionPressed;
  final Widget Function(BuildContext context, bool hovering) builder;

  const MouseHover({
    super.key,
    required this.onAddConnectionPressed,
    required this.builder,
  });

  @override
  State<MouseHover> createState() => _MouseHoverState();
}

class _MouseHoverState extends State<MouseHover> {
  bool _hovering = false;
  bool _animate = false;
  final _controller = OverlayPortalController();
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        return AnimatedBuilder(
          animation: _transformationController,
          builder: (context, child) {
            final renderBox =
                _childKey.currentContext?.findRenderObject() as RenderBox?;
            final pos = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
            final scale = _transformationController.value[0];
            final matrix = Matrix4.identity()
              ..translate(pos.dx, pos.dy, 0.0)
              ..scale(scale)
              // ProfileControls
              ..translate(-120.0, -60.0, 0.0);
            return Align(
              alignment: Alignment.topLeft,
              child: Transform(
                transform: matrix,
                child: child,
              ),
            );
          },
          child: MouseHoverAnimation(
            onMouseEnter: () {
              setState(() {
                _hovering = true;
                _animate = true;
              });
            },
            onMouseExit: () {
              setState(() {
                _hovering = false;
                _animate = false;
              });
            },
            onHoverAnimationEnd: () {
              setState(() => _controller.hide());
            },
            child: ProfileControls(
              show: _animate,
              onAddConnectionPressed: widget.onAddConnectionPressed,
              child: widget.builder(context, _hovering),
            ),
          ),
        );
      },
      child: MouseRegion(
        opaque: false,
        onEnter: (_) {
          setState(() {
            _hovering = true;
            _controller.show();
          });
        },
        child: Visibility(
          visible: !_controller.isShowing,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          maintainSemantics: true,
          child: IgnorePointer(
            ignoring: _hovering,
            child: KeyedSubtree(
              key: _childKey,
              child: widget.builder(context, _hovering),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileControls extends StatefulWidget {
  final TransformationController transformationController;
  final Widget child;

  const _ProfileControls({
    super.key,
    required this.transformationController,
    required this.child,
  });

  @override
  State<_ProfileControls> createState() => _ProfileControlsState();
}

class _ProfileControlsState extends State<_ProfileControls> {
  final _controller = OverlayPortalController();
  final _childKey = GlobalKey();
  late final _ticker = Ticker((_) {
    setState(() {});
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        _controller.show();
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        final renderBox =
            _childKey.currentContext?.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? Size.zero;
        final pos = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
        final scale = widget.transformationController.value[0] * 1.5;
        print('POs $size, $scale');
        return Stack(
          children: [
            Positioned(
              left: pos.dx - 120, //+ size.width * scale,
              top: (pos.dy + size.height) /
                  1 /
                  (1.5 * scale), //+ size.height * scale,
              child: Padding(
                padding: EdgeInsets.only(right: size.width),
                child: FilledButton(
                  onPressed: () {},
                  child: Text('Add spouse'),
                ),
              ),
            ),
            Positioned(
              left: pos.dx + size.width * scale,
              top: pos.dy, //+ size.height * scale,
              child: Padding(
                padding: EdgeInsets.only(right: size.width),
                child: FilledButton(
                  onPressed: () {},
                  child: Text('Add sibling'),
                ),
              ),
            ),
          ],
        );
      },
      child: KeyedSubtree(
        key: _childKey,
        child: widget.child,
      ),
    );
  }
}
