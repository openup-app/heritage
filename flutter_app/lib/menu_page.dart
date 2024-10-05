import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/help.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/loading_page.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  bool _loading = false;

  List<Person>? _roots;

  @override
  void initState() {
    super.initState();
    _getRoots();
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots;
    return Scaffold(
      body: _roots == null
          ? const LoadingPage()
          : Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top,
                ),
                const SizedBox(height: 16),
                const AppVersion(),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            final result = await showDialog<
                                (
                                  String firstName,
                                  String lastName,
                                  Gender gender
                                )>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Start a family tree'),
                                  content:
                                      Consumer(builder: (context, ref, child) {
                                    return CreateRootDisplay(
                                      padding: const EdgeInsets.all(16),
                                      onDone: (firstName, lastName, gender) {
                                        Navigator.of(context)
                                            .pop((firstName, lastName, gender));
                                      },
                                    );
                                  }),
                                );
                              },
                            );
                            if (!mounted || result == null) {
                              return;
                            }
                            _start(result.$1, result.$2, result.$3);
                          },
                    child: _loading
                        ? const CircularProgressIndicator.adaptive()
                        : const Text('Start a family tree'),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Open an existing tree (Debug)',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (roots == null)
                  const SizedBox.shrink()
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: roots.length,
                      itemBuilder: (context, index) {
                        final person = roots[index];
                        return ListTile(
                          onTap: () => _navigate(person.id),
                          title: Text(
                              '${person.profile.fullName} (${person.profile.gender.name})'),
                          subtitle: Text(person.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  void _getRoots() async {
    final api = ref.read(apiProvider);
    final result = await api.getRoots();
    if (!mounted) {
      return;
    }
    result.fold(
      (l) => setState(() {}),
      (r) => setState(() => _roots = r),
    );
  }

  void _start(String firstName, String lastName, Gender gender) async {
    final api = ref.read(apiProvider);
    setState(() => _loading = true);
    final result = await api.createRoot(
        firstName: firstName, lastName: lastName, gender: gender);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
    result.fold(
      (l) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l))),
      (r) => _navigate(r.id),
    );
  }

  void _navigate(String focalPersonId) async {
    context.goNamed(
      'view',
      extra: ViewHistory(
        primaryUserId: focalPersonId,
      ),
    );
  }
}
