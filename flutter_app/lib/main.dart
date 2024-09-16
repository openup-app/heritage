import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/heritage_app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();

  const serverBaseUrl = String.fromEnvironment('SERVER_BASE_URL');
  final api = Api(
    baseUrl: serverBaseUrl,
    appVersionName: packageInfo.version,
    appVersionCode: packageInfo.buildNumber,
  );

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  await SentryFlutter.init(
    (options) => options.dsn = sentryDsn,
    appRunner: () => runApp(
      HeritageApp(
        api: api,
      ),
    ),
  );
}
