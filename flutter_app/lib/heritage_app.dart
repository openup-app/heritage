import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/error_page.dart';
import 'package:heritage/menu_page.dart';
import 'package:heritage/restart_app.dart';
import 'package:heritage/tree_test_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const primaryColor = Color.fromRGBO(0x00, 0xAE, 0xFF, 1.0);
const greyColor = Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0);
const unselectedColor = Color.fromRGBO(175, 175, 175, 1);

class HeritageApp extends StatelessWidget {
  final String? redirectPath;
  final Api api;

  const HeritageApp({
    super.key,
    required this.redirectPath,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return RestartApp(
      child: ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
        ],
        child: _RouterBuilder(
          redirectPath: redirectPath,
          navigatorObservers: [
            SentryNavigatorObserver(),
          ],
          builder: (context, router) {
            return MaterialApp.router(
              routerConfig: router,
              title: 'Family Tree',
              theme: ThemeData(
                useMaterial3: false,
                fontFamily: 'SF Pro Display',
                primaryColor: primaryColor,
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: greyColor,
                  outlineBorder: BorderSide.none,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouterBuilder extends StatefulWidget {
  final String? redirectPath;
  final List<NavigatorObserver> navigatorObservers;
  final Widget Function(BuildContext context, GoRouter router) builder;

  const _RouterBuilder({
    super.key,
    required this.redirectPath,
    required this.navigatorObservers,
    required this.builder,
  });

  @override
  State<_RouterBuilder> createState() => _RouterBuilderState();
}

class _RouterBuilderState extends State<_RouterBuilder> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _initRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _router);
  }

  GoRouter _initRouter() {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      observers: widget.navigatorObservers,
      initialLocation: kDebugMode ? '/test_layout' : widget.redirectPath ?? '/',
      overridePlatformDefaultLocation: true,
      errorBuilder: (context, state) => const ErrorPage(),
      routes: [
        GoRoute(
          path: '/',
          name: 'menu',
          builder: (context, state) {
            return const MenuPage();
          },
        ),
        if (kDebugMode)
          GoRoute(
            path: '/test_layout',
            name: 'test_layout',
            builder: (context, state) {
              final focalNode = makeManyAncestoryTree();
              // final focalNode = makeWideTree();
              // final focalNode = makeTallTree();
              return Scaffold(
                body: TreeTestPage(
                  focalNode: focalNode,
                ),
              );
            },
          ),
        GoRoute(
          path: '/:focalNodeId',
          name: 'view',
          onExit: (context, state) {
            RestartApp.of(context).restart();
            return Future.value(true);
          },
          builder: (context, state) {
            final focalNodeId = state.pathParameters['focalNodeId'];
            if (focalNodeId == null) {
              throw 'Missing focalNodeId';
            }
            return ViewPage(
              focalNodeId: focalNodeId,
            );
          },
        ),
      ],
    );
  }
}
