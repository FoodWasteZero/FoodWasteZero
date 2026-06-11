import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Gost = ni prijavljen z e-pošto (lahko je anonimno prijavljen za dostop do Firestore).
bool isAppGuest(User? user) => user == null || user.isAnonymous;

/// Anonimna prijava omogoči branje/pisanje, če so Rules še vedno auth-only.
Future<void> ensureFirestoreAccess() async {
  // Ne kliči med aktivnim login procesom!
  if (_loginInProgress) return;
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

/// Zastavica: true med aktivnim email login/register procesom.
/// Preprečuje da _AuthGate med tem kliče ensureFirestoreAccess().
bool _loginInProgress = false;
bool get isLoginInProgress => _loginInProgress;

/// Pred prijavo z e-pošto odjavi anonimnega uporabnika.
Future<void> signOutAnonymousIfNeeded() async {
  _loginInProgress = true;
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    await FirebaseAuth.instance.signOut();
    // Na webu signOut() je async in treba malo časa
    // da authStateChanges konča preden začnemo signIn
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

/// Kliči po uspešnem ali neuspešnem login/register procesu.
void loginDone() {
  _loginInProgress = false;
}