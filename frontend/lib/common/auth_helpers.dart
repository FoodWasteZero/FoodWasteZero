import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Gost = ni prijavljen z e-pošto (lahko je anonimno prijavljen za dostop do Firestore).
bool isAppGuest(User? user) => user == null || user.isAnonymous;

/// Anonimna prijava omogoči branje/pisanje, če so Rules še vedno auth-only.
Future<void> ensureFirestoreAccess() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    await FirebaseAuth.instance.signInAnonymously();
    if (kDebugMode) {
      debugPrint('Firebase: anonimna prijava za dostop do Firestore');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase: anonimna prijava ni uspela: $e');
    }
  }
}

/// Pred prijavo z e-pošto odjavi anonimnega uporabnika.
Future<void> signOutAnonymousIfNeeded() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    await FirebaseAuth.instance.signOut();
  }
}
