import 'package:flutter/widgets.dart';
import 'package:heritage/graph.dart';

class GraphView extends StatefulWidget {
  final Node focal;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;

  const GraphView({
    super.key,
    required this.focal,
    required this.levelGap,
    required this.siblingGap,
    required this.spouseGap,
    required this.nodeBuilder,
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
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
    return _GraphLevelView(
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
}

class _GraphLevelView extends StatelessWidget {
  final List<LevelGroupCouples> levelGroupCouples;
  final String? parentId;
  final bool isFirstCoupleInLevel;
  final int level;
  final double levelGap;
  final double siblingGap;
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;

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
                          _CoupleView(
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

class _CoupleView extends StatelessWidget {
  final Couple couple;
  final double spouseGap;
  final Widget Function(BuildContext context, Node node) nodeBuilder;

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
            child: nodeBuilder(context, spouse),
          ),
        nodeBuilder(context, couple.node),
      ],
    );
  }
}
