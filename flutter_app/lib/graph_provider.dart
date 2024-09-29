import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/profile_update.dart';

final focalPersonIdProvider = StateProvider<Id?>((ref) => null);

final _peopleProvider = FutureProvider<List<Person>>((ref) async {
  final focalPersonId = ref.watch(focalPersonIdProvider);
  if (focalPersonId == null) {
    throw 'No focal person id set';
  }
  final api = ref.watch(apiProvider);
  final result = await api.getLimitedGraph(focalPersonId);
  return result.fold(
    (l) => throw l,
    (r) => r,
  );
});

final hasPeopleProvider = Provider<bool>(
    (ref) => ref.watch(_peopleProvider.select((s) => s.hasValue)));

final graphProvider = StateNotifierProvider<GraphNotifier, Graph>((ref) {
  final api = ref.watch(apiProvider);
  final focalPersonId = ref.watch(focalPersonIdProvider);
  final value = ref.watch(_peopleProvider);
  final people = value.valueOrNull;
  if (people == null) {
    throw 'Initial people have not yet loaded';
  }

  final peopleMap = Map.fromEntries(people.map((e) => MapEntry(e.id, e)));
  final focalPerson = peopleMap[focalPersonId];
  if (focalPerson == null) {
    throw 'Missing focal person';
  }
  return GraphNotifier(
    api: api,
    initialGraph: Graph(
      focalPerson: focalPerson,
      people: peopleMap,
    ),
  );
});

class GraphNotifier extends StateNotifier<Graph> {
  final Api api;
  final String _focalPersonId;

  GraphNotifier({
    required this.api,
    required Graph initialGraph,
  })  : _focalPersonId = initialGraph.focalPerson.id,
        super(initialGraph);

  Future<Id?> addConnection({
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
      return null;
    }
    return result.fold((l) {
      debugPrint(l);
      return null;
    }, (r) {
      _updatePeople(r.$2);
      return r.$1;
    });
  }

  Future<void> updateProfile(String id, ProfileUpdate update) async {
    final result = await api.updateProfile(
      id,
      profile: update.profile,
      image: update.image,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      debugPrint,
      (r) => _updatePeople([r]),
    );
  }

  Future<void> takeOwnership(String id) async {
    final result = await api.takeOwnership(id);
    if (!mounted) {
      return;
    }
    result.fold(
      debugPrint,
      (r) => _updatePeople([r]),
    );
  }

  void _updatePeople(List<Person> updates) {
    final people =
        Map.fromEntries(state.people.values.map((e) => MapEntry(e.id, e)));
    // Overwrite previous people with any updates
    people.addEntries(updates.map((e) => MapEntry(e.id, e)));
    final focalPerson = people[_focalPersonId];
    if (focalPerson == null) {
      throw 'Missing focal person after update';
    }
    state = Graph(
      focalPerson: focalPerson,
      people: people,
    );
  }
}

class Graph {
  final Person focalPerson;
  final Map<Id, Person> people;

  Graph({
    required this.focalPerson,
    required this.people,
  });
}
