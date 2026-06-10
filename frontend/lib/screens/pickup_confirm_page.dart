import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../common/auth_helpers.dart';
import '../common/theme.dart';
import 'auth_screen.dart';
import '../services/email_service.dart';
import '../services/reservation_service.dart';

/// Stran za potrditev prevzema (QR koda).
///
/// URL parametri: pickup=<oglasId>&rez=<rezervacijaId>&token=<pickupToken>
/// Bere iz kolekcije 'rezervacije' (ne več iz 'oglasi').
/// Samo lastnik oglasa (davatelj) potrdi prevzem.
class PickupConfirmPage extends StatefulWidget {
  final String adId;          // oglasId
  final String rezervacijaId; // id dokumenta v 'rezervacije'
  final String token;         // pickupToken

  const PickupConfirmPage({
    super.key,
    required this.adId,
    required this.rezervacijaId,
    required this.token,
  });

  @override
  State<PickupConfirmPage> createState() => _PickupConfirmPageState();
}

class _PickupConfirmPageState extends State<PickupConfirmPage> {
  bool _loading = true;
  bool _saving = false;
  bool _errorVisible = false;
  bool _authPromptShown = false;
  String? _error;
  Map<String, dynamic>? _rezData;
  Map<String, dynamic>? _oglasData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePromptAuth();
  }

  void _maybePromptAuth() {
    if (_authPromptShown || !mounted || _loading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _authPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAuth();
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Naloži rezervacijo
      final rezDoc = await FirebaseFirestore.instance
          .collection('rezervacije')
          .doc(widget.rezervacijaId)
          .get();
      if (!rezDoc.exists) {
        setState(() {
          _error = 'Rezervacija ne obstaja več.';
          _loading = false;
          _errorVisible = true;
        });
        return;
      }

      // Naloži oglas (za lastnika in naslov)
      final oglasDoc = await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(widget.adId)
          .get();
      if (!oglasDoc.exists) {
        setState(() {
          _error = 'Oglas ne obstaja več.';
          _loading = false;
          _errorVisible = true;
        });
        return;
      }

      setState(() {
        _rezData = rezDoc.data() as Map<String, dynamic>;
        _oglasData = oglasDoc.data() as Map<String, dynamic>;
        _loading = false;
      });

      _maybePromptAuth();
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
    ).then((_) => _loadData());
  }

  Future<void> _confirmPickup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _showAuth();
      return;
    }

    final rezData = _rezData;
    final oglasData = _oglasData;
    if (rezData == null || oglasData == null) return;

    // Preveri pickupToken
    final token = rezData['pickupToken'] as String?;
    if (token != widget.token) {
      setState(() {
        _error = 'QR koda ni več veljavna.';
        _errorVisible = true;
      });
      return;
    }

    // Samo lastnik oglasa (davatelj) potrdi prevzem
    final ownerUid = oglasData['uid'] as String?;
    if (ownerUid == null || user == null || user.uid != ownerUid) {
      setState(() {
        _error = 'Prijavi se mora ista uporabnik, ki je ustvaril oglas.';
        _errorVisible = true;
      });
      return;
    }

    // Preveri da rezervacija ni že prevzeta
    if ((rezData['status'] as String?) == 'prevzeto') {
      setState(() {
        _error = 'Ta prevzem je že bil potrjen.';
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
      final confirmationCode = await ReservationService.instance.potrdiPrevzem(
        rezervacijaId: widget.rezervacijaId,
        oglasId: widget.adId,
        pickupToken: widget.token,
        ownerUid: ownerUid,
        currentUserUid: user.uid,
      );

      // Pošlji email prevzemniku (best-effort)
      try {
        final reservedUid = rezData['userId'] as String?;
        if (reservedUid != null && reservedUid.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(reservedUid)
              .get();
          final email = userDoc.data()?['email'] as String?;
          if (email != null && email.isNotEmpty) {
            await EmailService.sendPickupConfirmedEmail(
              to: email,
              title: (oglasData['title'] as String?) ?? 'Prevzem',
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
        // Osveži podatke
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _errorVisible = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final title = (_oglasData?['title'] as String?) ?? 'Prevzem';
    final currentStatus =
        (_rezData?['status'] as String?) ?? 'rezervirano';
    final kolicina =
        (_rezData?['kolicinaPorcij'] as num?)?.toInt() ?? 1;
    final ownerUid = _oglasData?['uid'] as String?;
    final isOwner = user != null && !user.isAnonymous && ownerUid != null && user.uid == ownerUid;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Potrditev prevzema')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kGreenMid))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kHeading2),
                    const SizedBox(height: 8),
                    Text(
                      'Količina: $kolicina '
                      '${kolicina == 1 ? 'porcija' : kolicina < 5 ? 'porcije' : 'porcij'}',
                      style: kBody.copyWith(
                          fontWeight: FontWeight.w700, color: kTextDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Po skenu QR kode se prijavi avtor oglasa, ki potrdi prevzem.',
                      style: kBody.copyWith(color: kTextMid),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Trenutni status: ${currentStatus.toUpperCase()}'),
                    const Spacer(),
                    if (!isAppGuest(user) && !isOwner) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: kRadius12,
                          border: Border.all(color: Colors.orange.withOpacity(0.25)),
                        ),
                        child: const Text(
                          'Prijavljena oseba ni avtor tega oglasa. Prijavi se z računom, ki je ustvaril oglas.',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (_errorVisible && _error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    if (currentStatus == 'prevzeto')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kGreenMid.withOpacity(0.1),
                          borderRadius: kRadius12,
                          border: Border.all(
                              color: kGreenMid.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: kGreenMid),
                            SizedBox(width: 10),
                            Text('Prevzem je bil potrjen.',
                                style: TextStyle(
                                    color: kGreenMid,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )
                    else if (isAppGuest(FirebaseAuth.instance.currentUser))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _showAuth,
                            child: const Text('Prijavi se'),
                          ),
                      )
                    else if (!isOwner)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showAuth,
                          child: const Text('Prijavi se'),
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text('Potrdi prevzem'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Po potrditvi se rezervacija označi kot prevzeta.',
                      style: TextStyle(
                          fontSize: 12, color: kTextLight),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}