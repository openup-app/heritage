import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:heritage/graph.dart';
import 'package:http/http.dart' as http;

part 'api.freezed.dart';
part 'api.g.dart';

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
        Uri.parse('$_baseUrl/v1/nodes/$id/profile'),
        headers: _headers,
        body: jsonEncode({
          'profile': profile.toJson(),
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Node.fromJson(json['node']));
      },
    );
  }

  Future<Either<Error, Node>> takeOwnership(String id) {
    return _makeRequest(
      request: () => http.put(
        Uri.parse('$_baseUrl/v1/nodes/$id/take_ownership'),
        headers: _headers,
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

@freezed
class Node with _$Node implements GraphNode {
  const factory Node({
    required Id id,
    required List<Id> parents,
    required List<Id> spouses,
    required List<Id> children,
    required Id addedBy,
    required Id? ownedBy,
    @DateTimeConverter() required DateTime createdAt,
    required Profile profile,
  }) = _Node;

  factory Node.fromJson(Map<String, Object?> json) => _$NodeFromJson(json);
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String name,
    required Gender gender,
    required String? imageUrl,
    required DateTime? birthday,
    @DateTimeConverter() required DateTime? deathday,
    required final String birthplace,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);
}

class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String value) => DateTime.parse(value);

  @override
  String toJson(DateTime dateTime) => dateTime.toUtc().toIso8601String();
}
