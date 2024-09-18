import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

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

  Future<Either<Error, List<ApiNode>>> addConnection({
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
        return right(nodes.map((e) => ApiNode.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, ApiNode>> createRoot() {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/nodes'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(ApiNode.fromJson(json['node']));
      },
    );
  }

  Future<Either<Error, List<ApiNode>>> getNodes(List<Id> ids) {
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
        return right(nodes.map((e) => ApiNode.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, R>> _makeRequest<R>({
    required Future<Response> Function() request,
    required Either<Error, R> Function(Response response) handleResponse,
  }) async {
    try {
      final response = await request().timeout(_kTimeout);
      if (response.statusCode != 200) {
        return left('Status ${response.statusCode}');
      }
      return handleResponse(response);
    } on ClientException {
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

class ApiNode {
  final Id id;
  final List<Id> parents;
  final List<Id> spouses;
  final List<Id> children;
  final Id addedBy;
  final Id? ownedBy;
  final DateTime createdAt;
  final ApiProfile profile;

  const ApiNode({
    required this.id,
    required this.parents,
    required this.spouses,
    required this.children,
    required this.addedBy,
    required this.ownedBy,
    required this.createdAt,
    required this.profile,
  });

  factory ApiNode.fromJson(Map<String, dynamic> json) {
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
            'birthday': final String? birthday,
          }
        }) {
      return ApiNode(
        id: id,
        parents: parents.cast<Id>(),
        spouses: spouses.cast<Id>(),
        children: children.cast<Id>(),
        addedBy: addedBy,
        ownedBy: ownedBy,
        createdAt: DateTime.parse(createdAt),
        profile: ApiProfile(
          name: name,
          gender: Gender.values.byName(gender),
          birthday: birthday == null ? null : DateTime.tryParse(birthday),
        ),
      );
    }
    throw FormatException('Failed to parse $json');
  }
}

class ApiProfile {
  final String name;
  final Gender gender;
  final DateTime? birthday;

  ApiProfile({
    required this.name,
    required this.gender,
    required this.birthday,
  });
}
