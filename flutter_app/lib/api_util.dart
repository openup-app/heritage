import 'package:flutter/material.dart';
import 'package:heritage/api.dart';

Future<void> showErrorMessage({
  required BuildContext context,
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Okay'),
          )
        ],
      );
    },
  );
}

String smsErrorToMessage(ApiError<SmsError> error) {
  return switch (error) {
    ClientError(:final data) => switch (data) {
        SmsError.failure => 'Something went wrong, please try again',
        SmsError.tooManyAttempts => 'Too many attempts, please try again later',
        SmsError.badPhoneNumber =>
          'Unable to send code, ensure the phone number is correct',
      },
    ServerError() => 'Something went wrong on our end, please try again',
    NetworkError() =>
      'There was a network connection problem, please try again',
    PackageError() || UnhandledError() => 'An error occurred, please try again',
  };
}

String authErrorToMessage(
  ApiError<AuthError> error, {
  required bool isGoogleOauth,
}) {
  return switch (error) {
    ClientError(:final data) => switch (data) {
        AuthError.failure => 'Something went wrong, please try again',
        AuthError.badRequest => 'Something went wrong',
        AuthError.badCredential =>
          isGoogleOauth ? 'Failed to sign in with Google' : 'Invalid code',
        AuthError.credentialUsedForDifferentUid =>
          '${isGoogleOauth ? 'Email' : 'Phone number'} already used for a different profile',
        AuthError.noAccount =>
          'Unable to find your account. Stitchfam is invite only',
        AuthError.unknownUid => 'Unable to find profile',
        AuthError.alreadyOwned => 'This profile has already been claimed',
        AuthError.accountLinkFailure => 'Unable to claim the profile',
      },
    ServerError() => 'Something went wrong on our end, please try again',
    NetworkError() =>
      'There was a network connection problem, please try again',
    PackageError() || UnhandledError() => 'An error occurred, please try again',
  };
}
