import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:heritage/graph.dart';
import 'package:http/http.dart' as http;

final apiProvider = Provider<Api>((ref) => throw 'Uninitialized provider');

const _kTimeout = Duration(seconds: 10);

class Api {
  final String _baseUrl;
  final Map<String, String> _headers;

  Api({
    required String baseUrl,
    required String appVersionName,
    required String appVersionCode,
  })  : _baseUrl = baseUrl,
        _headers = {
          'content-type': 'application/json',
          'x-app-version-name': appVersionName,
          'x-app-version-code': appVersionCode,
          'x-app-platform': _platformName(),
          'x-app-uid': 'test_uid',
        };

  void setAuthToken(String? authToken) {
    if (authToken == null) {
      _headers.remove('authorization');
    } else {
      _headers['authorization'] = 'Bearer $authToken';
    }
  }

  Future<Either<Error, List<Node>>> addConnection({
    required Id sourceId,
    required String name,
    required Gender gender,
    required Relationship relationship,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/nodes/$sourceId/connections'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'gender': gender.name,
          'relationship': relationship.name,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final nodes = json['nodes'] as List;
        return right(nodes.map((e) => Node.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, Node>> createRoot({
    required String name,
    required Gender gender,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/nodes'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'gender': gender.name,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Node.fromJson(json['node']));
      },
    );
  }

  Future<Either<Error, List<Node>>> getLimitedGraph(Id id) {
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/nodes/$id'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final nodes = json['nodes'] as List;
        return right(nodes.map((e) => Node.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, List<Node>>> getNodes(List<Id> ids) {
    if (ids.isEmpty) {
      return Future.value(right([]));
    }
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/nodes?ids=${ids.join(',')}'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final nodes = json['nodes'] as List;
        return right(nodes.map((e) => Node.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, List<Node>>> getRoots() {
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/roots'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final nodes = json['nodes'] as List;
        return right(nodes.map((e) => Node.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, Node>> updateProfile(String id, Profile profile) {
    return _makeRequest(
      request: () => http.put(
        Uri.parse('$_baseUrl/v1/node/$id/profile'),
        headers: _headers,
        body: jsonEncode(profile.toJson()),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Node.fromJson(json['node']));
      },
    );
  }

  Future<Either<Error, R>> _makeRequest<R>({
    required Future<http.Response> Function() request,
    required Either<Error, R> Function(http.Response response) handleResponse,
  }) async {
    try {
      final response = await request().timeout(_kTimeout);
      if (response.statusCode != 200) {
        return left('Status ${response.statusCode}');
      }
      return handleResponse(response);
    } on http.ClientException {
      return left('Client Exception');
    } on SocketException {
      return left('Socket Exception');
    } on TimeoutException {
      return left('Timeout Exception');
    } catch (e) {
      return left('Error $e');
    }
  }
}

String _platformName() => kIsWeb
    ? 'web'
    : Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : Platform.isLinux
                ? 'linux'
                : 'unknown';

typedef Error = String;

typedef Id = String;

enum Gender { male, female }

enum Relationship { parent, sibling, spouse, child }

class Node implements GraphNode {
  @override
  final Id id;
  @override
  final List<Id> parents;
  @override
  final List<Id> spouses;
  @override
  final List<Id> children;
  final Id addedBy;
  final Id? ownedBy;
  final DateTime createdAt;
  final Profile profile;

  const Node({
    required this.id,
    required this.parents,
    required this.spouses,
    required this.children,
    required this.addedBy,
    required this.ownedBy,
    required this.createdAt,
    required this.profile,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    if (json
        case {
          'id': final Id id,
          'parents': final List parents,
          'spouses': final List spouses,
          'children': final List children,
          'addedBy': final String addedBy,
          'ownedBy': final String? ownedBy,
          'createdAt': final String createdAt,
          'profile': {
            'name': final String name,
            'gender': final String gender,
            'imageUrl': final String? imageUrl,
            'birthday': final String? birthday,
            'deathday': final String? deathday,
            'birthplace': final String birthplace,
          }
        }) {
      return Node(
        id: id,
        parents: parents.cast<Id>(),
        spouses: spouses.cast<Id>(),
        children: children.cast<Id>(),
        addedBy: addedBy,
        ownedBy: ownedBy,
        createdAt: DateTime.parse(createdAt),
        profile: Profile(
          name: name,
          gender: Gender.values.byName(gender),
          imageUrl: imageUrl,
          birthday: birthday == null ? null : DateTime.tryParse(birthday),
          deathday: deathday == null ? null : DateTime.tryParse(deathday),
          birthplace: birthplace,
        ),
      );
    }
    throw FormatException('Failed to parse $json');
  }
}

class Profile {
  final String name;
  final Gender gender;
  final String? imageUrl;
  final DateTime? birthday;
  final DateTime? deathday;
  final String birthplace;

  Profile({
    required this.name,
    required this.gender,
    required this.imageUrl,
    required this.birthday,
    required this.deathday,
    required this.birthplace,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender.name,
      'imageUrl': imageUrl,
      'birthday': birthday?.toIso8601String(),
      'deathday': deathday?.toIso8601String(),
      'birthplace': birthplace,
    };
  }
}
