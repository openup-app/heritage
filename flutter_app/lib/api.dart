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
        };

  void setAuthToken(String? authToken) {
    if (authToken == null) {
      _headers.remove('authorization');
    } else {
      _headers['authorization'] = 'Bearer $authToken';
    }
  }

  void setUid(String uid) {
    _headers['x-app-uid'] = uid;
  }

  Future<Either<ApiError<SmsError>, void>> sendSms({
    required String phoneNumber,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/accounts/authenticate/send_sms'),
        headers: _headers,
        body: jsonEncode({
          'phoneNumber': phoneNumber,
        }),
      ),
      handleResponse: (response) => right(null),
      handleError: (response) {
        final result = jsonDecode(response.body);
        final error = Error.fromJson(result['error']);
        final code = SmsError.values.asNameMap()[error.code];
        if (code == null) {
          debugPrint('Missing error code: ${error.code}');
        }
        return ClientError(code ?? SmsError.failure);
      },
    );
  }

  Future<Either<ApiError<AuthError>, String>> authenticatePhone({
    required String? claimUid,
    required String phoneNumber,
    required String smsCode,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/accounts/authenticate'),
        headers: _headers,
        body: jsonEncode({
          'claimUid': claimUid,
          'credential': {
            'type': 'phone',
            'phoneNumber': phoneNumber,
            'smsCode': smsCode,
          },
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(json['token']);
      },
      handleError: (response) {
        final result = jsonDecode(response.body);
        final error = Error.fromJson(result['error']);
        final code = AuthError.values.asNameMap()[error.code];
        if (code == null) {
          debugPrint('Missing error code: ${error.code}');
        }
        return ClientError(code ?? AuthError.failure);
      },
    );
  }

  Future<Either<ApiError<AuthError>, String>> authenticateOauth({
    required String? claimUid,
    required String idToken,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/accounts/authenticate'),
        headers: _headers,
        body: jsonEncode({
          'claimUid': claimUid,
          'credential': {
            'type': 'oauth',
            'idToken': idToken,
          },
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(json['token']);
      },
      handleError: (response) {
        final result = jsonDecode(response.body);
        final error = Error.fromJson(result['error']);
        final code = AuthError.values.asNameMap()[error.code];
        if (code == null) {
          debugPrint('Missing error code: ${error.code}');
        }
        return ClientError(code ?? AuthError.failure);
      },
    );
  }

  Future<Either<ApiError, (Id id, List<Person> people)>> addConnection({
    required Id sourceId,
    required Relationship relationship,
    required String? inviteText,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/people/$sourceId/connections'),
        headers: _headers,
        body: jsonEncode({
          'relationship': relationship.name,
          'inviteText': inviteText,
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

  Future<Either<ApiError, Person>> createRoot({
    required String firstName,
    required String lastName,
  }) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/people'),
        headers: _headers,
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Person.fromJson(json['person']));
      },
    );
  }

  Future<Either<ApiError, List<Person>>> getLimitedGraph(Id id) {
    return _makeRequest(
      request: () => http.get(
        Uri.parse('$_baseUrl/v1/people/$id/graph'),
        headers: _headers,
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        final people = json['people'] as List;
        return right(people.map((e) => Person.fromJson(e)).toList());
      },
    );
  }

  Future<Either<ApiError, List<Person>>> getPeople(List<Id> ids) {
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

  Future<Either<ApiError, List<Person>>> getRoots() {
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

  Future<Either<ApiError, Person>> updateProfile(
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
        if (response.statusCode == 500) {
          return left(ServerError());
        } else {
          return left(UnhandledError('Status ${response.statusCode}'));
        }
      }

      // Handle the response
      final responseBody = await http.Response.fromStream(response);
      final json = jsonDecode(responseBody.body);
      return right(Person.fromJson(json['person']));
    } on http.ClientException {
      return left(PackageError());
    } on SocketException {
      return left(NetworkError());
    } on TimeoutException {
      return left(NetworkError());
    } catch (e) {
      debugPrint(e.toString());
      return left(UnhandledError(e.toString()));
    }
  }

  Future<Either<ApiError, List<Person>>> deletePerson(Id id) {
    return _makeRequest(
      request: () => http.delete(
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

  Future<Either<ApiError, Person>> updateOwnershipUnableReason(
      Id id, OwnershipUnableReason? reason) {
    return _makeRequest(
      request: () => http.put(
        Uri.parse('$_baseUrl/v1/people/$id/ownership_unable_reason'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason?.name,
        }),
      ),
      handleResponse: (response) {
        final json = jsonDecode(response.body);
        return right(Person.fromJson(json['person']));
      },
    );
  }

  Future<Either<ApiError, Null>> addInvite(
    Id fromId,
    Id toId,
    String inviteText,
  ) {
    return _makeRequest(
      request: () => http.post(
        Uri.parse('$_baseUrl/v1/invites/'),
        headers: _headers,
        body: jsonEncode({
          'fromId': fromId,
          'toId': toId,
          'inviteText': inviteText,
        }),
      ),
      handleResponse: (_) => const Right(null),
    );
  }

  Future<void> _addDownscaledPhoto(
    http.MultipartRequest request,
    String key,
    String basename,
    Uint8List bytes,
  ) async {
    final downscaled = await downscaleImage(bytes, size: 600);
    if (downscaled == null) {
      return;
    }
    request.files.add(http.MultipartFile.fromBytes(
      key,
      downscaled,
      filename: '$basename.jpg',
    ));
  }

  Future<Either<ApiError<T>, R>> _makeRequest<T, R>({
    required Future<http.Response> Function() request,
    required Either<ApiError<T>, R> Function(http.Response response)
        handleResponse,
    ApiError<T> Function(http.Response response)? handleError,
  }) async {
    try {
      final response = await request().timeout(_kTimeout);
      if (response.statusCode != 200) {
        if (response.statusCode == 400 && handleError != null) {
          return left(handleError(response));
        } else if (response.statusCode == 500) {
          return left(ServerError());
        } else {
          return left(UnhandledError('Status ${response.statusCode}'));
        }
      }
      return handleResponse(response);
    } on http.ClientException {
      return left(PackageError());
    } on SocketException {
      return left(NetworkError());
    } on TimeoutException {
      return left(NetworkError());
    } catch (e) {
      debugPrint(e.toString());
      return left(UnhandledError(e.toString()));
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

sealed class ApiError<T> {}

class ClientError<T> implements ApiError<T> {
  T data;

  ClientError(this.data);
}

class ServerError<T> implements ApiError<T> {}

class PackageError<T> implements ApiError<T> {}

class NetworkError<T> implements ApiError<T> {}

class UnhandledError<T> implements ApiError<T> {
  final String message;

  UnhandledError(this.message);
}

@freezed
class Error with _$Error {
  const factory Error({
    required String code,
  }) = _Error;

  factory Error.fromJson(Map<String, Object?> json) => _$ErrorFromJson(json);
}

enum SmsError { failure, tooManyAttempts, badPhoneNumber }

enum AuthError {
  failure,
  badRequest,
  badCredential,
  credentialUsedForDifferentUid,
  noAccount,
  unknownUid,
  alreadyOwned,
  accountLinkFailure
}

typedef Id = String;

enum Gender { male, female }

enum Ownership { owned, unowned, unable }

enum OwnershipUnableReason { child, disabled, deceased }

enum Relationship { parent, sibling, spouse, child }

@Freezed(makeCollectionsUnmodifiable: false)
class Person with _$Person implements GraphNode {
  const factory Person({
    required Id id,
    required List<Id> parents,
    required List<Id> spouses,
    required List<Id> children,
    required Id addedBy,
    required Ownership ownership,
    required OwnershipUnableReason? ownershipUnableReason,
    @DateTimeConverter() required DateTime createdAt,
    @DateTimeConverter() DateTime? ownedAt,
    required Profile profile,
  }) = _Person;

  const Person._();

  bool get isAwaiting => ownership == Ownership.unowned;

  bool get isOwned => ownership == Ownership.owned;

  bool get isUnownable => ownership == Ownership.unable;

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
    required Gender? gender,
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

  String get fullName => firstName.isEmpty && lastName.isEmpty
      ? "Missing Name"
      : "$firstName $lastName";
}

class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String value) => DateTime.parse(value);

  @override
  String toJson(DateTime dateTime) => dateTime.toUtc().toIso8601String();
}
