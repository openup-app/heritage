import 'dart:async';
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
          'Content-Type': 'application/json',
          'X-App-Version-Name': appVersionName,
          'X-App-Version-Code': appVersionCode,
          'X-App-Platform': _platformName(),
        };

  void setAuthToken(String? authToken) {
    if (authToken == null) {
      _headers.remove('Authorization');
    } else {
      _headers['Authorization'] = 'Bearer $authToken';
    }
  }

  Future<Either<Error, void>> getTest() async {
    final url = Uri.parse('$_baseUrl/v1/');
    try {
      final result = await http
          .get(
            url,
            headers: _headers,
          )
          .timeout(_kTimeout);

      if (result.statusCode != 200) {
        return left('Status ${result.statusCode}');
      }
      return right(null);
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
