import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/authentication.dart';

class AuthStateListener extends ConsumerStatefulWidget {
  final void Function(AuthUser? user) onAuthStateChanged;
  final Widget child;

  const AuthStateListener({
    super.key,
    required this.onAuthStateChanged,
    required this.child,
  });

  @override
  ConsumerState<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends ConsumerState<AuthStateListener> {
  @override
  void initState() {
    super.initState();
    bool first = true;
    ref.listenManual(
      authProvider,
      fireImmediately: true,
      (_, next) {
        if (first) {
          WidgetsBinding.instance.endOfFrame.then((_) {
            first = false;
            if (mounted) {
              widget.onAuthStateChanged(next);
            }
          });
        } else {
          widget.onAuthStateChanged(next);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
