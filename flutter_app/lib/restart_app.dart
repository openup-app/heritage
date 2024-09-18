import 'package:flutter/widgets.dart';

/// Enables the app below this widget to be restarted by calling
/// [RestartApp.of(context).restart()].
class RestartApp extends StatefulWidget {
  final Widget child;

  const RestartApp({
    super.key,
    required this.child,
  });

  /// Restarts the app below the nearest [RestartApp].
  static RestartAppState of(BuildContext context) {
    return context.findAncestorStateOfType<RestartAppState>()!;
  }

  @override
  RestartAppState createState() => RestartAppState();
}

class RestartAppState extends State<RestartApp> {
  Key _resetKey = UniqueKey();

  void restart() => setState(() => _resetKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _resetKey,
      child: widget.child,
    );
  }
}
