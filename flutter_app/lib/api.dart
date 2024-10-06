import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:heritage/file_picker.dart';
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

  Future<Either<Error, (Id id, List<Person> people)>> addConnection({
    required Id sourceId,
    required String firstName,
    required String lastName,
    required Gender gender,
    required Relationship relationship,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/people/$sourceId/connections'),
        headers: _headers,
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'gender': gender.name,
          'relationship': relationship.name,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final id = json['id'] as String;
        final people = json['people'] as List;
        return right((id, people.map((e) => Person.fromJson(e)).toList()));
      },
    );
  }

  Future<Either<Error, Person>> createRoot({
    required String firstName,
    required String lastName,
    required Gender gender,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/people'),
        headers: _headers,
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'gender': gender.name,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Person.fromJson(json['person']));
      },
    );
  }

  Future<Either<Error, List<Person>>> getLimitedGraph(Id id) {
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/people/$id'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final people = json['people'] as List;
        return right(people.map((e) => Person.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, List<Person>>> getPeople(List<Id> ids) {
    if (ids.isEmpty) {
      return Future.value(right([]));
    }
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/people?ids=${ids.join(',')}'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final people = json['people'] as List;
        return right(people.map((e) => Person.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, List<Person>>> getRoots() {
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/roots'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final people = json['people'] as List;
        return right(people.map((e) => Person.fromJson(e)).toList());
      },
    );
  }

  Future<Either<Error, Person>> updateProfile(
      String id, Profile profile) async {
    final uri = Uri.parse('$_baseUrl/v1/people/$id/profile');
    final request = http.MultipartRequest('PUT', uri);
    request.fields['profile'] = jsonEncode(profile.toJson());

    switch (profile.photo) {
      case NetworkPhoto():
        break;
      case MemoryPhoto(:final Uint8List bytes):
        await _addDownscaledPhoto(request, 'photo', 'photo', bytes);
        break;
    }

    for (final photo in profile.gallery) {
      switch (photo) {
        case NetworkPhoto():
          break;
        case MemoryPhoto(:final key, :final Uint8List bytes):
          await _addDownscaledPhoto(request, 'gallery', key, bytes);
          break;
      }
    }

    request.headers.addAll(_headers);

    try {
      final response = await request.send().timeout(_kTimeout);

      if (response.statusCode != 200) {
        return left('Status ${response.statusCode}');
      }

      // Handle the response
      final responseBody = await http.Response.fromStream(response);
      final json = jsonDecode(responseBody.body);
      return right(Person.fromJson(json['person']));
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

  Future<Either<Error, Person>> takeOwnership(String id) {
    return _makeRequest(
      request: () => http.put(
        Uri.parse('$_baseUrl/v1/people/$id/take_ownership'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Person.fromJson(json['person']));
      },
    );
  }

  Future<void> _addDownscaledPhoto(
    http.MultipartRequest request,
    String key,
    String basename,
    Uint8List bytes,
  ) async {
    final downscaled = await downscaleImage(bytes, size: 400);
    if (downscaled == null) {
      return;
    }
    request.files.add(http.MultipartFile.fromBytes(
      key,
      bytes,
      filename: '$basename.jpg',
    ));
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

@Freezed(makeCollectionsUnmodifiable: false)
class Person with _$Person implements GraphNode {
  const factory Person({
    required Id id,
    required List<Id> parents,
    required List<Id> spouses,
    required List<Id> children,
    required Id addedBy,
    required Id? ownedBy,
    @DateTimeConverter() required DateTime createdAt,
    required Profile profile,
  }) = _Person;

  const Person._();

  factory Person.fromJson(Map<String, Object?> json) => _$PersonFromJson(json);

  @override
  bool operator <(GraphNode other) {
    if (createdAt == (other as Person).createdAt) {
      return id.compareTo(other.id) == -1;
    }
    return createdAt.compareTo(other.createdAt) == -1;
  }
}

@freezed
class Photo with _$Photo {
  const factory Photo.network({
    required String key,
    required String url,
  }) = NetworkPhoto;

  const factory Photo.memory({
    required String key,
    // ignore: invalid_annotation_target
    @JsonKey(includeToJson: false, includeFromJson: false) Uint8List? bytes,
  }) = MemoryPhoto;

  factory Photo.fromJson(Map<String, Object?> json) => _$PhotoFromJson(json);
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String firstName,
    required String lastName,
    required Gender gender,
    required Photo photo,
    required List<Photo> gallery,
    required DateTime? birthday,
    @DateTimeConverter() required DateTime? deathday,
    required final String birthplace,
    required final String occupation,
    required final String hobbies,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  const Profile._();

  String get fullName => '$firstName $lastName';
}

class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String value) => DateTime.parse(value);

  @override
  String toJson(DateTime dateTime) => dateTime.toUtc().toIso8601String();
}
