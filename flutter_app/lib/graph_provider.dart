import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';

final focalPersonIdProvider =
    StateProvider<Id>((ref) => throw 'Uninitialized provider');

final _peopleProvider = FutureProvider<List<Person>>(
  (ref) async {
    final focalPersonId = ref.watch(focalPersonIdProvider);
    final api = ref.watch(apiProvider);
    final result = await api.getLimitedGraph(focalPersonId);
    return result.fold(
      (l) => throw l,
      (r) {
        if (r.isEmpty) {
          throw 'No people';
        }
        return r;
      },
    );
  },
  dependencies: [focalPersonIdProvider],
);

final hasPeopleProvider = Provider<bool>(
  (ref) => ref.watch(_peopleProvider.select((s) => s.hasValue)),
  dependencies: [_peopleProvider],
);

final hasPeopleErrorProvider = Provider<bool>(
  (ref) => ref.watch(_peopleProvider.select((s) => s.hasError)),
  dependencies: [_peopleProvider],
);

final graphProvider = StateNotifierProvider<GraphNotifier, Graph>(
  (ref) {
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
    final notifier = GraphNotifier(
      api: api,
      initialGraph: Graph(
        focalPerson: focalPerson,
        people: peopleMap,
      ),
    );
    return notifier;
  },
  dependencies: [_peopleProvider],
);

class GraphNotifier extends StateNotifier<Graph> {
  final Api api;
  final String _focalPersonId;
  late final Timer _timer;

  GraphNotifier({
    required this.api,
    required Graph initialGraph,
  })  : _focalPersonId = initialGraph.focalPerson.id,
        super(initialGraph) {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _onTimer());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<Id?> addConnection({
    required Id source,
    required String firstName,
    required String lastName,
    required Gender gender,
    required Relationship relationship,
    bool takeOwnership = false,
  }) async {
    final result = await api.addConnection(
      sourceId: source,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      relationship: relationship,
      takeOwnership: takeOwnership,
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

  Future<void> updateProfile(Id id, Profile profile) async {
    final result = await api.updateProfile(id, profile);
    if (!mounted) {
      return;
    }
    return result.fold(
      debugPrint,
      (r) => _updatePeople([r]),
    );
  }

  Future<void> deletePerson(Id id) async {
    final result = await api.deletePerson(id);
    if (!mounted) {
      return;
    }
    return result.fold(
      debugPrint,
      (r) => _updatePeople(r, deletedId: id),
    );
  }

  Future<void> clearProfile(Id id) async {
    final result = await api.deleteProfile(id);
    if (!mounted) {
      return;
    }
    return result.fold(
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

  void _updatePeople(List<Person> updates, {Id? deletedId}) {
    final people =
        Map.fromEntries(state.people.values.map((e) => MapEntry(e.id, e)));
    // Overwrite previous people with any updates
    people.addEntries(updates.map((e) => MapEntry(e.id, e)));
    if (deletedId != null) {
      people.removeWhere((key, value) => key == deletedId);
    }
    final focalPerson = people[_focalPersonId];
    if (focalPerson == null) {
      throw 'Missing focal person after update';
    }
    state = Graph(
      focalPerson: focalPerson,
      people: people,
    );
  }

  void _onTimer() async {
    final focalPersonId = state.focalPerson.id;
    final result = await api.getLimitedGraph(focalPersonId);
    if (!mounted) {
      return;
    }
    result.fold(
      (_) {},
      (people) {
        final peopleMap = Map.fromEntries(people.map((e) => MapEntry(e.id, e)));
        final focalPerson = peopleMap[focalPersonId];
        if (focalPerson == null) {
          return;
        }
        state = Graph(
          focalPerson: focalPerson,
          people: peopleMap,
        );
      },
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
