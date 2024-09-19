import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';

final focalNodeIdProvider = StateProvider<Id?>((ref) => null);

final focalNodeProvider = FutureProvider<Node>((ref) async {
  final focalNodeId = ref.watch(focalNodeIdProvider);
  if (focalNodeId == null) {
    throw 'No focal node id set';
  }
  final api = ref.watch(apiProvider);
  final result = await api.getNodes([focalNodeId]);
  return result.fold(
    (l) => throw l,
    (r) => _convertApiNodeGraph(r.first),
  );
});

final graphProvider = StateNotifierProvider<GraphNotifier, Graph>((ref) {
  final api = ref.watch(apiProvider);
  final value = ref.watch(focalNodeProvider);
  final focalNode = value.valueOrNull;
  if (focalNode == null) {
    throw 'Focal node has not yet loaded';
  }
  return GraphNotifier(api: api, focalNode: focalNode);
});

class GraphNotifier extends StateNotifier<Graph> {
  final Api api;
  late final Map<Id, Node> _nodes;
  final _connectionsFetched = <Id>{};

  GraphNotifier({
    required this.api,
    required Node focalNode,
  })  : _nodes = {focalNode.id: focalNode},
        super(Graph(focalNode: focalNode, nodes: {focalNode.id: focalNode}));

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

  Future<void> fetchConnections(List<Id> ids) async {
    final nodes = ids.map((e) => _nodes[e]).whereNotNull();
    if (nodes.isEmpty) {
      return;
    }
    final connectionIds = [
      for (final node in nodes) ...[
        ...node.parentIds,
        ...node.spouseIds,
        ...node.childIds,
      ],
    ];
    connectionIds
      ..removeWhere((e) => _nodes.keys.contains(e))
      ..removeWhere((e) => _connectionsFetched.contains(e));
    _connectionsFetched.addAll(connectionIds);
    return fetchNodes(connectionIds.toSet());
  }

  Future<void> fetchNodes(Set<Id> ids) async {
    final result = await api.getNodes(ids.toList());
    if (!mounted) {
      return;
    }
    result.fold(
      (l) => debugPrint(l),
      _addNodes,
    );
  }

  void _addNodes(List<ApiNode> newApiNodes) {
    if (newApiNodes.isEmpty) {
      return;
    }
    final newNodePairs = newApiNodes.map((e) => (_convertApiNodeGraph(e), e));
    for (final (newNode, newApiNode) in newNodePairs) {
      for (final parentId in newApiNode.parents) {
        final parentNode = _nodes[parentId];
        if (parentNode != null) {
          newNode.parents.add(parentNode);
          parentNode.children.add(newNode);
        }
      }
      for (final childId in newApiNode.children) {
        final childNode = _nodes[childId];
        if (childNode != null) {
          newNode.children.add(childNode);
          childNode.parents.add(newNode);
        }
      }
      for (final spouseId in newApiNode.spouses) {
        final spouseNode = _nodes[spouseId];
        if (spouseNode != null) {
          newNode.spouses.add(spouseNode);
          spouseNode.spouses.add(newNode);
        }
      }
      _nodes[newNode.id] = newNode;
    }

    state = Graph(
      focalNode: state.focalNode,
      nodes: Map.of(_nodes),
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

Node _convertApiNodeGraph(ApiNode apiNode) {
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
      birthday: apiNode.profile.birthday,
    ),
  );
}
