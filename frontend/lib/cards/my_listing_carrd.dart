import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

// ── My Listing Card ───────────────────────────────────────────────────────────
class MyListingCard extends StatelessWidget {
  final FoodOglas oglas;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const MyListingCard({
    super.key,
    required this.oglas,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: oglas.imageColor,
                    borderRadius: kRadius12,
                  ),
                  child: Center(
                    child: Icon(oglas.icon, size: 32, color: kTextMid),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              oglas.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: kTextLight),
                          const SizedBox(width: 2),
                          Text(
                            oglas.location,
                            style: const TextStyle(
                                fontSize: 14, color: kTextLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildPriceBadge(),
                          const SizedBox(width: 6),
                          _buildTimeBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Stats bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildMiniStat(
                    Icons.visibility_outlined, '24', 'ogledov'),
                _buildDivider(),
                _buildMiniStat(
                    Icons.favorite_border_rounded, '3', 'všeček'),
                _buildDivider(),
                _buildMiniStat(
                    Icons.chat_bubble_outline_rounded, '1', 'sporočil'),
                const Spacer(),
                // Action buttons
                _buildActionBtn(
                  Icons.edit_outlined,
                  kGreenMid,
                  kGreenPale,
                  onEdit,
                ),
                const SizedBox(width: 6),
                _buildActionBtn(
                  Icons.delete_outline_rounded,
                  kOrange,
                  kOrangePale,
                  () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isExp = oglas.isExpiringSoon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isExp ? kOrangePale : kGreenPale,
        borderRadius: kRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isExp ? kOrange : kGreenMid,
              borderRadius: kRadiusFull,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isExp ? 'Potekajoč' : 'Aktiven',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isExp ? kOrange : kGreenMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: oglas.isFree ? kGreenPale : Colors.grey.shade100,
        borderRadius: kRadius8,
      ),
      child: Text(
        oglas.isFree ? 'BREZPLAČNO' : 'PLAČLJIVO',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: oglas.isFree ? kGreenMid : kTextMid,
        ),
      ),
    );
  }

  Widget _buildTimeBadge() {
    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 11,
          color: oglas.isExpiringSoon ? kOrange : kTextLight,
        ),
        const SizedBox(width: 2),
        Text(
          oglas.time,
          style: TextStyle(
            fontSize: 13,
            color: oglas.isExpiringSoon ? kOrange : kTextLight,
            fontWeight: oglas.isExpiringSoon
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String count, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: kTextLight),
        const SizedBox(width: 3),
        Text(
          count,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextMid),
        ),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(fontSize: 14, color: kTextLight)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: kBorder,
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    Color color,
    Color bg,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: kRadius8,
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: kRadiusFull,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kOrangePale,
                borderRadius: kRadiusFull,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: kOrange, size: 28),
            ),
            const SizedBox(height: 14),
            const Text('Izbriši oglas?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextDark)),
            const SizedBox(height: 6),
            const Text(
              'Ta oglas bo trajno izbrisan in ga ne boste mogli obnoviti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextLight),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: kRadius12),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Prekliči',
                        style: TextStyle(
                            color: kTextMid,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: kRadius12),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Izbriši',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}