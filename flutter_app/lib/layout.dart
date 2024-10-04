import 'package:flutter/material.dart';

enum LayoutType { large, small }

class LayoutWidget extends StatelessWidget {
  final Widget child;

  const LayoutWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Layout(
          type:
              constraints.maxWidth <= 500 ? LayoutType.small : LayoutType.large,
          child: child,
        );
      },
    );
  }
}

class Layout extends InheritedWidget {
  final LayoutType type;

  const Layout({
    super.key,
    required this.type,
    required super.child,
  });

  static LayoutType of(BuildContext context) {
    final layout = context.dependOnInheritedWidgetOfExactType<Layout>();
    if (layout == null) {
      throw 'Missing inherited Layout';
    }
    return layout.type;
  }

  @override
  bool updateShouldNotify(covariant Layout oldWidget) {
    return oldWidget.type != type;
  }
}
