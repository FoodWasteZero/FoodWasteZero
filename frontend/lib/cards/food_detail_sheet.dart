import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../screens/auth_screen.dart';
import '../common/firestore_error.dart';
import '../common/auth_helpers.dart';
import '../common/publisher_navigation.dart';
import '../services/email_service.dart';
import '../services/reservation_service.dart';
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
  bool _rezervacijaLoaded = false;
  int _selectedPickupIndex = -1;
  int _selectedPortions = 1;

  // Aktivna rezervacija tega uporabnika za ta oglas (null = ni rezervacije)
  Rezervacija? _mojaRezervacija;

  FoodOglas get oglas => widget.oglas;

  static const _vzorecIds = {'1', '2', '3', '4', '5'};
  bool get _jeVzorecOglasa => _vzorecIds.contains(oglas.id);

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _loadMojaRezervacija();
  }

  Future<void> _loadMojaRezervacija() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _rezervacijaLoaded = true);
      return;
    }
    try {
      final rez = await ReservationService.instance.getUserReservation(
        oglasId: oglas.id,
        userId: user.uid,
      );
      if (mounted) {
        setState(() {
          _mojaRezervacija = rez;
          _rezervacijaLoaded = true;
          // Nastavi izbrani termin če ga ima rezervacija
          if (rez?.chosenTermin != null) {
            final terms = _getPickupTerms();
            final idx = terms.indexWhere(
              (t) => t.isAtSameMomentAs(rez!.chosenTermin!),
            );
            if (idx != -1) _selectedPickupIndex = idx;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rezervacijaLoaded = true);
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

  List<DateTime> _getPickupTerms() {
    return <DateTime?>[
      oglas.termin1,
    ].whereType<DateTime>().toList();
  }

  // ── Rezerviraj ─────────────────────────────────────────────────────────────
  Future<void> _rezerviraj() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) { _showAuthPopup(); return; }
    if (_jeVzorecOglasa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Počakajte, da se oglasi naložijo, nato poskusite znova.')),
      );
      return;
    }
    if (_userTypeLoaded && _isDavatelj) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organizacije lahko samo objavljajo oglase, ne rezervirajo.')),
      );
      return;
    }
    if (user?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Napaka: Niste prijavljeni.'), backgroundColor: Colors.red),
      );
      return;
    }

    final pickupTerms = _getPickupTerms();
    if (pickupTerms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Za ta oglas ni razpoložljivih terminov.')),
      );
      return;
    }
    if (_selectedPickupIndex < 0 || _selectedPickupIndex >= pickupTerms.length) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Izberite termin'),
          content: Text('Pred rezervacijo izberite termin prevzema.'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('V redu'))],
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final selectedTerm = pickupTerms[_selectedPickupIndex];
      final rezervacijaId = await ReservationService.instance.ustvariRezervacijo(
        oglasId: oglas.id,
        userId: user!.uid,
        kolicinaPorcij: _selectedPortions,
        chosenTermin: selectedTerm,
        totalPortions: oglas.portions ?? 1,
      );

      // Pošlji QR email asinhrono
      _sendPickupEmail(user.uid, rezervacijaId, selectedTerm).catchError(
        (e) => debugPrint('Pickup email failed: $e'),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oglas rezerviran! ✓ Poglej na mail, poslana QR koda.'),
            duration: Duration(seconds: 4),
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

  Future<void> _sendPickupEmail(String userId, String rezervacijaId, DateTime term) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final email = userDoc.data()?['email'] as String?;
      if (email == null || email.isEmpty) return;

      // Pridobi pickupToken iz právkar ustvarjene rezervacije
      final rezDoc = await FirebaseFirestore.instance
          .collection('rezervacije').doc(rezervacijaId).get();
        final reservedPortions = (rezDoc.data()?['kolicinaPorcij'] as num?)?.toInt() ?? 1;
      final pickupToken = rezDoc.data()?['pickupToken'] as String?;
      if (pickupToken == null) return;

      final baseUrl = ReservationService.instance.baseUrl();
      final pickupUrl = '$baseUrl/?pickup=${oglas.id}&rez=$rezervacijaId&token=$pickupToken';
      final termLabel = _formatPickupTerm(term);

      await EmailService.sendPickupQrEmail(
        to: email,
        title: oglas.title,
        reservedPortions: reservedPortions,
        pickupUrl: pickupUrl,
        selectedTermLabel: termLabel,
      );
    } catch (e) {
      debugPrint('sendPickupEmail error: $e');
    }
  }

  // ── Prekliči rezervacijo ──────────────────────────────────────────────────
  Future<void> _preklici() async {
    final rez = _mojaRezervacija;
    if (rez == null) return;

    // Preveri 24h omejitev
    final now = DateTime.now();
    final lockCheck = rez.chosenTermin ?? oglas.expiryDate;
    if (lockCheck != null && lockCheck.difference(now) < const Duration(hours: 24)) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: kRadius16),
          icon: Icon(Icons.lock_clock_rounded, color: Colors.red, size: 32),
          title: Text('Preklic ni možen', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text('Rezervacije ni mogoče preklicati manj kot 24 ur pred rokom.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: kGreenMid, foregroundColor: Colors.white),
              child: Text('Razumem'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ReservationService.instance.prekliciRezervacijo(
        rezervacijaId: rez.id,
        oglasId: oglas.id,
        kolicinaPorcij: rez.kolicinaPorcij,
        oglas: oglas,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervacija preklicana.'),
            backgroundColor: kOrange,
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

  // ── Dodaj v čakalno vrsto ─────────────────────────────────────────────────
  Future<void> _dodajVVrsto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) { _showAuthPopup(); return; }
    if (_userTypeLoaded && _isDavatelj) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organizacije ne morejo vstopati v čakalno vrsto.')),
      );
      return;
    }
    if (user?.uid == null) return;

    setState(() => _loading = true);
    try {
      await ReservationService.instance.dodajVWaitlist(
        oglasId: oglas.id,
        userId: user!.uid,
      );
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
      await ReservationService.instance.zapustiWaitlist(
        oglasId: oglas.id,
        userId: user.uid,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zapustili ste čakalno vrsto.'), backgroundColor: kOrange),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Maps ───────────────────────────────────────────────────────────
  Future<void> _openGoogleMaps() async {
    final latLng = oglas.latLng;
    Uri uri;
    if (latLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${latLng.lat},${latLng.lng}&travelmode=driving',
      );
    } else if (oglas.location.isNotEmpty) {
      final encoded = Uri.encodeComponent(oglas.location);
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$encoded&travelmode=driving',
      );
    } else {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lokacija ni na voljo.')));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final pickupTerms = _getPickupTerms();

    final jeMojaRezervacija = _mojaRezervacija != null && _mojaRezervacija!.jeAktivna;
    final semVVrsti = user != null && oglas.waitlist.contains(user.uid);
    final mojaPozijaVVrsti = semVVrsti ? oglas.waitlist.indexOf(user!.uid) + 1 : 0;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
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
                decoration: BoxDecoration(color: c.border, borderRadius: kRadiusFull),
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
                          Center(child: Icon(oglas.icon, size: 64, color: kGreenMid.withOpacity(0.45))),
                        if (oglas.isExpiringSoon)
                          Positioned(top: 12, left: 16,
                              child: _Badge(label: '⏰ Kmalu poteče', color: kOrange)),
                        Positioned(top: 12, right: 16,
                            child: _StatusBadge(status: oglas.status)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategorija
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kGreenMid.withOpacity(0.1),
                            borderRadius: kRadiusFull,
                            border: Border.all(color: kGreenMid.withOpacity(0.3), width: 0.8),
                          ),
                          child: Text(oglas.category,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: kGreenMid, letterSpacing: 0.3)),
                        ),
                        SizedBox(height: 12),

                        // Naslov
                        Text(oglas.title,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900,
                                color: c.textDark, height: 1.2)),
                        SizedBox(height: 12),

                        // Avtor in cena
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: kGreenMid.withOpacity(0.05),
                            borderRadius: kRadius12,
                            border: Border.all(color: kGreenMid.withOpacity(0.15), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: kGreenMid.withOpacity(0.12), borderRadius: kRadius8),
                                child: Icon(Icons.store_rounded, size: 14, color: kGreenMid),
                              ),
                              SizedBox(width: 10),
                              if (oglas.username != null) ...[
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.pop(context);
                                    openPublisherProfile(context, oglas);
                                  },
                                  child: Text(oglas.username!,
                                      style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w700,
                                          color: kGreenMid)),
                                ),
                                SizedBox(width: 16),
                                Container(width: 1, height: 14, color: c.border.withOpacity(0.3)),
                                SizedBox(width: 16),
                              ],
                              const Spacer(),
                              // Cena
                              if (oglas.price != null && oglas.price! > 0)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF5C6BC0).withOpacity(0.12),
                                        borderRadius: kRadius8),
                                    child: Icon(Icons.euro_rounded,
                                        size: 12, color: Color(0xFF5C6BC0)),
                                  ),
                                  SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${(oglas.price! * _selectedPortions).toStringAsFixed(2)} €',
                                        style: TextStyle(fontSize: 14,
                                            fontWeight: FontWeight.w800, color: Color(0xFF5C6BC0)),
                                      ),
                                      if (_selectedPortions > 1)
                                        Text(
                                          '${oglas.price!.toStringAsFixed(2)} € / porcija',
                                          style: TextStyle(fontSize: 11,
                                              color: Color(0xFF5C6BC0), fontWeight: FontWeight.w500),
                                        ),
                                    ],
                                  ),
                                ])
                              else
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                        color: kGreenMid.withOpacity(0.12), borderRadius: kRadius8),
                                    child: Icon(Icons.volunteer_activism_rounded,
                                        size: 12, color: kGreenMid),
                                  ),
                                  SizedBox(width: 6),
                                  Text('Brezplačno',
                                      style: TextStyle(fontSize: 14,
                                          fontWeight: FontWeight.w800, color: kGreenMid)),
                                ]),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Opis
                        if (oglas.description.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: c.border.withOpacity(0.5)),
                          ),
                          Text('Opis',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textDark)),
                          SizedBox(height: 10),
                          Text(oglas.description,
                              style: kBody.copyWith(height: 1.6, color: c.textMid, fontSize: 14)),
                          SizedBox(height: 20),
                        ],

                        // Termini prevzema
                        if (pickupTerms.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: c.border.withOpacity(0.5)),
                          ),
                          Text('Termini prevzema',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textDark)),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              for (var i = 0; i < pickupTerms.length; i++)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedPickupIndex = i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedPickupIndex == i
                                          ? kGreenMid.withOpacity(0.12) : kSurface,
                                      borderRadius: kRadius12,
                                      border: Border.all(
                                        color: _selectedPickupIndex == i
                                            ? kGreenMid.withOpacity(0.6) : kBorder,
                                        width: _selectedPickupIndex == i ? 1.2 : 0.8,
                                      ),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                            color: kGreenMid.withOpacity(0.12), borderRadius: kRadius6),
                                        child: Icon(Icons.schedule_rounded,
                                            size: 13, color: kGreenMid),
                                      ),
                                      SizedBox(width: 8),
                                      Text(_formatPickupTerm(pickupTerms[i]),
                                          style: TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w700,
                                              color: _selectedPickupIndex == i ? kGreenMid : kTextDark)),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 20),
                        ],

                        // Izbor števila porcij — prikaži samo če ni moje rezervacije
                        if (oglas.status == OglasStatus.naRazpolago &&
                            !jeMojaRezervacija &&
                            !(user != null && oglas.uid != null && oglas.uid == user.uid) &&
                            !(_userTypeLoaded && _isDavatelj) &&
                            !_jeVzorecOglasa) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: c.border.withOpacity(0.5)),
                          ),
                          Text('Število porcij',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textDark)),
                          SizedBox(height: 10),
                          Builder(builder: (_) {
                            final maxPortions = oglas.remainingPortions ?? oglas.portions ?? 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: c.surface, borderRadius: kRadius12,
                                  border: Border.all(color: c.border)),
                              child: Row(
                                children: [
                                  Icon(Icons.restaurant_rounded, size: 16, color: kGreenMid),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Na voljo: $maxPortions '
                                      '${maxPortions == 1 ? 'porcija' : maxPortions < 5 ? 'porcije' : 'porcij'}',
                                      style: kCaption.copyWith(fontSize: 13, color: c.textMid),
                                    ),
                                  ),
                                  _PortionButton(
                                    icon: Icons.remove_rounded,
                                    enabled: _selectedPortions > 1,
                                    onTap: () => setState(() => _selectedPortions--),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('$_selectedPortions',
                                        style: TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.w800, color: c.textDark)),
                                  ),
                                  _PortionButton(
                                    icon: Icons.add_rounded,
                                    enabled: _selectedPortions < maxPortions,
                                    onTap: () => setState(() => _selectedPortions++),
                                  ),
                                ],
                              ),
                            );
                          }),
                          SizedBox(height: 16),
                        ],

                        // Lokacija in rok
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: c.border.withOpacity(0.5)),
                        ),
                        Text('Lokacija in rok uporabe',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textDark)),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _InfoChip(Icons.location_on_outlined, oglas.location),
                            _InfoChip(Icons.access_time_outlined, oglas.time),
                            _InfoChip(Icons.near_me_outlined,
                                '${oglas.distanceKm.toStringAsFixed(1)} km stran'),
                            if (oglas.expiryDate != null)
                              _InfoChip(Icons.event_outlined,
                                  'Rok: ${_formatDate(oglas.expiryDate!)}',
                                  color: oglas.isExpiringSoon ? kOrange : kYellow),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Info boxe
                        if (!_userTypeLoaded)
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(color: kGreenMid),
                          ),
                        if (isAppGuest(user))
                          _InfoBox(
                            icon: Icons.login_rounded, color: kGreenMid,
                            text: 'Za rezervacijo ali čakalno vrsto se prijavite v račun.',
                          ),
                        if (_isDavatelj && _userTypeLoaded && oglas.uid != user?.uid)
                          _InfoBox(
                            icon: Icons.store_rounded, color: c.textMid,
                            text: 'Kot organizacija lahko objavljate oglase. Rezervacije so namenjene uporabnikom.',
                          ),
                        if (jeMojaRezervacija) () {
                          final rez = _mojaRezervacija!;
                          final ostalo = oglas.remainingPortions ?? 0;
                          return _InfoBox(
                            icon: Icons.check_circle_outline_rounded, color: kGreenMid,
                            text: 'Rezervirali ste ${rez.kolicinaPorcij} '
                                '${rez.kolicinaPorcij == 1 ? 'porcijo' : rez.kolicinaPorcij < 5 ? 'porcije' : 'porcij'}. '
                                'Preostalih na voljo: $ostalo.',
                          );
                        }(),
                        if (semVVrsti && !jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.queue_rounded, color: const Color(0xFF5C6BC0),
                            text: 'Ste na $mojaPozijaVVrsti. mestu v čakalni vrsti. Obveščeni boste, ko bo oglas na voljo.',
                          ),
                        if (!jeMojaRezervacija && !semVVrsti &&
                            oglas.waitlist.isNotEmpty)
                          _InfoBox(
                            icon: Icons.people_outline_rounded, color: c.textMid,
                            text: '${oglas.waitlist.length} '
                                '${oglas.waitlist.length == 1 ? 'oseba čaka' : 'osebe čakajo'} v vrsti.',
                          ),
                        SizedBox(height: 16),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(oglas.time,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500, color: c.textLight)),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gumbi — pritrjeni na dno
          Container(
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.border, width: 0.8)),
            ),
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomInset),
            child: SafeArea(
              top: false,
              child: _loading || !_rezervacijaLoaded
                  ? Center(
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

  Widget _buildActionButtons(bool jeMojaRezervacija, bool semVVrsti) {
    final c = AppColors.of(context);
    final hasLocation = oglas.latLng != null || oglas.location.isNotEmpty;
    final user = FirebaseAuth.instance.currentUser;
    final jeVlasnik = user != null && oglas.uid != null && oglas.uid == user.uid;

    final navBtn = Expanded(
      flex: 2,
      child: ElevatedButton.icon(
        onPressed: hasLocation ? () { Navigator.pop(context); _openGoogleMaps(); } : null,
        icon: Icon(Icons.directions_rounded, size: 18, color: c.card),
        label: Text('Pelji me tja',
            style: TextStyle(color: c.card, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreenMid, elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: kRadius12),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );

    final prekliciBtn = Expanded(
      child: OutlinedButton.icon(
        onPressed: _preklici,
        icon: Icon(Icons.cancel_outlined, size: 16),
        label: Text('Prekliči rezervacijo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kOrange,
          side: BorderSide(color: kOrange, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: kRadius12),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );

    // Lastnik oglasa in davatelji vidijo samo navigacijo
    if (jeVlasnik || (_userTypeLoaded && _isDavatelj)) {
      return Row(children: [navBtn]);
    }

    if (oglas.status == OglasStatus.prevzeto) {
      return Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextLight, side: BorderSide(color: c.border),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: Text('Prevzeto'),
          ),
        ),
        SizedBox(width: 10),
        navBtn,
      ]);
    }

    // Moja aktivna rezervacija
    if (jeMojaRezervacija) {
      return Row(children: [prekliciBtn, SizedBox(width: 10), navBtn]);
    }

    // V čakalni vrsti
    if (semVVrsti) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _zapustiVrsto,
            icon: Icon(Icons.exit_to_app_rounded, size: 16),
            label: Text('Zapusti vrsto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5C6BC0),
              side: BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        SizedBox(width: 10),
        navBtn,
      ]);
    }

    final remaining = oglas.remainingPortions ?? oglas.portions ?? 1;

    // Ni porcij — čakalna vrsta
    if (remaining <= 0) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _dodajVVrsto,
            icon: Icon(Icons.queue_rounded, size: 16),
            label: Text('Čakalna vrsta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5C6BC0),
              side: BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        SizedBox(width: 10),
        navBtn,
      ]);
    }

    // Rezerviraj
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _rezerviraj,
          icon: Icon(Icons.check_circle_outline_rounded, size: 16),
          label: Text('Rezerviraj'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kGreenMid,
            side: BorderSide(color: kGreenMid, width: 1.5),
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
      SizedBox(width: 10),
      navBtn,
    ]);
  }
}

// ── Pomožni widget ────────────────────────────────────────────────────────────
class _PortionButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PortionButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: enabled ? kGreenPale : const Color(0xFFF0F0F0),
            borderRadius: kRadius8,
            border: Border.all(color: enabled ? kGreenMid.withOpacity(0.4) : kBorder),
          ),
          child: Icon(icon, size: 18, color: enabled ? kGreenMid : kTextLight),
        ),
      );
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
    final c = AppColors.of(context);
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: kRadiusFull,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(statusLabel(status),
          style: TextStyle(color: color.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: kRadiusFull),
        child: Text(label,
            style: TextStyle(color: c.card, fontSize: 13, fontWeight: FontWeight.w700)),
      );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: kRadius12,
          border: Border.all(color: color.withOpacity(0.4), width: 0.8),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: kRadius8),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500, height: 1.4)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color != null ? color!.withOpacity(0.12) : kSurface,
          borderRadius: kRadius12,
          border: Border.all(color: color != null ? color!.withOpacity(0.35) : kBorder, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: (color ?? kTextMid).withOpacity(0.18), borderRadius: kRadius6),
            child: Icon(icon, size: 12, color: color ?? kTextMid),
          ),
          SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 13, color: color ?? kTextMid, fontWeight: FontWeight.w600)),
        ]),
      );
}