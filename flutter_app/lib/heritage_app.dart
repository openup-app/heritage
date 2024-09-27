import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/error_page.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/menu_page.dart';
import 'package:heritage/restart_app.dart';

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
        child: LayoutWidget(
          child: _RouterBuilder(
            redirectPath: redirectPath,
            navigatorObservers: [
              SentryNavigatorObserver(),
            ],
            builder: (context, router) {
              return MaterialApp.router(
                routerConfig: router,
                title: 'Family Tree',
                supportedLocales: const [
                  Locale('en'),
                  Locale('en', 'AU'),
                ],
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
                  dialogTheme: const DialogTheme(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(16),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
      initialLocation: widget.redirectPath ?? '/',
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
              final (:focalNode, :nodes) = _makeManyAncestoryTree();
              // final (:focalNode, :nodes) = _makeWideTree();
              // final (:focalNode, :nodes) = _makeTallTree();
              return Scaffold(
                body: GraphView<Node>(
                  focalNodeId: focalNode.id,
                  nodes: nodes,
                  spacing: const Spacing(
                    level: 40,
                    sibling: 8,
                    spouse: 2,
                  ),
                  nodeBuilder: (context, node, key) {
                    return Container(
                      key: key,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade300,
                      ),
                      child: Text(
                        node.id,
                        style: const TextStyle(fontSize: 24),
                      ),
                    );
                  },
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
            return FamilyTreeLoadingPage(
              focalNodeId: focalNodeId,
              child: const FamilyTreePage(),
            );
          },
          routes: [
            GoRoute(
              path: 'perspective/:perspectiveNodeId',
              name: 'perspective',
              builder: (context, state) {
                final focalNodeId = state.pathParameters['perspectiveNodeId'];
                if (focalNodeId == null) {
                  throw 'Missing focalNodeId';
                }
                return FamilyTreeLoadingPage(
                  focalNodeId: focalNodeId,
                  child: const FamilyTreePage(
                    isPerspectiveMode: true,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

({Node focalNode, List<Node> nodes}) _generateRandomTree(int totalNodes) {
  final random = Random();
  final nodes = List.generate(totalNodes, (i) => _createNode('$i'));

  for (var i = 1; i < totalNodes; i++) {
    final parentIndex = random.nextInt(i);
    final parent = nodes[parentIndex];
    final child = nodes[i];
    parent.children.add(child.id);
  }

  return (focalNode: nodes[random.nextInt(totalNodes)], nodes: nodes);
}

({Node focalNode, List<Node> nodes}) _makeTallTree() {
  final nodes = List.generate(34, (i) => _createNode('$i'));

  connect(nodes, spouseA: 0, spouseB: 1, children: [2, 4]);
  connect(nodes, spouseA: 3, spouseB: 4, children: [7, 8, 10]);
  connect(nodes, spouseA: 9, spouseB: 10, children: [16]);
  connect(nodes, spouseA: 15, spouseB: 16, children: [19]);
  connect(nodes, spouseA: 19, spouseB: 20, children: [24, 25, 27]);
  connect(nodes, spouseA: 23, spouseB: 24, children: []);
  connect(nodes, spouseA: 26, spouseB: 27, children: [28, 29, 30]);

  connect(nodes, spouseA: 5, spouseB: 6, children: [/*12*,*/ 13]);
  // connect(spouseA: 11, spouseB: 12, children: []);
  connect(nodes, spouseA: 13, spouseB: 14, children: [18]);
  connect(nodes, spouseA: 17, spouseB: 18, children: [20, 22]);
  connect(nodes, spouseA: 21, spouseB: 22, children: []);

  connect(nodes, spouseA: 25, spouseB: 31, children: [32, 33]);

  final focalNode = nodes[25];
  return (focalNode: focalNode, nodes: nodes);
}

({Node focalNode, List<Node> nodes}) _makeWideTree() {
  final nodes = List.generate(40, (i) => _createNode('$i'));

  connect(nodes,
      spouseA: 0,
      spouseB: 1,
      children: [5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 24]);
  connect(nodes, spouseA: 2, spouseB: 3, children: [25, 27]);

  connect(nodes, spouseA: 4, spouseB: 5, children: []);
  connect(nodes, spouseA: 6, spouseB: 7, children: []);
  connect(nodes,
      spouseA: 8, spouseB: 9, children: [28, 29, 30, 31, 32, 33, 34, 35]);
  connect(nodes, spouseA: 10, spouseB: 11, children: []);
  connect(nodes, spouseA: 12, spouseB: 13, children: []);
  connect(nodes, spouseA: 14, spouseB: 15, children: []);
  connect(nodes, spouseA: 16, spouseB: 17, children: []);
  connect(nodes, spouseA: 18, spouseB: 19, children: []);
  connect(nodes, spouseA: 20, spouseB: 21, children: []);
  connect(nodes, spouseA: 22, spouseB: 23, children: []);
  connect(nodes, spouseA: 24, spouseB: 25, children: [37, 39]);

  connect(nodes, spouseA: 26, spouseB: 27, children: []);

  connect(nodes, spouseA: 36, spouseB: 37, children: []);
  connect(nodes, spouseA: 38, spouseB: 39, children: []);

  final focalNode = nodes[37];
  return (focalNode: focalNode, nodes: nodes);
}

({Node focalNode, List<Node> nodes}) _makeManyAncestoryTree() {
  final nodes = List.generate(35, (i) => _createNode('$i'));

  connect(nodes, spouseA: 0, spouseB: 1, children: [5]);
  connect(nodes, spouseA: 2, spouseB: 3, children: [9, 11]);

  connect(nodes, spouseA: 4, spouseB: 5, children: [14, 15]);
  connect(nodes, spouseA: 6, spouseB: 7, children: [16, 17]);
  connect(nodes, spouseA: 8, spouseB: 9, children: [18, 19]);
  connect(nodes, spouseA: 10, spouseB: 11, children: []);
  connect(nodes, spouseA: 12, spouseB: 13, children: [20, 22]);

  connect(nodes, spouseA: 15, spouseB: 16, children: [23, 24, 25]);
  connect(nodes, spouseA: 19, spouseB: 20, children: [26, 28, 30]);
  connect(nodes, spouseA: 21, spouseB: 22, children: []);
  connect(nodes, spouseA: 25, spouseB: 26, children: [32]);
  connect(nodes, spouseA: 27, spouseB: 28, children: []);

  connect(nodes, spouseA: 29, spouseB: 30, children: []);

  connect(nodes, spouseA: 31, spouseB: 32, children: []);
  connect(nodes, spouseA: 33, spouseB: 34, children: [8]);

  final focalNode = nodes[32];
  return (focalNode: focalNode, nodes: nodes);
}

void connect(
  List<Node> nodes, {
  required int spouseA,
  required int spouseB,
  required List<int> children,
}) {
  nodes[spouseA].spouses.add(nodes[spouseB].id);
  nodes[spouseB].spouses.add(nodes[spouseA].id);
  nodes[spouseA].children.addAll(children.map((e) => nodes[e].id));
  nodes[spouseB].children.addAll(children.map((e) => nodes[e].id));
  for (final childIndex in children) {
    nodes[childIndex].parents.addAll([nodes[spouseA].id, nodes[spouseB].id]);
  }
}

Node _createNode(String id) {
  return Node(
    id: id,
    parents: [],
    children: [],
    spouses: [],
    addedBy: '',
    ownedBy: '',
    createdAt: DateTime.now(),
    profile: Profile(
      name: id,
      gender: Gender.male,
      imageUrl:
          'https://d2xzkuyodufiic.cloudfront.net/avatars/${int.parse(id) + 1 % 70}.jpg',
      birthday: null,
      deathday: null,
      birthplace: '',
    ),
  );
}
