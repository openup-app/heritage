import 'dart:async';

import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Log in/out, token refresh trigger
final _firebaseUserProvider =
    StreamProvider((ref) => FirebaseAuth.instance.userChanges());

final _idTokenProvider = FutureProvider<String?>((ref) {
  final user = ref.watch(_firebaseUserProvider).asData?.value;
  if (user == null) {
    return Future.value();
  }
  return _getIdToken(user);
});

final _asyncAuthProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final user = ref.watch(_firebaseUserProvider);
  final idToken = ref.watch(_idTokenProvider).valueOrNull;
  return user.map(
    loading: (loading) => const AsyncLoading(),
    error: (error) => AsyncError(error.error, error.stackTrace),
    data: (data) {
      final user = data.value;
      return (user == null)
          ? const AsyncData(null)
          : AsyncData(
              AuthUser(
                uid: user.uid,
                linkedProviders: user.providerData
                    .map((authProvider) => SignInProvider.values
                        .firstWhereOrNull(
                            (e) => e.id == authProvider.providerId))
                    .whereNotNull()
                    .toList(),
                isAnonymous: user.isAnonymous,
                emailAddress: user.email,
                phoneNumber: user.phoneNumber,
                name: user.displayName,
                authToken: idToken,
              ),
            );
    },
  );
});

final authProvider =
    Provider((ref) => ref.watch(_asyncAuthProvider).valueOrNull);

class AuthUser {
  final String uid;
  final bool isAnonymous;
  final List<SignInProvider> linkedProviders;
  final String? emailAddress;
  final String? phoneNumber;
  final String? name;
  final String? authToken;

  const AuthUser({
    required this.uid,
    required this.isAnonymous,
    required this.linkedProviders,
    required this.emailAddress,
    required this.phoneNumber,
    required this.name,
    required this.authToken,
  });

  @override
  int get hashCode => Object.hash(uid, isAnonymous, linkedProviders,
      emailAddress, phoneNumber, name, authToken);

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.isAnonymous == isAnonymous &&
      const DeepCollectionEquality.unordered()
          .equals(linkedProviders, other.linkedProviders) &&
      other.emailAddress == emailAddress &&
      other.phoneNumber == phoneNumber &&
      other.name == name &&
      other.authToken == authToken;
}

late GoogleSignIn googleSignIn;

Future<void> _signOutGoogle() => GoogleSignIn.standard().signOut();

Future<void> signOut() async {
  _signOutGoogle();
  await FirebaseAuth.instance.signOut();
}

Future<void> deleteAccount() =>
    FirebaseAuth.instance.currentUser?.delete() ?? Future.value();

Future<void> signInAnonymously() => FirebaseAuth.instance.signInAnonymously();

Future<Either<AuthError, SignInCredential>> signInWithGoogle() async {
  return _requestGoogleAuthCredential();
}

Future<void> unlinkUser(SignInProvider provider) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }
  try {
    switch (provider) {
      case SignInProvider.google:
        _signOutGoogle();
      // case SignInProvider.phone:
      // Nothing to do
    }
    await user.unlink(provider.id);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'no-such-provider') {
      // Ignore
    } else {
      rethrow;
    }
  }
}

Future<AuthResult> linkUser(SignInProvider provider) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const AuthFailure(AuthError.failure);
  }
  final result = await switch (provider) {
    SignInProvider.google => _requestGoogleAuthCredential(),
  };
  return result.fold(
    (error) => AuthFailure(error),
    (credential) => _linkUserWithCredential(
      user,
      provider._firebaseProvider,
      credential,
    ),
  );
}

Future<AuthResult> _linkUserWithCredential(
  User user,
  AuthProvider provider,
  SignInCredential signIn,
) async {
  UserCredential userCredential;
  try {
    userCredential = await user.linkWithCredential(signIn.credential);
  } on FirebaseAuthException catch (e) {
    if (e.code == "provider-already-linked") {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == "invalid-credential") {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == "credential-already-in-use") {
      return _signInWithCredential(signIn.credential);
    } else if (e.code == "email-already-in-use") {
      return _signInWithCredential(signIn.credential);
    } else if (e.code == "operation-not-allowed") {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-email') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-verification-code') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-verification-id') {
      return const AuthFailure(AuthError.failure);
    } else {
      rethrow;
    }
  }

  await _maybeFixFirebaseNameAndEmail(
    userCredential,
    signIn.name,
    signIn.email,
  );
  return const AuthSuccess();
}

Future<AuthResult> _signInWithCredential(AuthCredential credential) async {
  try {
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      return const AuthSuccess();
    } else {
      return const AuthFailure(AuthError.failure);
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'account-exists-with-different-credential') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-credential') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'operation-not-allowed') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'user-disabled') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'user-not-found') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'wrong-password') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-verification-code') {
      return const AuthFailure(AuthError.failure);
    } else if (e.code == 'invalid-verification-id') {
      return const AuthFailure(AuthError.failure);
    } else {
      rethrow;
    }
  }
}

Future<bool> signInWithCustomToken(String token) async {
  try {
    final result = await FirebaseAuth.instance.signInWithCustomToken(token);
    final user = result.user;
    if (user != null) {
      return true;
    } else {
      return false;
    }
  } on FirebaseAuthException catch (e, s) {
    if (e.code == 'custom-token-mismatch') {
      return false;
    } else if (e.code == 'invalid-custom-token') {
      return false;
    } else {
      debugPrint(e.code);
      Sentry.captureException(e, stackTrace: s);
      return false;
    }
  }
}

Future<Either<AuthError, SignInCredential>>
    _requestGoogleAuthCredential() async {
  GoogleSignInAccount? googleUser;
  try {
    googleUser = await googleSignIn.signIn();
  } on PlatformException catch (e) {
    if (e.code == 'sign_in_failed') {
      return const Left(AuthError.failure);
    }
    rethrow;
  }
  final googleAuth = await googleUser?.authentication;
  if (googleUser == null || googleAuth == null) {
    return const Left(AuthError.canceled);
  }
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  final info = SignInCredential(
    credential,
    googleUser.displayName,
    googleUser.email,
  );
  return Right(info);
}

Future<void> _maybeFixFirebaseNameAndEmail(
  UserCredential userCredential,
  String? name,
  String? email,
) async {
  if (userCredential.user?.displayName == null ||
      userCredential.user?.displayName?.isEmpty == true) {
    try {
      await userCredential.user?.updateDisplayName(name);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
  if (userCredential.user?.email == null ||
      userCredential.user?.email?.isEmpty == true) {
    try {
      await userCredential.user?.verifyBeforeUpdateEmail(email ?? '');
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}

Future<String?> _getIdToken(User user, {bool forceRefresh = false}) async {
  for (var retryAttempt = 0; retryAttempt < 3; retryAttempt++) {
    try {
      return user.getIdToken(forceRefresh);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return null;
      } else if (e.code == 'unknown') {
        // Retry
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      } else {
        rethrow;
      }
    }
  }
  return null;
}

class SignInCredential {
  final OAuthCredential credential;
  final String? name;
  final String? email;

  SignInCredential(this.credential, this.name, this.email);
}

sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess();
}

class AuthFailure extends AuthResult {
  final AuthError error;

  const AuthFailure(this.error);
}

enum AuthError { canceled, invalidCode, invalidId, quotaExceeded, failure }

enum SignInProvider {
  google('google.com', 'Google');

  const SignInProvider(this.id, this.name);

  final String id;
  final String name;

  AuthProvider get _firebaseProvider {
    switch (this) {
      case SignInProvider.google:
        return GoogleAuthProvider();
    }
  }
}
