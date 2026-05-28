import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../screens/auth_screen.dart';
import '../common/firestore_error.dart';
import '../common/auth_helpers.dart';
import '../services/email_service.dart';
import '../services/offer_promotion_service.dart';
import '../services/ui_state_service.dart';

class FoodDetailSheet extends StatefulWidget {
  final FoodOglas oglas;

  const FoodDetailSheet({super.key, required this.oglas});

  static Future<void> show(BuildContext context, FoodOglas oglas) async {
    UIStateService.instance.isDetailOpen.value = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(oglas: oglas),
    );
    UIStateService.instance.isDetailOpen.value = false;
  }

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  bool _loading = false;
  bool _isDavatelj = false;
  bool _userTypeLoaded = false;
  int _selectedPickupIndex = -1;
  int _selectedPortions = 1;

  FoodOglas get oglas => widget.oglas;

  static const _vzorecIds = {'1', '2', '3', '4', '5'};
  bool get _jeVzorecOglasa => _vzorecIds.contains(oglas.id);

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _initSelectedIndex();
  }

  void _initSelectedIndex() {
    final pickupTerms = <DateTime?>[oglas.termin1, oglas.termin2, oglas.termin3, oglas.termin4]
        .where((t) => t != null)
        .map((t) => t!)
        .toList();
    if (oglas.chosenTermin != null) {
      final idx = pickupTerms.indexWhere((t) => t.isAtSameMomentAs(oglas.chosenTermin!));
      if (idx != -1) _selectedPickupIndex = idx;
    }
  }

  void _showAuthPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    );
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _userTypeLoaded = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _isDavatelj = doc.data()?['userType'] == 'davatelj';
          _userTypeLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userTypeLoaded = true);
    }
  }

  // ── Rezerviraj ─────────────────────────────────────────────────────────────
  Future<void> _rezerviraj() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _showAuthPopup();
      return;
    }
    if (_jeVzorecOglasa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Počakajte, da se oglasi naložijo, nato poskusite znova.'),
        ),
      );
      return;
    }
    if (_userTypeLoaded && _isDavatelj) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organizacije lahko samo objavljajo oglase, ne rezervirajo.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    if (user?.uid == null) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Napaka: Niste prijavljeni. Osvežite stran.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Preverimo termin pred transakcijo (UI validacija)
    final localPickupTerms = <DateTime?>[oglas.termin1, oglas.termin2, oglas.termin3, oglas.termin4]
        .where((t) => t != null).toList();
    if (localPickupTerms.isEmpty) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Za ta oglas ni razpoložljivih terminov.')),
      );
      return;
    }
    if (_selectedPickupIndex < 0 || _selectedPickupIndex >= localPickupTerms.length) {
      setState(() => _loading = false);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izberite termin'),
          content: const Text('Pred rezervacijo izberite termin prevzema.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('V redu')),
          ],
        ),
      );
      return;
    }

    final userUid = user!.uid;
    int? finalNewRemaining;
    DateTime? finalSelectedTerm;
    String? finalPickupToken;

    try {
      // Transakcija: atomično beri in piši, da preprečimo race condition
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection('oglasi').doc(oglas.id);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception('Oglas ne obstaja več.');

        final data = snapshot.data()!;

        // Beri SVEŽO vrednost iz Firestorea (ne iz lokalnega oglas objekta)
        final currentRemaining = (data['remainingPortions'] as num?)?.toInt()
            ?? (data['portions'] as num?)?.toInt()
            ?? 1;

        // Preveri porcije s svežimi podatki
        if (_selectedPortions > currentRemaining) {
          throw Exception(
            'Na voljo je samo $currentRemaining '
            '${currentRemaining == 1 ? 'porcija' : 'porcije'}.',
          );
        }

        // Preveri, da je izbrani termin še vedno veljaven
        final freshTerms = <DateTime?>[
          (data['termin1'] as Timestamp?)?.toDate(),
          (data['termin2'] as Timestamp?)?.toDate(),
          (data['termin3'] as Timestamp?)?.toDate(),
          (data['termin4'] as Timestamp?)?.toDate(),
        ].where((t) => t != null).toList();

        if (_selectedPickupIndex < 0 || _selectedPickupIndex >= freshTerms.length) {
          throw Exception('Izbrani termin ni več na voljo.');
        }
        final selectedTerm = freshTerms[_selectedPickupIndex]!;

        final newRemaining = currentRemaining - _selectedPortions;
        // Always create a pickup token for the reservation so we can send a QR link
        // to the reserver even if there are still portions left.
        final pickupToken = _createToken();

        transaction.update(docRef, {
          'status': newRemaining == 0 ? 'rezervirano' : 'naRazpolago',
          'reservedByUid': userUid, // always save who reserved
          'remainingPortions': newRemaining,
          'reservedPortions': _selectedPortions,
          'chosenTermin': Timestamp.fromDate(selectedTerm),
          'reservedAt': FieldValue.serverTimestamp(),
          'offerPending': false,
          'offerExpiresAt': FieldValue.delete(),
          'pickupToken': pickupToken,
        });

        // Shrani vrednosti za uporabo po transakciji
        finalNewRemaining = newRemaining;
        finalSelectedTerm = selectedTerm;
        finalPickupToken = pickupToken;
      });

      // Po uspešni transakciji: pošlji e-mail z QR kodo (best-effort)
      if (finalSelectedTerm != null && finalPickupToken != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userUid).get();
          final email = userDoc.data()?['email'] as String?;
          final baseUrl = _baseUrl();
          final pickupUrl = '$baseUrl/?pickup=${oglas.id}&token=$finalPickupToken';

          if (email != null && email.isNotEmpty) {
            final termLabel = _formatPickupTerm(finalSelectedTerm!);
            _sendPickupEmail(email, pickupUrl, termLabel).catchError((e) {
              debugPrint('Pickup email failed: $e');
            });
          }
        } catch (_) {
          // Best-effort: rezervacija je že uspela.
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalPickupToken != null
                ? 'Oglas rezerviran! ✓ Poglej na mail, poslana QR koda.'
                : 'Oglas rezerviran! ✓'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isUserFacing = msg.contains('Na voljo je samo') ||
            msg.contains('ni več na voljo') ||
            msg.contains('ne obstaja več');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUserFacing ? msg : firestoreErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ── Prekliči rezervacijo ──────────────────────────────────────────────────
  Future<void> _preklici() async {
    setState(() => _loading = true);
    try {
      final ref = FirebaseFirestore.instance.collection('oglasi').doc(oglas.id);

      // Prevent cancellation within 24h of expiry or chosen term
      final now = DateTime.now();
      if (oglas.expiryDate != null && oglas.expiryDate!.difference(now) < const Duration(hours: 24)) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rezervacije ni mogoče preklicati manj kot 24 ur pred rokom.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      if (oglas.chosenTermin != null && oglas.chosenTermin!.difference(now) < const Duration(hours: 24)) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rezervacije ni mogoče preklicati manj kot 24 ur pred izbranim terminom.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (oglas.waitlist.isNotEmpty) {
        final naslednji = oglas.waitlist.first;
        final novaVrsta = oglas.waitlist.skip(1).toList();
        await OfferPromotionService.instance.promoteNextUser(
          docId: oglas.id,
          nextUid: naslednji,
          remainingWaitlist: novaVrsta,
          title: oglas.title,
          termin1: oglas.termin1 != null ? Timestamp.fromDate(oglas.termin1!) : null,
          termin2: oglas.termin2 != null ? Timestamp.fromDate(oglas.termin2!) : null,
          termin3: oglas.termin3 != null ? Timestamp.fromDate(oglas.termin3!) : null,
          termin4: oglas.termin4 != null ? Timestamp.fromDate(oglas.termin4!) : null,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervacija preklicana. Naslednji v vrsti ima 3 ure za prevzem.'),
              backgroundColor: kOrange,
            ),
          );
        }
      } else {
        // Obnovi remainingPortions z transakcijo, da preprečimo napačne vrednosti
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(ref);
          if (!snapshot.exists) throw Exception('Oglas ne obstaja več.');
          final data = snapshot.data()!;

          final totalPortions = (data['portions'] as num?)?.toInt() ?? 1;
          final currentRemaining = (data['remainingPortions'] as num?)?.toInt() ?? 0;
          final reservedPortions = (data['reservedPortions'] as num?)?.toInt() ?? _selectedPortions;  
          final restored = (currentRemaining + reservedPortions).clamp(0, totalPortions);             

          transaction.update(ref, {
            'status': 'naRazpolago',
            'reservedByUid': FieldValue.delete(),
            'chosenTermin': FieldValue.delete(),
            'remainingPortions': restored,
            'reservedPortions': FieldValue.delete(),   
            'offerPending': false,
            'offerExpiresAt': FieldValue.delete(),
            'offerToken': FieldValue.delete(),
            'offeredUid': FieldValue.delete(),
            'offerNotifiedAt': FieldValue.delete(),
            'pickupToken': FieldValue.delete(),
          });
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervacija preklicana.'),
              backgroundColor: kOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendPickupEmail(String email, String pickupUrl, String termLabel) async {
    await EmailService.sendPickupQrEmail(
      to: email,
      title: oglas.title,
      pickupUrl: pickupUrl,
      selectedTermLabel: termLabel,
    );
  }

  String _baseUrl() {
    final custom = dotenv.maybeGet('WEB_BASE_URL');
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim().replaceAll(RegExp(r'/$'), '');
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return base.origin;
    }
    return 'https://foodwastezero.web.app';
  }

  String _createToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Dodaj v čakalno vrsto ─────────────────────────────────────────────────
  Future<void> _dodajVVrsto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _showAuthPopup();
      return;
    }
    if (_userTypeLoaded && _isDavatelj) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organizacije ne morejo vstopati v čakalno vrsto.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    if (user?.uid == null) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Napaka: Niste prijavljeni. Osvežite stran.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final userUid = user!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'waitlist': FieldValue.arrayUnion([userUid]),
      });
      if (mounted) {
        final pos = oglas.waitlist.length + 1;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Postavljeni ste v čakalno vrsto ($pos. mesto).')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Zapusti čakalno vrsto ─────────────────────────────────────────────────
  Future<void> _zapustiVrsto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'waitlist': FieldValue.arrayRemove([user.uid]),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zapustili ste čakalno vrsto.'),
            backgroundColor: kOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Google Maps ───────────────────────────────────────────────────────────
  Future<void> _openGoogleMaps() async {
    final latLng = oglas.latLng;
    Uri uri;
    if (latLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${latLng.lat},${latLng.lng}'
        '&travelmode=driving',
      );
    } else if (oglas.location.isNotEmpty) {
      final encoded = Uri.encodeComponent(oglas.location);
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$encoded'
        '&travelmode=driving',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokacija ni na voljo.')),
        );
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final pickupTerms = <DateTime?>[
      oglas.termin1,
      oglas.termin2,
      oglas.termin3,
      oglas.termin4,
    ].where((term) => term != null).toList();

    final jeMojaRezervacija = (oglas.status == OglasStatus.rezervirano ||
        oglas.status == OglasStatus.naRazpolago) &&
    oglas.reservedByUid != null &&
    oglas.reservedByUid == user?.uid;

    final semVVrsti = user != null && oglas.waitlist.contains(user.uid);
    final mojaPozijaVVrsti = semVVrsti
        ? oglas.waitlist.indexOf(user!.uid) + 1
        : 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 20),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull),
              ),
            ),
          ),

          // Scrollable vsebina
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image header
                  Container(
                    width: double.infinity,
                    height: 200,
                    color: oglas.imageColor,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (oglas.imageBase64 != null)
                          _buildBase64Image(oglas.imageBase64!)
                        else
                          Center(
                            child: Icon(oglas.icon, size: 64,
                                color: kGreenMid.withOpacity(0.45)),
                          ),
                        if (oglas.isExpiringSoon)
                          Positioned(
                            top: 12, left: 16,
                            child: _Badge(label: '⏰ Kmalu poteče', color: kOrange),
                          ),
                        Positioned(
                          top: 12, right: 16,
                          child: _StatusBadge(status: oglas.status),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: kGreenPale, borderRadius: kRadiusFull),
                          child: Text(oglas.category,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: kGreenMid)),
                        ),
                        const SizedBox(height: 8),
                        Text(oglas.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 4),
                        if (oglas.username != null)
                          Text('Objavljeno od ${oglas.username}',
                              style: kCaption.copyWith(
                                  color: kGreenMid, fontWeight: FontWeight.w600)),

                        const SizedBox(height: 10),

                        // ── Cena ──────────────────────────────────────────
                        if (oglas.price != null && oglas.price! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C6BC0).withOpacity(0.08),
                              borderRadius: kRadius8,
                              border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.euro_rounded, size: 15, color: Color(0xFF5C6BC0)),
                              const SizedBox(width: 6),
                              Text(
                                'Cena: ${oglas.price!.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5C6BC0),
                                ),
                              ),
                            ]),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: kGreenPale,
                              borderRadius: kRadius8,
                              border: Border.all(color: kGreenMid.withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.volunteer_activism_rounded, size: 15, color: kGreenMid),
                              const SizedBox(width: 6),
                              const Text(
                                'Brezplačno',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kGreenMid,
                                ),
                              ),
                            ]),
                          ),

                        const SizedBox(height: 16),

                        if (oglas.description.isNotEmpty) ...[
                          Text(oglas.description, style: kBody.copyWith(height: 1.5)),
                          const SizedBox(height: 16),
                        ],

                        if (pickupTerms.isNotEmpty) ...[
                          const Text(
                            'Termini prevzema',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < pickupTerms.length; i++)
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedPickupIndex = i);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedPickupIndex == i
                                          ? kGreenMid.withOpacity(0.12)
                                          : kSurface,
                                      borderRadius: kRadius8,
                                      border: Border.all(
                                        color: _selectedPickupIndex == i
                                            ? kGreenMid.withOpacity(0.8)
                                            : kBorder,
                                      ),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.schedule_rounded, size: 13, color: kGreenMid),
                                      const SizedBox(width: 6),
                                      Text('Termin ${i + 1}: ${_formatPickupTerm(pickupTerms[i]!)}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _selectedPickupIndex == i ? kGreenMid : kTextDark)),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Izbor števila porcij ───────────────────────────
                        if (oglas.status == OglasStatus.naRazpolago &&
                            !(user != null && oglas.uid != null && oglas.uid == user.uid) &&
                            !(_userTypeLoaded && _isDavatelj) &&
                            !_jeVzorecOglasa &&
                            !jeMojaRezervacija) ...[
                          const Text(
                            'Število porcij',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark),
                          ),
                          const SizedBox(height: 8),
                          () {
                            final maxPortions = oglas.remainingPortions ?? oglas.portions ?? 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: kRadius12,
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.restaurant_rounded, size: 16, color: kGreenMid),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Na voljo: $maxPortions ${maxPortions == 1 ? 'porcija' : maxPortions < 5 ? 'porcije' : 'porcij'}',
                                      style: kCaption.copyWith(fontSize: 13, color: kTextMid),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _selectedPortions > 1
                                        ? () => setState(() => _selectedPortions--)
                                        : null,
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _selectedPortions > 1 ? kGreenPale : const Color(0xFFF0F0F0),
                                        borderRadius: kRadius8,
                                        border: Border.all(
                                          color: _selectedPortions > 1 ? kGreenMid.withOpacity(0.4) : kBorder,
                                        ),
                                      ),
                                      child: Icon(Icons.remove_rounded,
                                          size: 18,
                                          color: _selectedPortions > 1 ? kGreenMid : kTextLight),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      '$_selectedPortions',
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _selectedPortions < maxPortions
                                        ? () => setState(() => _selectedPortions++)
                                        : null,
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _selectedPortions < maxPortions ? kGreenPale : const Color(0xFFF0F0F0),
                                        borderRadius: kRadius8,
                                        border: Border.all(
                                          color: _selectedPortions < maxPortions ? kGreenMid.withOpacity(0.4) : kBorder,
                                        ),
                                      ),
                                      child: Icon(Icons.add_rounded,
                                          size: 18,
                                          color: _selectedPortions < maxPortions ? kGreenMid : kTextLight),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }(),
                          const SizedBox(height: 16),
                        ],

                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _InfoChip(Icons.location_on_outlined, oglas.location),
                            _InfoChip(Icons.access_time_outlined, oglas.time),
                            _InfoChip(Icons.near_me_outlined,
                                '${oglas.distanceKm.toStringAsFixed(1)} km stran'),
                            if (oglas.expiryDate != null)
                              _InfoChip(
                                Icons.event_outlined,
                                'Rok: ${_formatDate(oglas.expiryDate!)}',
                                color: oglas.isExpiringSoon ? kOrange : null,
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        if (_isDavatelj && !_userTypeLoaded)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(color: kGreenMid),
                          ),

                        if (isAppGuest(user))
                          _InfoBox(
                            icon: Icons.login_rounded,
                            color: kGreenMid,
                            text: 'Za rezervacijo ali čakalno vrsto se prijavite v račun.',
                          ),

                        if (_isDavatelj && _userTypeLoaded && oglas.uid != user?.uid)
                          _InfoBox(
                            icon: Icons.store_rounded,
                            color: kTextMid,
                            text: 'Kot organizacija lahko objavljate oglase. Rezervacije so namenjene uporabnikom.',
                          ),

                        if (jeMojaRezervacija) () {
                          final rezervirano = oglas.reservedPortions ?? 1;
                          final ostalo = oglas.remainingPortions ?? 0;
                          return _InfoBox(
                            icon: Icons.info_outline_rounded,
                            color: kOrange,
                            text: 'Rezervirali ste $rezervirano ${rezervirano == 1 ? 'porcijo' : rezervirano < 5 ? 'porcije' : 'porcij'}. '
                                'Še ostalo: $ostalo ${ostalo == 1 ? 'porcija' : ostalo < 5 ? 'porcije' : 'porcij'}.',
                          );
                        }(),

                        if (semVVrsti && !jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.queue_rounded,
                            color: const Color(0xFF5C6BC0),
                            text: 'Ste na $mojaPozijaVVrsti. mestu v čakalni vrsti. Obveščeni boste, ko bo oglas na voljo.',
                          ),

                        if (oglas.status == OglasStatus.naRazpolago &&
                            (oglas.remainingPortions ?? (oglas.portions ?? 1)) <= 0 &&
                            oglas.waitlist.isNotEmpty)
                          _InfoBox(
                            icon: Icons.people_outline_rounded,
                            color: kTextMid,
                            text: '${oglas.waitlist.length} ${oglas.waitlist.length == 1 ? 'oseba čaka' : 'osebe čakajo'} v vrsti.',
                          ),

                        if (oglas.status == OglasStatus.rezervirano &&
                            oglas.waitlist.isNotEmpty)
                          _InfoBox(
                            icon: Icons.people_outline_rounded,
                            color: kTextMid,
                            text: '${oglas.waitlist.length} ${oglas.waitlist.length == 1 ? 'oseba čaka' : 'osebe čakajo'} v vrsti.',
                          ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gumbi — pritrjeni na dno
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorder, width: 1)),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
            child: SafeArea(
              top: false,
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(color: kGreenMid, strokeWidth: 2.5),
                      ),
                    )
                  : _buildActionButtons(jeMojaRezervacija, semVVrsti),
            ),
          ),
        ],
      ),
    );
  }

  // ── Označi kot prevzeto (samo davatelj/lastnik oglasa) ────────────────────
  Future<void> _oznaci(FoodOglas o) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(o.id)
          .update({'status': 'prevzeto'});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oglas označen kot prevzeto ✓'),
            backgroundColor: kGreenMid,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildActionButtons(bool jeMojaRezervacija, bool semVVrsti) {
  final hasLocation = oglas.latLng != null || oglas.location.isNotEmpty;
  final user = FirebaseAuth.instance.currentUser;
  final jeVlasnik = user != null && oglas.uid != null && oglas.uid == user.uid;

  final navBtn = Expanded(
    flex: 2,
    child: ElevatedButton.icon(
      onPressed: hasLocation
          ? () {
              Navigator.pop(context);
              _openGoogleMaps();
            }
          : null,
      icon: const Icon(Icons.directions_rounded, size: 18, color: Colors.white),
      label: const Text('Pelji me tja',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreenMid,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );

  if (oglas.status == OglasStatus.naRazpolago) {
    if (jeVlasnik || (_userTypeLoaded && _isDavatelj) || _jeVzorecOglasa) {
      return Row(children: [navBtn]);
    }

    // ── NOVO: če je ta uporabnik že delno rezerviral, pokaži Prekliči ──
    if (jeMojaRezervacija) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _preklici,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Prekliči rezervacijo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOrange,
              side: const BorderSide(color: kOrange, width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        navBtn,
      ]);
    }

    // Če so vse porcije zasedene (remainingPortions == 0), pokaži čakalno vrsto
    final remaining = oglas.remainingPortions ?? oglas.portions ?? 1;
    if (remaining <= 0) {
      if (semVVrsti) {
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _zapustiVrsto,
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              label: const Text('Zapusti vrsto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5C6BC0),
                side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          navBtn,
        ]);
      }
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _dodajVVrsto,
            icon: const Icon(Icons.queue_rounded, size: 16),
            label: const Text('Čakalna vrsta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5C6BC0),
              side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        navBtn,
      ]);
    }

    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _rezerviraj,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: const Text('Rezerviraj'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kGreenMid,
            side: const BorderSide(color: kGreenMid, width: 1.5),
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
      const SizedBox(width: 10),
      navBtn,
    ]);
  }

  if (oglas.status == OglasStatus.rezervirano) {
    // Vlasnik oglasa vidi "Označi kot prevzeto"
    if (jeVlasnik) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _oznaci(oglas),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Označi kot prevzeto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kGreenMid,
              side: const BorderSide(color: kGreenMid, width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        navBtn,
      ]);
    }

    if (jeMojaRezervacija) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _preklici,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Prekliči rezervacijo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOrange,
              side: const BorderSide(color: kOrange, width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        navBtn,
      ]);
    }

    if (semVVrsti) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _zapustiVrsto,
            icon: const Icon(Icons.exit_to_app_rounded, size: 16),
            label: const Text('Zapusti vrsto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5C6BC0),
              side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        navBtn,
      ]);
    }

    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _dodajVVrsto,
          icon: const Icon(Icons.queue_rounded, size: 16),
          label: const Text('Čakalna vrsta'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF5C6BC0),
            side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
      const SizedBox(width: 10),
      navBtn,
    ]);
  }

  // Prevzeto
  return Row(children: [
    Expanded(
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextLight,
          side: const BorderSide(color: kBorder),
          shape: const RoundedRectangleBorder(borderRadius: kRadius12),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: const Text('Prevzeto'),
      ),
    ),
    const SizedBox(width: 10),
    navBtn,
  ]);
}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) => '${dt.day}. ${dt.month}. ${dt.year}';

String _formatPickupTerm(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day.$month.${dt.year} $hour:$minute';
}

Widget _buildBase64Image(String base64) {
  try {
    final bytes = base64Decode(base64);
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  } catch (_) {
    return const SizedBox.shrink();
  }
}

class _StatusBadge extends StatelessWidget {
  final OglasStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: kRadiusFull,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(statusLabel(status),
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: kRadiusFull),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: kRadius8,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color != null ? color!.withOpacity(0.08) : kSurface,
          borderRadius: kRadius8,
          border: Border.all(
              color: color != null ? color!.withOpacity(0.25) : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? kTextMid),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: color ?? kTextMid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}