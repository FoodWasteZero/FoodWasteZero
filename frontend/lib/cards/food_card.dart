import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

// ── Modern food listing card ──────────────────────────────────────────────────
class FoodCard extends StatelessWidget {
  final FoodOglas oglas;
  final VoidCallback? onTap;

  const FoodCard({super.key, required this.oglas, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, left: 1, right: 1),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: kRadius16,
          border: Border.all(color: Color(0x0F000000), width: 0.8),
          boxShadow: const [
            // Ambient shadow — soft, wide
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              spreadRadius: -2,
              offset: Offset(0, 6),
            ),
            // Key shadow — crisp, close
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              spreadRadius: 0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Left image block
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background colour fill
                    Container(color: oglas.imageColor),
                    // Perfectly centred icon
                    Align(
                      alignment: Alignment.center,
                      child: Icon(
                        oglas.icon,
                        size: 44,
                        color: kGreenMid.withOpacity(0.50),
                      ),
                    ),
                    // Badges
                    if (oglas.isExpiringSoon)
                      Positioned(
                        top: 8, left: 8,
                        child: _PillBadge(
                          label: '⏰ Kmalu poteče',
                          color: kOrange,
                        ),
                      ),
                    if (oglas.isFree)
                      Positioned(
                        bottom: 8, left: 8,
                        child: _PillBadge(label: 'BREZPLAČNO', color: kGreenLight),
                      ),
                  ],
                ),
              ),
            ),
            // ── Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kGreenPale,
                        borderRadius: kRadiusFull,
                      ),
                      child: Text(oglas.category,
                          style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w600, color: kGreenMid)),
                    ),
                    const SizedBox(height: 6),
                    Text(oglas.title,
                        style: kBodyBold.copyWith(fontSize: 13),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    _InfoRow(Icons.location_on_outlined, oglas.location),
                    const SizedBox(height: 3),
                    _InfoRow(Icons.access_time_outlined, oglas.time),
                    const SizedBox(height: 3),
                    _InfoRow(Icons.near_me_outlined,
                        '${oglas.distanceKm.toStringAsFixed(1)} km stran'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatusChip(status: oglas.status),
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: kGreenMid,
                            borderRadius: kRadius8,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x552E7D32),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: kTextLight),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: kCaption.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OglasStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: kRadiusFull,
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color, borderRadius: kRadiusFull,
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white,
              fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }
}