import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/theme.dart';
import '../models/models.dart';

class FoodDetailSheet extends StatefulWidget {
  final FoodOglas oglas;

  const FoodDetailSheet({super.key, required this.oglas});

  static void show(BuildContext context, FoodOglas oglas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(oglas: oglas),
    );
  }

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  bool _loading = false;
  bool _isSaved = false;
  bool _savingToggle = false;

  FoodOglas get oglas => widget.oglas;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final saved = List<String>.from(doc.data()?['savedOglasi'] ?? []);
      setState(() => _isSaved = saved.contains(oglas.id));
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za shranjevanje.')),
      );
      return;
    }
    setState(() => _savingToggle = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (_isSaved) {
        await ref.update({'savedOglasi': FieldValue.arrayRemove([oglas.id])});
      } else {
        await ref.update({'savedOglasi': FieldValue.arrayUnion([oglas.id])});
      }
      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
          _savingToggle = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSaved ? 'Oglas shranjen ✓' : 'Oglas odstranjen iz shranjenih'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingToggle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Rezerviraj ─────────────────────────────────────────────────────────────
  Future<void> _rezerviraj() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za rezervacijo.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'status': 'rezervirano',
        'reservedByUid': user.uid,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas rezerviran! ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Napaka: $e'),
            backgroundColor: Colors.red,
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

      if (oglas.waitlist.isNotEmpty) {
        final naslednji = oglas.waitlist.first;
        final novaVrsta = oglas.waitlist.skip(1).toList();
        await ref.update({
          'status': 'rezervirano',
          'reservedByUid': naslednji,
          'waitlist': novaVrsta,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervacija preklicana. Naslednji v vrsti je obveščen.'),
              backgroundColor: kOrange,
            ),
          );
        }
      } else {
        await ref.update({
          'status': 'naRazpolago',
          'reservedByUid': FieldValue.delete(),
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

  // ── Dodaj v čakalno vrsto ─────────────────────────────────────────────────
  Future<void> _dodajVVrsto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za čakalno vrsto.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'waitlist': FieldValue.arrayUnion([user.uid]),
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

    final jeMojaRezervacija = oglas.status == OglasStatus.rezervirano &&
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
                        Positioned(
                          bottom: 12, right: 16,
                          child: GestureDetector(
                            onTap: _savingToggle ? null : _toggleSave,
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: kRadiusFull,
                                boxShadow: kCardShadow,
                              ),
                              child: _savingToggle
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: kGreenMid),
                                    )
                                  : Icon(
                                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                      color: _isSaved ? kGreenMid : kTextMid,
                                      size: 22,
                                    ),
                            ),
                          ),
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

                        const SizedBox(height: 16),

                        if (oglas.description.isNotEmpty) ...[
                          Text(oglas.description, style: kBody.copyWith(height: 1.5)),
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

                        if (jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.info_outline_rounded,
                            color: kOrange,
                            text: 'Ta oglas ste rezervirali vi. Kliknite "Prekliči" za odstranitev rezervacije.',
                          ),

                        if (semVVrsti && !jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.queue_rounded,
                            color: const Color(0xFF5C6BC0),
                            text: 'Ste na $mojaPozijaVVrsti. mestu v čakalni vrsti. Obveščeni boste, ko bo oglas na voljo.',
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
      // Vlasnik ne može rezervirati vlastiti oglas
      if (jeVlasnik) {
        return Row(children: [navBtn]);
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
            label: const Text('V čakalno vrsto'),
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