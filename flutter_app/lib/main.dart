import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:heritage/api.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  await SentryFlutter.init(
    (options) => options.dsn = sentryDsn,
    appRunner: init,
  );
}

void init() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // App nav misses address bar pastes/typing. So 404.html redirects to
  // index.html with the original path as a query param, so app can handle it
  final redirect = Uri.base.queryParameters['redirect'];

  final packageInfo = await PackageInfo.fromPlatform();

  const serverBaseUrl = String.fromEnvironment('SERVER_BASE_URL');
  final api = Api(
    baseUrl: serverBaseUrl,
    appVersionName: packageInfo.version,
    appVersionCode: packageInfo.buildNumber,
  );

  final sharedPreferences = await SharedPreferences.getInstance();
  final storage = Storage(sharedPreferences: sharedPreferences);
  final uid = storage.loadUid();
  final redirectPath = uid != null ? '/invite/$uid' : redirect;

  runApp(
    HeritageApp(
      api: api,
      storage: storage,
      redirectPath: redirectPath,
    ),
  );
}
