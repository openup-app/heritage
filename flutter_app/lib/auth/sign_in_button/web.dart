import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'stub.dart';

// Will not call the [onPressed] callback.
Widget buildSignInButton({Callback? onPressed}) {
  return web.renderButton();
}
