import 'dart:convert';
import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

class FoodCard extends StatelessWidget {
  final FoodOglas oglas;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  const FoodCard({
    super.key,
    required this.oglas,
    this.onTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPrice = oglas.price != null && oglas.price! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 148,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: kRadius12,
          border: Border.all(color: c.border.withOpacity(0.45), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.0 : 0.055),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 148,
                height: 148,
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: oglas.imageColor),
                  if (oglas.imageBase64 != null)
                    _Base64Image(base64: oglas.imageBase64!)
                  else
                    Center(
                      child: Icon(oglas.icon, size: 48,
                          color: kGreenMid.withOpacity(0.45)),
                    ),
                  // Dark gradient overlay at bottom for badge readability
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.62),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price badge bottom-left
                  Positioned(
                    bottom: 7, left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasPrice ? const Color(0xFF5C6BC0) : kGreenMid,
                        borderRadius: kRadius6,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.45),
                              blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        hasPrice ? '€${oglas.price!.toStringAsFixed(2)}' : 'BREZPLAČNO',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                      ),
                    ),
                  ),
                  // Expiring badge top-left
                  if (oglas.isExpiringSoon)
                    Positioned(
                      top: 7, left: 7,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: kOrange,
                          borderRadius: kRadius6,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4),
                                blurRadius: 5, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 15),
                      ),
                    ),
                ]),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: category pill + verified + time
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: kGreenPale, borderRadius: kRadius6),
                        child: Text(oglas.category,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: kGreenMid)),
                      ),
                      if (oglas.isDavatelj) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF029624), size: 15),
                      ],
                      const Spacer(),
                      Text(oglas.time,
                          style: const TextStyle(
                              fontSize: 11.5, color: kTextLight)),
                    ]),

                    // Title — 2 lines allowed
                    Text(oglas.title,
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700,
                            color: c.textDark, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),

                    // Location + distance badge inline
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: kTextLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(oglas.location,
                            style: const TextStyle(
                                fontSize: 12.5, color: kTextLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: kGreenPale, borderRadius: kRadius6),
                        child: Text(
                          '${oglas.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 11, color: kGreenMid,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),

                    // Bottom: author + status dot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (oglas.username != null)
                          Flexible(
                            child: GestureDetector(
                              onTap: onAuthorTap,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.store_rounded,
                                      size: 12, color: kGreenMid),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(oglas.username!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: kGreenMid,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        _StatusDot(status: oglas.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Chevron ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded,
                  color: c.textLight, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final OglasStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(statusLabel(status),
          style: TextStyle(fontSize: 11.5, color: color,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Base64Image extends StatelessWidget {
  final String base64;
  const _Base64Image({required this.base64});

  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(base64Decode(base64),
          fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: kRadius6),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}