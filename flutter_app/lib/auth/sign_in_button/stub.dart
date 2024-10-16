import 'dart:async';

import 'package:flutter/material.dart';

typedef Callback = Future<void> Function();

/// May or may not call the [onPressed] callback depending on the platform.
Widget buildSignInButton({Callback? onPressed}) {
  return Container();
}
