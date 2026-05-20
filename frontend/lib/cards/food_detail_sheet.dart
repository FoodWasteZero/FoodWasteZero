import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/theme.dart';
import '../models/models.dart';

class FoodDetailSheet extends StatelessWidget {
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

  // ── Rezerviraj (samo ako je naRazpolago) ─────────────────────────────────
  Future<void> _rezerviraj(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za rezervacijo.')),
      );
      return;
    }
    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'status': 'rezervirano',
        'reservedByUid': user.uid,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas rezerviran! ✓')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Napaka. Poskusite znova.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Prekliči svojo rezervacijo ────────────────────────────────────────────
  Future<void> _preklici(BuildContext context) async {
    Navigator.pop(context);
    try {
      final ref = FirebaseFirestore.instance.collection('oglasi').doc(oglas.id);

      // Če je čakalna vrsta — prvi v vrsti avtomatsko dobi rezervacijo
      if (oglas.waitlist.isNotEmpty) {
        final naslednji = oglas.waitlist.first;
        final novaVrsta = oglas.waitlist.skip(1).toList();
        await ref.update({
          'status': 'rezervirano',
          'reservedByUid': naslednji,
          'waitlist': novaVrsta,
        });
        if (context.mounted) {
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervacija preklicana.'),
              backgroundColor: kOrange,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Napaka. Poskusite znova.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Postavi se v čakalno vrsto ────────────────────────────────────────────
  Future<void> _dodajVVrsto(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za čakalno vrsto.')),
      );
      return;
    }
    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'waitlist': FieldValue.arrayUnion([user.uid]),
      });
      if (context.mounted) {
        final pos = oglas.waitlist.length + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Postavljeni ste v čakalno vrsto (${pos}. mesto).')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Napaka. Poskusite znova.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Zapusti čakalno vrsto ─────────────────────────────────────────────────
  Future<void> _zapustiVrsto(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(oglas.id)
          .update({
        'waitlist': FieldValue.arrayRemove([user.uid]),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zapustili ste čakalno vrsto.'),
            backgroundColor: kOrange,
          ),
        );
      }
    } catch (_) {}
  }

  // ── Google Maps ───────────────────────────────────────────────────────────
  Future<void> _openGoogleMaps(BuildContext context) async {
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
      if (context.mounted) {
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

    // Statusi gumbov:
    // naRazpolago → "Rezerviraj"
    // rezervirano + sem jaz rezerviral → "Prekliči rezervacijo"
    // rezervirano + sem v vrsti → "Zapusti čakalno vrsto"
    // rezervirano + nisem v vrsti → "Postavi se v čakalno vrsto"
    // prevzeto → gumb onemogočen

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
                        // Kategorija
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: kGreenPale, borderRadius: kRadiusFull),
                          child: Text(oglas.category,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: kGreenMid)),
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

                        // Info chips
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

                        // Moja rezervacija info
                        if (jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.info_outline_rounded,
                            color: kOrange,
                            text: 'Ta oglas ste rezervirali vi. Kliknite "Prekliči" za odstranitev rezervacije.',
                          ),

                        // V čakalni vrsti info
                        if (semVVrsti && !jeMojaRezervacija)
                          _InfoBox(
                            icon: Icons.queue_rounded,
                            color: const Color(0xFF5C6BC0),
                            text: 'Ste na $mojaPozijaVVrsti. mestu v čakalni vrsti. Obveščeni boste, ko bo oglas na voljo.',
                          ),

                        // Čakalna vrsta (koliko čaka)
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
              child: _buildActionButtons(context, jeMojaRezervacija, semVVrsti),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool jeMojaRezervacija,
    bool semVVrsti,
  ) {
    final hasLocation = oglas.latLng != null || oglas.location.isNotEmpty;

    // Navigacija gumb — vedno desno
    final navBtn = Expanded(
      flex: 2,
      child: ElevatedButton.icon(
        onPressed: hasLocation
            ? () {
                Navigator.pop(context);
                _openGoogleMaps(context);
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
      // Rezerviraj
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _rezerviraj(context),
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
      if (jeMojaRezervacija) {
        // Prekliči svojo rezervacijo
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _preklici(context),
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
        // Zapusti čakalno vrsto
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _zapustiVrsto(context),
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

      // Postavi se v čakalno vrsto
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _dodajVVrsto(context),
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

    // Prevzeto — samo navigacija, rezervacija onemogočena
    return Row(children: [
      const Expanded(
        child: OutlinedButton(
          onPressed: null,
          child: Text('Prevzeto'),
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
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
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
                    fontSize: 12, color: color, fontWeight: FontWeight.w500)),
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
                  fontSize: 12,
                  color: color ?? kTextMid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}