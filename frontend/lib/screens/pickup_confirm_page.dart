import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../common/auth_helpers.dart';
import '../common/theme.dart';
import 'auth_screen.dart';
import '../services/email_service.dart';

class PickupConfirmPage extends StatefulWidget {
  final String adId;
  final String token;

  const PickupConfirmPage({
    super.key,
    required this.adId,
    required this.token,
  });

  @override
  State<PickupConfirmPage> createState() => _PickupConfirmPageState();
}

class _PickupConfirmPageState extends State<PickupConfirmPage> {
  bool _loading = true;
  bool _saving = false;
  bool _errorVisible = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('oglasi').doc(widget.adId).get();
      if (!doc.exists) {
        setState(() {
          _error = 'Oglas ne obstaja več.';
          _loading = false;
          _errorVisible = true;
        });
        return;
      }
      setState(() {
        _data = doc.data() as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Napaka pri nalaganju: $e';
        _loading = false;
        _errorVisible = true;
      });
    }
  }

  void _showAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    ).then((_) => _loadAd());
  }

  Future<void> _confirmPickup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _showAuth();
      return;
    }

    final data = _data;
    if (data == null) return;

    final token = data['pickupToken'] as String?;
    if (token != widget.token) {
      setState(() {
        _error = 'QR koda ni več veljavna.';
        _errorVisible = true;
      });
      return;
    }

    final ownerUid = data['uid'] as String?;
    if (ownerUid == null || user == null || user.uid != ownerUid) {
      setState(() {
        _error = 'Ta potrditvena stran je namenjena organizaciji, ki je objavo ustvarila.';
        _errorVisible = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _errorVisible = false;
    });

    try {
      // Generate a short confirmation code to send to the reserver
      final confirmationCode = (100000 + Random().nextInt(900000)).toString();

      await FirebaseFirestore.instance.collection('oglasi').doc(widget.adId).update({
        'status': 'prevzeto',
        'pickupConfirmedAt': FieldValue.serverTimestamp(),
        'pickupToken': FieldValue.delete(),
        'pickupConfirmationCode': confirmationCode,
      });

      // Notify the reserver by email (best-effort)
      try {
        final reservedUid = _data?['reservedByUid'] as String?;
        if (reservedUid != null && reservedUid.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(reservedUid).get();
          final email = userDoc.data()?['email'] as String?;
          if (email != null && email.isNotEmpty) {
            await EmailService.sendPickupConfirmedEmail(
              to: email,
              title: (_data?['title'] as String?) ?? 'Prevzem',
              confirmationCode: confirmationCode,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to send pickup confirmed email: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prevzem potrjen ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Napaka: $e';
          _errorVisible = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_data?['title'] as String?) ?? 'Prevzem';
    final currentStatus = (_data?['status'] as String?) ?? 'naRazpolago';

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Potrditev prevzema')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenMid))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kHeading2),
                    const SizedBox(height: 8),
                    Text(
                      'Sken QR kode odpre to stran. Organizacija potrdi prevzem s spodnjim gumbom.',
                      style: kBody.copyWith(color: kTextMid),
                    ),
                    const SizedBox(height: 16),
                    Text('Trenutni status: ${currentStatus.toUpperCase()}'),
                    const Spacer(),
                    if (_errorVisible && _error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    if (FirebaseAuth.instance.currentUser == null || FirebaseAuth.instance.currentUser!.isAnonymous)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showAuth,
                          child: const Text('Prijavi se kot organizacija'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _confirmPickup,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Potrdi prevzem'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Po potrditvi se oglas označi kot prevzet.',
                      style: TextStyle(fontSize: 12, color: kTextLight),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
