import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heritage/util.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> showHelpDialog({
  required BuildContext context,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const AppVersion(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: launchEmail,
              style: FilledButton.styleFrom(
                fixedSize: const Size.fromHeight(48),
              ),
              child: const Text('Contact us'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

class AppVersion extends StatefulWidget {
  const AppVersion({super.key});

  @override
  State<AppVersion> createState() => _AppVersionState();
}

class _AppVersionState extends State<AppVersion> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _getPackageInfo();
  }

  void _getPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = packageInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = _packageInfo;
    if (packageInfo == null) {
      return const SizedBox.shrink();
    }
    final appName = kIsWeb ? 'Stitchfam' : packageInfo.appName;
    return Text('$appName - ${packageInfo.version}');
  }
}
