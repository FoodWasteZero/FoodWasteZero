import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/auth_screen.dart';
import '../screens/publisher_profile_screen.dart';
import '../services/ui_state_service.dart';
import 'auth_helpers.dart';

/// Klik na ime objavitelja: lastnik → Moje objave, ostali → javni profil.
void openPublisherProfile(BuildContext context, FoodOglas oglas) {
  final targetUid = oglas.uid;
  if (targetUid == null || targetUid.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (isAppGuest(user)) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    return;
  }

  if (user != null && user.uid == targetUid) {
    UIStateService.instance.requestMineTab();
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublisherProfileScreen(targetUid: targetUid),
    ),
  );
}
