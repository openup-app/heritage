import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/error_page.dart';
import 'package:heritage/tree_test_page.dart';

class HeritageApp extends StatelessWidget {
  final Api api;

  const HeritageApp({
    super.key,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(api),
      ],
      child: _RouterBuilder(
        builder: (context, router) {
          return MaterialApp.router(
            routerConfig: router,
            title: 'Family Tree',
          );
        },
      ),
    );
  }
}

class _RouterBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, GoRouter router) builder;

  const _RouterBuilder({
    super.key,
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
  Widget build(BuildContext context) {
    return widget.builder(context, _router);
  }

  GoRouter _initRouter() {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      initialLocation: '/',
      errorBuilder: (context, state) => const ErrorPage(),
      routes: [
        GoRoute(
          path: '/',
          name: 'initial',
          builder: (context, state) {
            return const TreeTestPage();
          },
        ),
      ],
    );
  }
}
