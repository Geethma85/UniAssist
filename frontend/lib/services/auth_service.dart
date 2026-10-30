import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
/// Handles all Firebase Authentication + user profile logic.
/// UI screens should never call FirebaseAuth or Firestore directly —
/// they call methods on this class instead.
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Returns the currently signed-in user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Registers a new user:
  /// 1. Creates the Firebase Auth account (email + password)
  /// 2. Creates a matching Firestore profile doc under users/{uid}
  ///
  /// Throws a [FirebaseAuthException] on failure — the caller (UI)
  /// is responsible for catching it and showing a friendly message.
  Future<User?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-creation-failed',
        message: 'Could not create user.',
      );
    }

    // Create the Firestore profile doc.
    // If this fails, the Auth account still exists — see note below.
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': 'student', // default role, admin accounts set manually in Firestore
      'createdAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  /// Signs in an existing user and fetches their role from Firestore.
  /// Returns a map with the User object and their role string.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed.',
      );
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      // Edge case: Auth account exists but no Firestore profile.
      // Shouldn't normally happen, but fail loudly rather than silently.
      throw FirebaseAuthException(
        code: 'profile-missing',
        message: 'User profile not found.',
      );
    }

    final role = doc.data()?['role'] ?? 'student';

    return {
      'user': user,
      'role': role,
    };
  }

    /// Returns the signed-in user's role ('student' or 'admin') from Firestore.
  /// Falls back to 'student' if anything is missing or fails, so a problem
  /// can only ever HIDE the admin button, never show it by mistake.
  Future<String> getCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'student';
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return (doc.data()?['role'] as String?) ?? 'student';
    } catch (_) {
      return 'student';
    }
  }
  
  Future<String> getCurrentName() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return ((doc.data()?['name'] as String?) ?? '').trim();
    } catch (_) {
      return '';
    }
  }

    Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw FirebaseAuthException(
        code: 'unsupported-platform',
        message: 'Google sign-in is currently available on the website.',
      );
    }

    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Google sign-in did not return a user.',
      );
    }

    final profile = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(profile);

      // Existing profiles and admin roles remain unchanged.
      if (!snapshot.exists) {
        transaction.set(profile, {
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
  
  /// Signs the current user out.
  Future<void> logout() async {
    await _auth.signOut();
  }
}