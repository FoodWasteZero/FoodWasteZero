import 'dart:convert';
import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../screens/map_page.dart';

// ── Detail bottom sheet koji se otvara na tap karte ──────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final color = statusColor(oglas.status);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

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
                        // Base64 slika iz Firestora (brez Firebase Storage!)
                        if (oglas.imageBase64 != null)
                          _buildBase64Image(oglas.imageBase64!)
                        else
                          Center(
                            child: Icon(oglas.icon, size: 64, color: kGreenMid.withOpacity(0.45)),
                          ),
                        if (oglas.isExpiringSoon)
                          Positioned(
                            top: 12, left: 16,
                            child: _Badge(label: '⏰ Kmalu poteče', color: kOrange),
                          ),
                        Positioned(
                          top: 12, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: kRadiusFull,
                              border: Border.all(color: color.withOpacity(0.4)),
                            ),
                            child: Text(statusLabel(oglas.status),
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                          child: Text(oglas.category,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGreenMid)),
                        ),
                        const SizedBox(height: 8),
                        Text(oglas.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 4),
                        if (oglas.username != null)
                          Text('Objavljeno od ${oglas.username}',
                            style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600)),

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
                            if (oglas.isFree)
                              _InfoChip(Icons.volunteer_activism_rounded, 'Brezplačno',
                                color: kGreenMid),
                          ],
                        ),

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
                      side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
                      shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    ),
                    child: const Icon(Icons.bookmark_outline_rounded, size: 20),
                  ),
                  const SizedBox(width: 10),
                  // Rezerviraj
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: oglas.status == OglasStatus.naRazpolago
                        ? () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Oglas rezerviran!')));
                          }
                        : null,
                      label: const Text('Rezerviraj'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreenMid,
                        side: const BorderSide(color: kGreenMid, width: 1.5),
                        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Pokaži na zemljevidu
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: oglas.latLng != null
                        ? () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MapPage(oglas: oglas),
                            ));
                          }
                        : null,
                      icon: const Icon(Icons.directions_rounded, size: 18, color: Colors.white),
                      label: const Text('Pelji me tja',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
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

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: kRadiusFull),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}


// ── Base64 image helper ───────────────────────────────────────────────────────
Widget _buildBase64Image(String base64) {
  try {
    final bytes = base64Decode(base64);
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  } catch (_) {
    return const SizedBox.shrink();
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label; final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color != null ? color!.withOpacity(0.08) : kSurface,
      borderRadius: kRadius8,
      border: Border.all(color: color != null ? color!.withOpacity(0.25) : kBorder),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? kTextMid),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: color ?? kTextMid, fontWeight: FontWeight.w500)),
    ]),
  );
}