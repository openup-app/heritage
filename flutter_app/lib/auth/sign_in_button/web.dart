import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'stub.dart';

// Will not call the [onPressed] callback.
Widget buildSignInButton({Callback? onPressed}) {
  return SizedBox(
    height: 40,
    child: web.renderButton(
      configuration: web.GSIButtonConfiguration(
        text: web.GSIButtonText.signupWith,
        logoAlignment: web.GSIButtonLogoAlignment.center,
        minimumWidth: 400,
        size: web.GSIButtonSize.large,
      ),
    ),
  );
}
