import 'package:flutter/material.dart';

import 'stub.dart';

/// Will call the [onPressed] callback.
Widget buildSignInButton({Callback? onPressed}) {
  return ElevatedButton(
    onPressed: onPressed,
    child: const Text('Sign In'),
  );
}
