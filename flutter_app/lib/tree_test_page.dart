import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heritage/tree.dart';
import 'package:heritage/tree_display2.dart';

class TreeTestPage extends StatefulWidget {
  const TreeTestPage({super.key});

  @override
  State<TreeTestPage> createState() => _TreeTestPageState();
}

class _TreeTestPageState extends State<TreeTestPage> {
  late final Node _focal;

  @override
  void initState() {
    super.initState();
    _focal = _makeManyAncestoryTree();
    // _focal = _makeWideTree();
    // _focal = _makeTallTree();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FamilyTreeDisplay2(
          focal: _focal,
        ),
      ),
    );
  }
}

Node _generateRandomTree(int totalNodes) {
  final random = Random();
  final nodes = <Node>[];

  for (var i = 0; i < totalNodes; i++) {
    final node = Node(
      id: '$i',
      parents: [],
      children: [],
      spouses: [],
    );
    nodes.add(node);
  }

  for (var i = 1; i < totalNodes; i++) {
    final parentIndex = random.nextInt(i);
    final parent = nodes[parentIndex];
    final child = nodes[i];
    parent.addChild(child);
  }

  return nodes[random.nextInt(totalNodes)];
}

Node _makeTallTree() {
  final nodes = List.generate(
    28,
    (i) => Node(parents: [], spouses: [], children: [], id: '$i'),
  );

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(spouseA: 0, spouseB: 1, children: [2, 4]);
  connect(spouseA: 3, spouseB: 4, children: [7, 8, 10]);
  connect(spouseA: 9, spouseB: 10, children: [16]);
  connect(spouseA: 15, spouseB: 16, children: [19]);
  connect(spouseA: 19, spouseB: 20, children: [24, 25, 27]);
  connect(spouseA: 23, spouseB: 24, children: []);
  connect(spouseA: 26, spouseB: 27, children: []);

  connect(spouseA: 5, spouseB: 6, children: [/*12*,*/ 13]);
  // connect(spouseA: 11, spouseB: 12, children: []);
  connect(spouseA: 13, spouseB: 14, children: [18]);
  connect(spouseA: 17, spouseB: 18, children: [20, 22]);
  connect(spouseA: 21, spouseB: 22, children: []);

  final focalNode = nodes[25];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}

Node _makeWideTree() {
  final nodes = List.generate(
    40,
    (i) => Node(parents: [], spouses: [], children: [], id: '$i'),
  );

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(
      spouseA: 0,
      spouseB: 1,
      children: [5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 24]);
  connect(spouseA: 2, spouseB: 3, children: [25, 27]);

  connect(spouseA: 4, spouseB: 5, children: []);
  connect(spouseA: 6, spouseB: 7, children: []);
  connect(spouseA: 8, spouseB: 9, children: [28, 29, 30, 31, 32, 33, 34, 35]);
  connect(spouseA: 10, spouseB: 11, children: []);
  connect(spouseA: 12, spouseB: 13, children: []);
  connect(spouseA: 14, spouseB: 15, children: []);
  connect(spouseA: 16, spouseB: 17, children: []);
  connect(spouseA: 18, spouseB: 19, children: []);
  connect(spouseA: 20, spouseB: 21, children: []);
  connect(spouseA: 22, spouseB: 23, children: []);
  connect(spouseA: 24, spouseB: 25, children: [37, 39]);

  connect(spouseA: 26, spouseB: 27, children: []);

  connect(spouseA: 36, spouseB: 37, children: []);
  connect(spouseA: 38, spouseB: 39, children: []);

  final focalNode = nodes[37];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}

Node _makeManyAncestoryTree() {
  final nodes = List.generate(
    33,
    (i) => Node(parents: [], spouses: [], children: [], id: '$i'),
  );

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(spouseA: 0, spouseB: 1, children: [5]);
  connect(spouseA: 2, spouseB: 3, children: [9, 11]);

  connect(spouseA: 4, spouseB: 5, children: [14, 15]);
  connect(spouseA: 6, spouseB: 7, children: [16, 17]);
  connect(spouseA: 8, spouseB: 9, children: [18, 19]);
  connect(spouseA: 10, spouseB: 11, children: []);
  connect(spouseA: 12, spouseB: 13, children: [20, 22]);

  connect(spouseA: 15, spouseB: 16, children: [23, 24, 25]);
  connect(spouseA: 19, spouseB: 20, children: [26, 28, 30]);
  connect(spouseA: 21, spouseB: 22, children: []);
  connect(spouseA: 25, spouseB: 26, children: [32]);
  connect(spouseA: 27, spouseB: 28, children: []);

  connect(spouseA: 29, spouseB: 30, children: []);

  connect(spouseA: 31, spouseB: 32, children: []);

  final focalNode = nodes[32];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}
