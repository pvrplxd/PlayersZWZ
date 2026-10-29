import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Completer<void>? _profileSetup;

  Stream<User?> get userChanges =>
      _auth.authStateChanges().asyncMap((user) async {
        // Account creation emits a user before updateDisplayName finishes.
        await _profileSetup?.future;
        return user == null ? null : _auth.currentUser;
      });
  User? get currentUser => _auth.currentUser;

  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final setup = Completer<void>();
    _profileSetup = setup;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
    } finally {
      setup.complete();
      if (identical(_profileSetup, setup)) _profileSetup = null;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in did not return an ID token. Please try again.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    // Firebase sign-out must remain available if Google cleanup fails.
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase has already ended the application session.
    }
  }
}

String readableAuthError(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  return switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' =>
      'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password (at least 6 characters).',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'missing-google-id-token' =>
      error.message ?? 'Google sign-in could not be completed.',
    _ => error.message ?? 'Authentication failed. Please try again.',
  };
}
