import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';

final focalNodeIdProvider = StateProvider<Id?>((ref) => null);

final _nodesProvider = FutureProvider<List<ApiNode>>((ref) async {
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
  final apiNodes = value.valueOrNull;
  if (apiNodes == null) {
    throw 'Initial nodes have not yet loaded';
  }

  final nodeMap = _linkWithNewApiNodes(
    currentNodes: [],
    newApiNodes: apiNodes,
  );
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

  GraphNotifier({
    required this.api,
    required Graph initialGraph,
  }) : super(initialGraph);

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
      _addNodes,
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
    await api.updateProfile(id, _convertProfileToApiProfile(profile));
  }

  void _addNodes(List<ApiNode> newApiNodes) {
    final linkedNodes = _linkWithNewApiNodes(
      currentNodes: state.nodes.values,
      newApiNodes: newApiNodes,
    );
    state = Graph(
      focalNode: state.focalNode,
      nodes: linkedNodes,
    );
  }
}

Map<Id, Node> _linkWithNewApiNodes({
  required Iterable<Node> currentNodes,
  required Iterable<ApiNode> newApiNodes,
}) {
  final newNodes = newApiNodes.map((e) => _convertApiNodeToNode(e));
  final map = Map.fromEntries(
      [...currentNodes, ...newNodes].map((e) => MapEntry(e.id, e)));

  for (final newNode in newNodes) {
    for (final parentId in newNode.parentIds) {
      final parentNode = map[parentId];
      if (parentNode != null) {
        newNode.parents.add(parentNode);
        parentNode.children.add(newNode);
      }
    }
    for (final childId in newNode.childIds) {
      final childNode = map[childId];
      if (childNode != null) {
        newNode.children.add(childNode);
        childNode.parents.add(newNode);
      }
    }
    for (final spouseId in newNode.spouseIds) {
      final spouseNode = map[spouseId];
      if (spouseNode != null) {
        newNode.spouses.add(spouseNode);
        spouseNode.spouses.add(newNode);
      }
    }
  }
  return map;
}

class Graph {
  final Node focalNode;
  final Map<Id, Node> nodes;

  Graph({
    required this.focalNode,
    required this.nodes,
  });
}

Node _convertApiNodeToNode(ApiNode apiNode) {
  return Node(
    id: apiNode.id,
    parents: [],
    spouses: [],
    children: [],
    parentIds: List.of(apiNode.parents),
    spouseIds: List.of(apiNode.spouses),
    childIds: List.of(apiNode.children),
    addedBy: apiNode.addedBy,
    ownedBy: apiNode.ownedBy,
    createdAt: apiNode.createdAt,
    profile: Profile(
      name: apiNode.profile.name,
      gender: apiNode.profile.gender,
      imageUrl: apiNode.profile.imageUrl,
      birthday: apiNode.profile.birthday,
      deathday: apiNode.profile.deathday,
      birthplace: apiNode.profile.birthplace,
    ),
  );
}

ApiProfile _convertProfileToApiProfile(Profile profile) {
  return ApiProfile(
    name: profile.name,
    gender: profile.gender,
    imageUrl: profile.imageUrl,
    birthday: profile.birthday,
    deathday: profile.deathday,
    birthplace: profile.birthplace,
  );
}
