import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heritage/api.dart';
import 'package:heritage/authentication.dart';
import 'package:heritage/heritage_app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  // Used to init GoogleSignIn before the web-only renderButton()
  googleSignIn = GoogleSignIn(
    clientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
    scopes: ['email'],
  );

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    ),
  );

  runApp(
    HeritageApp(
      api: api,
      redirectPath: redirect,
    ),
  );
}
