import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';

final focalNodeIdProvider = StateProvider<Id?>((ref) => null);

final _nodesProvider = FutureProvider<List<Node>>((ref) async {
  final focalNodeId = ref.watch(focalNodeIdProvider);
  if (focalNodeId == null) {
    throw 'No focal node id set';
  }
  final api = ref.watch(apiProvider);
  final result = await api.getLimitedGraph(focalNodeId);
  return result.fold(
    (l) => throw l,
    (r) => r,
  );
});

final hasNodesProvider = Provider<bool>(
    (ref) => ref.watch(_nodesProvider.select((s) => s.hasValue)));

final graphProvider = StateNotifierProvider<GraphNotifier, Graph>((ref) {
  final api = ref.watch(apiProvider);
  final focalNodeId = ref.watch(focalNodeIdProvider);
  final value = ref.watch(_nodesProvider);
  final nodes = value.valueOrNull;
  if (nodes == null) {
    throw 'Initial nodes have not yet loaded';
  }

  final nodeMap = Map.fromEntries(nodes.map((e) => MapEntry(e.id, e)));
  final focalNode = nodeMap[focalNodeId];
  if (focalNode == null) {
    throw 'Missing focal node';
  }
  return GraphNotifier(
    api: api,
    initialGraph: Graph(
      focalNode: focalNode,
      nodes: nodeMap,
    ),
  );
});

class GraphNotifier extends StateNotifier<Graph> {
  final Api api;
  final String _focalNodeId;

  GraphNotifier({
    required this.api,
    required Graph initialGraph,
  })  : _focalNodeId = initialGraph.focalNode.id,
        super(initialGraph);

  Future<void> addConnection({
    required Id source,
    required String name,
    required Gender gender,
    required Relationship relationship,
  }) async {
    final result = await api.addConnection(
      sourceId: source,
      name: name,
      gender: gender,
      relationship: relationship,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (l) => debugPrint(l),
      _updateNodes,
    );
  }

  // Future<void> fetchGraph(Id id) async => _fetchNodes({id});

  // Future<void> fetchConnectionsOf(List<Id> ids) async {
  //   final nodes = ids.map((e) => _nodes[e]).whereNotNull();
  //   if (nodes.isEmpty) {
  //     return;
  //   }
  //   final connectionIds = [
  //     for (final node in nodes) ...[
  //       ...node.parentIds,
  //       ...node.spouseIds,
  //       ...node.childIds,
  //     ],
  //   ];
  //   connectionIds
  //     ..removeWhere((e) => _nodes.keys.contains(e))
  //     ..removeWhere((e) => _connectionsFetched.contains(e));
  //   _connectionsFetched.addAll(connectionIds);
  //   return _fetchNodes(connectionIds.toSet());
  // }

  // Future<void> _fetchNodes(Set<Id> ids) async {
  //   final start = DateTime.now();
  //   final result = await api.getNodes(ids.toList());
  //   print('End ${DateTime.now().difference(start).inMilliseconds / 1000}s');
  //   if (!mounted) {
  //     return;
  //   }
  //   result.fold(
  //     (l) => debugPrint(l),
  //     _addNodes,
  //   );
  // }

  Future<void> updateProfile(String id, Profile profile) async {
    final result = await api.updateProfile(id, profile);
    if (!mounted) {
      return;
    }
    result.fold(
      debugPrint,
      (r) => _updateNodes([r]),
    );
  }

  Future<void> takeOwnership(String id) async {
    final result = await api.takeOwnership(id);
    if (!mounted) {
      return;
    }
    result.fold(
      debugPrint,
      (r) => _updateNodes([r]),
    );
  }

  void _updateNodes(List<Node> updates) {
    final nodes =
        Map.fromEntries(state.nodes.values.map((e) => MapEntry(e.id, e)));
    // Overwrite old nodes with any updates
    nodes.addEntries(updates.map((e) => MapEntry(e.id, e)));
    final focalNode = nodes[_focalNodeId];
    if (focalNode == null) {
      throw 'Missing focal node after update';
    }
    state = Graph(
      focalNode: focalNode,
      nodes: nodes,
    );
  }
}

class Graph {
  final Node focalNode;
  final Map<Id, Node> nodes;

  Graph({
    required this.focalNode,
    required this.nodes,
  });
}
