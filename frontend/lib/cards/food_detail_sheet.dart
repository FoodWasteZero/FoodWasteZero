import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/theme.dart';
import '../models/models.dart';

// ── Detail bottom sheet ───────────────────────────────────────────────────────
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

  // ── Rezerviraj ali prekliči rezervacijo ───────────────────────────────────
  Future<void> _toggleRezervacija(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijavite se za rezervacijo.')),
      );
      return;
    }

    final jeMojaRezervacija =
        oglas.status == OglasStatus.rezervirano &&
        oglas.reservedByUid == currentUser.uid;

    Navigator.pop(context);

    try {
      if (jeMojaRezervacija) {
        // Prekliči rezervacijo
        await FirebaseFirestore.instance
            .collection('oglasi')
            .doc(oglas.id)
            .update({
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
      } else {
        // Rezerviraj
        await FirebaseFirestore.instance
            .collection('oglasi')
            .doc(oglas.id)
            .update({
          'status': 'rezervirano',
          'reservedByUid': currentUser.uid,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Oglas rezerviran! ✓'),
              backgroundColor: kGreenMid,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Napaka. Poskusite znova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Google Maps navigacija ────────────────────────────────────────────────
  Future<void> _openGoogleMapsNavigation(BuildContext context) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokacija ni na voljo.')),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ne morem odpreti Google Maps.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final color = statusColor(oglas.status);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // Rezerviran od tega uporabnika?
    final jeMojaRezervacija =
        oglas.status == OglasStatus.rezervirano &&
        oglas.reservedByUid != null &&
        oglas.reservedByUid == currentUser?.uid;

    // Gumb aktiven: na razpolago (vsak) ali moja rezervacija (preklic)
    final rezervirajAktiven =
        oglas.status == OglasStatus.naRazpolago || jeMojaRezervacija;

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
          // ── Handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 20),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull),
              ),
            ),
          ),

          // ── Scrollable vsebina
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image / icon header
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: kRadiusFull,
                              border: Border.all(color: color.withOpacity(0.4)),
                            ),
                            child: Text(statusLabel(oglas.status),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: kGreenPale, borderRadius: kRadiusFull),
                          child: Text(oglas.category,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kGreenMid)),
                        ),
                        const SizedBox(height: 8),
                        Text(oglas.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kTextDark)),
                        const SizedBox(height: 4),
                        if (oglas.username != null)
                          Text('Objavljeno od ${oglas.username}',
                              style: kCaption.copyWith(
                                  color: kGreenMid,
                                  fontWeight: FontWeight.w600)),

                        const SizedBox(height: 16),

                        if (oglas.description.isNotEmpty) ...[
                          Text(oglas.description,
                              style: kBody.copyWith(height: 1.5)),
                          const SizedBox(height: 16),
                        ],

                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _InfoChip(Icons.location_on_outlined, oglas.location),
                            _InfoChip(Icons.access_time_outlined, oglas.time),
                            _InfoChip(Icons.near_me_outlined,
                                '${oglas.distanceKm.toStringAsFixed(1)} km stran'),
                            if (oglas.isFree)
                              _InfoChip(
                                  Icons.volunteer_activism_rounded, 'Brezplačno',
                                  color: kGreenMid),
                            // Pokaži rok uporabe če obstaja
                            if (oglas.expiryDate != null)
                              _InfoChip(
                                Icons.event_outlined,
                                'Rok: ${_formatDate(oglas.expiryDate!)}',
                                color: oglas.isExpiringSoon ? kOrange : null,
                              ),
                          ],
                        ),

                        // Obvestilo če je to moja rezervacija
                        if (jeMojaRezervacija) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.08),
                              borderRadius: kRadius8,
                              border: Border.all(
                                  color: kOrange.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 15, color: kOrange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ta oglas ste rezervirali vi. Kliknite "Prekliči" za odstranitev rezervacije.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: kOrange,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Gumbi — pritrjeni na dno
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorder, width: 1)),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Shrani
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Oglas shranjen! ✓')));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5C6BC0),
                      side: const BorderSide(
                          color: Color(0xFF5C6BC0), width: 1.5),
                      shape: const RoundedRectangleBorder(
                          borderRadius: kRadius12),
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 14),
                    ),
                    child: const Icon(Icons.bookmark_outline_rounded, size: 20),
                  ),
                  const SizedBox(width: 10),

                  // Rezerviraj / Prekliči rezervacijo
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: rezervirajAktiven
                          ? () => _toggleRezervacija(context)
                          : null,
                      icon: Icon(
                        jeMojaRezervacija
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(jeMojaRezervacija ? 'Prekliči' : 'Rezerviraj'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            jeMojaRezervacija ? kOrange : kGreenMid,
                        side: BorderSide(
                          color: jeMojaRezervacija ? kOrange : kGreenMid,
                          width: 1.5,
                        ),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Pelji me tja → Google Maps
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          (oglas.latLng != null || oglas.location.isNotEmpty)
                              ? () {
                                  Navigator.pop(context);
                                  _openGoogleMapsNavigation(context);
                                }
                              : null,
                      icon: const Icon(Icons.directions_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Pelji me tja',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) => '${dt.day}. ${dt.month}. ${dt.year}';

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
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
}

Widget _buildBase64Image(String base64) {
  try {
    final bytes = base64Decode(base64);
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  } catch (_) {
    return const SizedBox.shrink();
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color != null ? color!.withOpacity(0.08) : kSurface,
          borderRadius: kRadius8,
          border: Border.all(
              color: color != null
                  ? color!.withOpacity(0.25)
                  : kBorder),
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