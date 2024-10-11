import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/error_page.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/landing_page.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/menu_page.dart';
import 'package:heritage/restart_app.dart';
import 'package:heritage/storage.dart';
import 'package:heritage/transition.dart';
import 'package:heritage/util.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

part 'heritage_app.freezed.dart';
part 'heritage_app.g.dart';

const primaryColor = Color.fromRGBO(0x2A, 0xBB, 0xFF, 1.0);
const greyColor = Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0);
const unselectedColor = Color.fromRGBO(175, 175, 175, 1);

class HeritageApp extends StatelessWidget {
  final Api api;
  final Storage storage;
  final String? redirectPath;

  const HeritageApp({
    super.key,
    required this.api,
    required this.storage,
    required this.redirectPath,
  });

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      fontFamily: 'SF Pro Display',
    );
    const subtitleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: 'SF Pro Display',
    );
    const miniTitleStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: 'SF Pro Display',
    );
    return RestartApp(
      child: ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
        ],
        child: LayoutWidget(
          child: _CacheAssets(
            child: _RouterBuilder(
              redirectPath: redirectPath,
              navigatorObservers: [SentryNavigatorObserver()],
              tempApi: api,
              storage: storage,
              builder: (context, router) {
                return MaterialApp.router(
                  routerConfig: router,
                  title: 'Stitchfam',
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
                        elevation: 0,
                        foregroundColor: Colors.black,
                        backgroundColor:
                            const Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
                        padding: EdgeInsets.zero,
                        textStyle: subtitleStyle,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    outlinedButtonTheme: OutlinedButtonThemeData(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        textStyle: subtitleStyle,
                        padding: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                      textStyle: subtitleStyle,
                    )),
                    textTheme: const TextTheme(
                      displayLarge: titleStyle,
                      displayMedium: titleStyle,
                      displaySmall: titleStyle,
                      headlineLarge: titleStyle,
                      headlineMedium: titleStyle,
                      headlineSmall: titleStyle,
                      titleLarge: titleStyle,
                      titleMedium: subtitleStyle,
                      titleSmall: subtitleStyle,
                      bodyLarge: subtitleStyle,
                      bodyMedium: subtitleStyle,
                      bodySmall: miniTitleStyle,
                      labelLarge: miniTitleStyle,
                      labelMedium: miniTitleStyle,
                      labelSmall: miniTitleStyle,
                    ),
                    disabledColor: Colors.black,
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: true,
                      fillColor: greyColor,
                      outlineBorder: BorderSide.none,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    scrollbarTheme: const ScrollbarThemeData(
                      thumbColor: WidgetStatePropertyAll(Colors.grey),
                      thumbVisibility: WidgetStatePropertyAll(true),
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
      ),
    );
  }
}

class _RouterBuilder extends StatefulWidget {
  final String? redirectPath;
  final List<NavigatorObserver> navigatorObservers;
  final Api tempApi;
  final Storage storage;
  final Widget Function(BuildContext context, GoRouter router) builder;

  const _RouterBuilder({
    super.key,
    required this.redirectPath,
    required this.navigatorObservers,
    required this.tempApi,
    required this.storage,
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
    String? initialLocation;
    Id? referrerId;
    ViewHistory? viewHistory;
    final redirectPath = widget.redirectPath;
    if (redirectPath != null && redirectPath.startsWith('/login/')) {
      final focalUserId = redirectPath.substring(7);
      initialLocation = '/view';
      viewHistory = ViewHistory(primaryUserId: focalUserId);
    } else if (redirectPath != null && redirectPath.startsWith('/invite/')) {
      final base = redirectPath.substring(8);
      final tokens = base.split(':');
      if (tokens case [Id focalUserId, Id referrer]) {
        initialLocation = '/view';
        referrerId = referrer;
        viewHistory = ViewHistory(primaryUserId: focalUserId);
      } else {
        initialLocation = '/?status=failure';
      }
    } else if (redirectPath != null) {
      initialLocation = '/?status=failure';
    }

    _router = _initRouter(
      initialLocation: initialLocation,
      initialExtra: viewHistory,
      referrerId: referrerId,
    );
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

  GoRouter _initRouter({
    String? initialLocation,
    Object? initialExtra,
    Id? referrerId,
  }) {
    return GoRouter(
      debugLogDiagnostics: kDebugMode,
      observers: widget.navigatorObservers,
      initialLocation: kDebugMode ? '/menu' : initialLocation ?? '/',
      overridePlatformDefaultLocation: true,
      initialExtra: initialExtra,
      extraCodec: const _ExtraCodec(),
      errorBuilder: (context, state) => const ErrorPage(),
      routes: [
        GoRoute(
          path: '/',
          name: 'landing',
          pageBuilder: (context, state) {
            final statusString = state.uri.queryParameters['status'];
            final status = statusString == 'failure'
                ? LandingPageStatus.invalidLink
                : statusString == 'decline'
                    ? LandingPageStatus.decline
                    : null;
            return TopLevelTransitionPage(
              child: LandingPage(
                storage: widget.storage,
                status: status,
              ),
            );
          },
        ),
        if (kDebugMode)
          GoRoute(
            path: '/menu',
            name: 'menu',
            pageBuilder: (context, state) {
              return const TopLevelTransitionPage(
                child: MenuPage(),
              );
            },
          ),
        if (kDebugMode)
          GoRoute(
            path: '/test_layout',
            name: 'test_layout',
            builder: (context, state) {
              final (:focalPerson, :people) = _makeManyAncestoryTree();
              // final (:focalPerson, :people) = _makeWideTree();
              // final (:focalPerson, :people) = _makeTallTree();
              // final (:focalPerson, :people) = _makeJumbledTree();
              final nodeKeys = people.map((e) => (e, GlobalKey())).toList();
              const spacing = Spacing(
                level: 40,
                sibling: 30,
                spouse: 4,
              );
              return Scaffold(
                body: GraphView<Person>(
                  focalNodeId: focalPerson.id,
                  nodeKeys: nodeKeys,
                  spacing: spacing,
                  builder: (context, nodes, child) {
                    return Stack(
                      children: [
                        Edges(
                          idToKey: Map.fromEntries(
                              nodeKeys.map((e) => MapEntry(e.$1.id, e.$2))),
                          idToNode: nodes,
                          focalPersonId: focalPerson.id,
                          isPrimaryPerson: true,
                          spacing: spacing,
                          transform: Matrix4.identity(),
                          child: child,
                        ),
                      ],
                    );
                  },
                  nodeBuilder: (context, data, node, key) {
                    return Container(
                      key: key,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: node.isAncestor
                            ? Colors.orange.shade300
                            : Colors.blue.shade300,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            data.id,
                            style: const TextStyle(fontSize: 24),
                          ),
                          if (node.shouldBeRightChild && node.isAncestor)
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'R',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (!node.shouldBeRightChild && node.isAncestor)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'L',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        GoRoute(
          path: '/view',
          name: 'view',
          pageBuilder: (context, state) {
            final viewHistory = state.extra as ViewHistory?;
            if (viewHistory == null) {
              return const TopLevelTransitionPage(
                child: ErrorPage(),
              );
            }
            final focalPersonId =
                viewHistory.perspectiveUserId ?? viewHistory.primaryUserId;

            // TODO: Probably best to set UID as a provider that apiProvider depends on
            if (viewHistory.perspectiveUserId == null) {
              widget.tempApi.setUid(focalPersonId);
            }

            final isPersectiveMode = viewHistory.perspectiveUserId != null;
            return TopLevelTransitionPage(
              key: ValueKey(focalPersonId),
              child: ProviderScope(
                overrides: [
                  focalPersonIdProvider.overrideWith((ref) => focalPersonId),
                ],
                child: FamilyTreeLoadingPage(
                  isPerspectiveMode: isPersectiveMode,
                  isInvite: referrerId != null,
                  onReady: () {
                    if (!isPersectiveMode) {
                      widget.storage.saveUid(focalPersonId);
                    }
                  },
                  onError: () {
                    final uid = widget.storage.loadUid();
                    if (uid == focalPersonId) {
                      widget.storage.clearUid();
                    }
                    _router.goNamed(
                      'landing',
                      queryParameters: {'status': 'failure'},
                    );
                  },
                  child: FamilyTreePage(
                    referrerId: referrerId,
                    viewHistory: viewHistory,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CacheAssets extends StatefulWidget {
  final Widget child;

  const _CacheAssets({
    super.key,
    required this.child,
  });

  @override
  State<_CacheAssets> createState() => _CacheAssetsState();
}

class _CacheAssetsState extends State<_CacheAssets> {
  bool _cached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cached) {
      _cached = true;
      const assets = [
        'assets/images/binoculars.png',
        'assets/images/logo_text.png',
        'assets/images/perspective_portal.png',
        'assets/images/tagline.png',
        'assets/images/tree_background.png',
      ];
      for (final asset in assets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _ExtraCodec extends Codec {
  const _ExtraCodec();

  @override
  Converter get decoder => const _ExtraDecoder();

  @override
  Converter get encoder => const _ExtraEncoder();
}

class _ExtraDecoder extends Converter<Object?, Object?> {
  const _ExtraDecoder();

  @override
  Object? convert(Object? input) {
    if (input == null) {
      return null;
    }
    final inputAsMap = input as Map<String, Object?>;
    final key = inputAsMap.entries.firstOrNull?.key;
    final value = inputAsMap.entries.firstOrNull?.value;
    final json = jsonDecode(value as String);
    return switch (key) {
      'ViewHistory' => ViewHistory.fromJson(json),
      _ => throw 'Unable to decode $key',
    };
  }
}

class _ExtraEncoder extends Converter<Object?, Object?> {
  const _ExtraEncoder();

  @override
  Object? convert(Object? input) {
    if (input == null) {
      return null;
    }
    return switch (input) {
      ViewHistory() => {'ViewHistory': jsonEncode(input.toJson())},
      _ => throw 'Cannot encode type ${input.runtimeType}',
    };
  }
}

@freezed
class ViewHistory with _$ViewHistory {
  const factory ViewHistory({
    required String primaryUserId,
    @Default(null) String? perspectiveUserId,
  }) = _ViewHistory;

  factory ViewHistory.fromJson(Map<String, Object?> json) =>
      _$ViewHistoryFromJson(json);
}

({Person focalPerson, List<Person> people}) _generateRandomTree(
    int totalPeople) {
  final random = Random();
  final people = List.generate(totalPeople, (i) => _createPerson('$i'));

  for (var i = 1; i < totalPeople; i++) {
    final parentIndex = random.nextInt(i);
    final parent = people[parentIndex];
    final child = people[i];
    parent.children.add(child.id);
  }

  return (focalPerson: people[random.nextInt(totalPeople)], people: people);
}

({Person focalPerson, List<Person> people}) _makeTallTree() {
  final people = List.generate(34, (i) => _createPerson('$i'));

  connect(people, spouseA: 0, spouseB: 1, children: [2, 4]);
  connect(people, spouseA: 3, spouseB: 4, children: [7, 8, 10]);
  connect(people, spouseA: 9, spouseB: 10, children: [16]);
  connect(people, spouseA: 15, spouseB: 16, children: [19]);
  connect(people, spouseA: 19, spouseB: 20, children: [24, 25, 27]);
  connect(people, spouseA: 23, spouseB: 24, children: []);
  connect(people, spouseA: 26, spouseB: 27, children: [28, 29, 30]);

  connect(people, spouseA: 5, spouseB: 6, children: [/*12*,*/ 13]);
  // connect(spouseA: 11, spouseB: 12, children: []);
  connect(people, spouseA: 13, spouseB: 14, children: [18]);
  connect(people, spouseA: 17, spouseB: 18, children: [20, 22]);
  connect(people, spouseA: 21, spouseB: 22, children: []);

  connect(people, spouseA: 25, spouseB: 31, children: [32, 33]);

  final focalPerson = people[25];
  return (focalPerson: focalPerson, people: people);
}

({Person focalPerson, List<Person> people}) _makeWideTree() {
  final people = List.generate(40, (i) => _createPerson('$i'));

  connect(people,
      spouseA: 0,
      spouseB: 1,
      children: [5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 24]);
  connect(people, spouseA: 2, spouseB: 3, children: [25, 27]);

  connect(people, spouseA: 4, spouseB: 5, children: []);
  connect(people, spouseA: 6, spouseB: 7, children: []);
  connect(people,
      spouseA: 8, spouseB: 9, children: [28, 29, 30, 31, 32, 33, 34, 35]);
  connect(people, spouseA: 10, spouseB: 11, children: []);
  connect(people, spouseA: 12, spouseB: 13, children: []);
  connect(people, spouseA: 14, spouseB: 15, children: []);
  connect(people, spouseA: 16, spouseB: 17, children: []);
  connect(people, spouseA: 18, spouseB: 19, children: []);
  connect(people, spouseA: 20, spouseB: 21, children: []);
  connect(people, spouseA: 22, spouseB: 23, children: []);
  connect(people, spouseA: 24, spouseB: 25, children: [37, 39]);

  connect(people, spouseA: 26, spouseB: 27, children: []);

  connect(people, spouseA: 36, spouseB: 37, children: []);
  connect(people, spouseA: 38, spouseB: 39, children: []);

  final focalPerson = people[37];
  return (focalPerson: focalPerson, people: people);
}

({Person focalPerson, List<Person> people}) _makeManyAncestoryTree() {
  final people = List.generate(35, (i) => _createPerson('$i'));

  connect(people, spouseA: 0, spouseB: 1, children: [5]);
  connect(people, spouseA: 2, spouseB: 3, children: [9, 11]);

  connect(people, spouseA: 4, spouseB: 5, children: [14, 15]);
  connect(people, spouseA: 6, spouseB: 7, children: [16, 17]);
  connect(people, spouseA: 8, spouseB: 9, children: [18, 19]);
  connect(people, spouseA: 10, spouseB: 11, children: []);
  connect(people, spouseA: 12, spouseB: 13, children: [20, 22]);

  connect(people, spouseA: 15, spouseB: 16, children: [23, 24, 25]);
  connect(people, spouseA: 19, spouseB: 20, children: [26, 28, 30]);
  connect(people, spouseA: 21, spouseB: 22, children: []);
  connect(people, spouseA: 25, spouseB: 26, children: [32]);
  connect(people, spouseA: 27, spouseB: 28, children: []);

  connect(people, spouseA: 29, spouseB: 30, children: []);

  connect(people, spouseA: 31, spouseB: 32, children: []);
  connect(people, spouseA: 33, spouseB: 34, children: [8]);

  final focalPerson = people[32];
  return (focalPerson: focalPerson, people: people);
}

({Person focalPerson, List<Person> people}) _makeJumbledTree() {
  final people = List.generate(21, (i) => _createPerson('$i'));

  connect(people, spouseA: 19, spouseB: 15, children: [10, 11]);
  connect(people, spouseA: 16, spouseB: 6, children: [0, 1]);

  connect(people, spouseA: 9, spouseB: 20, children: [14, 2]);
  connect(people, spouseA: 11, spouseB: 0, children: [3, 17, 18]);
  connect(people, spouseA: 13, spouseB: 14, children: [4, 5, 7]);
  connect(people, spouseA: 18, spouseB: 4, children: [8, 12]);

  final focalPerson = people[8];
  return (focalPerson: focalPerson, people: people..shuffle());
}

void connect(
  List<Person> people, {
  required int spouseA,
  required int spouseB,
  required List<int> children,
}) {
  people[spouseA].spouses.add(people[spouseB].id);
  people[spouseB].spouses.add(people[spouseA].id);
  people[spouseA].children.addAll(children.map((e) => people[e].id));
  people[spouseB].children.addAll(children.map((e) => people[e].id));
  for (final childIndex in children) {
    people[childIndex].parents.addAll([people[spouseA].id, people[spouseB].id]);
  }
}

Person _createPerson(String id) {
  return Person(
    id: id,
    parents: [],
    children: [],
    spouses: [],
    addedBy: '',
    ownedBy: '',
    createdAt: DateTime.now(),
    profile: Profile(
      firstName: id,
      lastName: '',
      gender: Gender.male,
      photo: Photo.network(
        key: '',
        url: '$cdn/avatars/${int.parse(id) + 1 % 70}.jpg',
      ),
      gallery: [],
      birthday: null,
      deathday: null,
      birthplace: '',
      occupation: '',
      hobbies: '',
    ),
  );
}
