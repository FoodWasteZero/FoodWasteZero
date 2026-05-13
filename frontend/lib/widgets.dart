import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

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
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: kRadius16,
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            // ── Left image block
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(
                width: 110,
                height: 140,
                color: oglas.imageColor,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(oglas.icon, size: 42,
                          color: kGreenMid.withOpacity(0.55)),
                    ),
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
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: kGreenMid,
                            borderRadius: kRadius8,
                            boxShadow: [
                              BoxShadow(
                                color: kGreenMid.withOpacity(0.35),
                                blurRadius: 8, offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 14),
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
        color: color.withOpacity(0.15),
        borderRadius: kRadiusFull,
        border: Border.all(color: color.withOpacity(0.4)),
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

// ── Section header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: kHeading3),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: kGreenMid)),
            ),
        ],
      ),
    );
  }
}

// ── Quick filter chips ────────────────────────────────────────────────────────
class FilterChipsRow extends StatefulWidget {
  final Function(String)? onFilterChanged;
  const FilterChipsRow({super.key, this.onFilterChanged});

  @override
  State<FilterChipsRow> createState() => _FilterChipsRowState();
}

class _FilterChipsRowState extends State<FilterChipsRow> {
  String _active = 'Vse';
  final _filters = ['Vse', 'V bližini', 'Brezplačno', 'Kmalu poteče'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = _filters[i] == _active;
          return GestureDetector(
            onTap: () {
              setState(() => _active = _filters[i]);
              widget.onFilterChanged?.call(_filters[i]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kGreenMid : Colors.white,
                borderRadius: kRadiusFull,
                border: Border.all(color: active ? kGreenMid : kBorder),
                boxShadow: active ? kElevatedShadow : [],
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : kTextMid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: kRadius16,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: kRadius8,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: kCaption),
        ],
      ),
    );
  }
}
