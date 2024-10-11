import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/util.dart';

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
    required Relationship relationship,
  }) async {
    final output = _createTempLinkGraphWithNewPerson(
        state.focalPerson.id, source, relationship);
    final focalNode = output?.focalNode;
    final targetNode = output?.targetNode;
    String? inviteText;
    if (focalNode != null && targetNode != null) {
      inviteText = _createTempInviteText(focalNode, targetNode);
    }

    final result = await api.addConnection(
      sourceId: source,
      relationship: relationship,
      inviteText: inviteText,
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

  Future<void> addInvite(
      LinkedNode<Person> focalNode, LinkedNode<Person> targetNode) async {
    final inviteText = _createTempInviteText(focalNode, targetNode);
    await api.addInvite(focalNode.id, targetNode.id, inviteText);
  }

  ({LinkedNode<Person> focalNode, LinkedNode<Person> targetNode})?
      _createTempLinkGraphWithNewPerson(
          Id focalPersonId, Id sourceId, Relationship relationship) {
    final sourcePerson = state.people[sourceId];
    if (sourcePerson == null) {
      return null;
    }

    // Modifiy collection, so deep clone
    final people = Map.fromEntries(
        state.people.values.map((e) => MapEntry(e.id, e.copyWith())));

    final newPerson = _tempPerson('tempPerson');
    people[newPerson.id] = newPerson;
    switch (relationship) {
      case Relationship.parent:
        newPerson.children.add(sourceId);
        sourcePerson.parents.add(newPerson.id);
      case Relationship.spouse:
        newPerson.spouses.add(sourceId);
        sourcePerson.spouses.add(newPerson.id);
      case Relationship.sibling:
        Person parent;
        if (sourcePerson.parents.isEmpty) {
          parent = _tempPerson('parent');
          parent.children.add(sourceId);
          sourcePerson.parents.add(parent.id);
          people[parent.id] = parent;
        } else {
          parent = people[sourcePerson.parents.first]!;
        }
        parent.children.add(newPerson.id);
        newPerson.parents.add(parent.id);
      case Relationship.child:
        sourcePerson.children.add(newPerson.id);
        newPerson.parents.add(sourceId);
    }
    final linkedNodes = buildLinkedTree(people.values, focalPersonId);
    final targetNode = linkedNodes[newPerson.id];
    final focalNode = linkedNodes[focalPersonId];
    if (targetNode == null || focalNode == null) {
      return null;
    }
    return (focalNode: focalNode, targetNode: targetNode);
  }
}

String _createTempInviteText(
    LinkedNode<Person> focalNode, LinkedNode<Person> targetNode) {
  final relatedness = relatednessDescription(
    focalNode,
    targetNode,
    pov: PointOfView.second,
  );
  return '${focalNode.data.profile.firstName} wants to add you as $relatedness';
}

Person _tempPerson(String id) {
  return Person(
    id: id,
    parents: [],
    spouses: [],
    children: [],
    addedBy: '',
    ownedBy: '',
    createdAt: DateTime.now(),
    profile: const Profile(
      firstName: '',
      lastName: '',
      gender: null,
      photo: Photo.network(key: '', url: ''),
      gallery: [],
      birthday: null,
      deathday: null,
      birthplace: '',
      occupation: '',
      hobbies: '',
    ),
  );
}

class Graph {
  final Person focalPerson;
  final Map<Id, Person> people;

  Graph({
    required this.focalPerson,
    required this.people,
  });
}
