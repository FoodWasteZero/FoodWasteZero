import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

/// Recipe Card - displays a single ingredient listing with visual distinction
class RecipeCard extends StatelessWidget {
  final FoodOglas oglas;

  const RecipeCard({super.key, required this.oglas});

  @override
  Widget build(BuildContext context) {
    final borderColor = oglas.status == OglasStatus.prevzeto
        ? kGreenAccent
        : kOrange;
    
    final bgColor = oglas.status == OglasStatus.prevzeto
        ? kGreenPale
        : kOrangePale;
    
    final iconColor = oglas.status == OglasStatus.prevzeto
        ? kGreenAccent
        : kOrange;
    
    final statusLabel = oglas.status == OglasStatus.prevzeto
        ? '✓ Claimed'
        : '◇ Reserved';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon, title, and status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: kRadius12,
                      ),
                      child: Icon(
                        oglas.icon,
                        color: iconColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            oglas.title,
                            style: kHeading3.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            oglas.location,
                            style: kBody.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: kRadius8,
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (oglas.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    oglas.description,
                    style: kBody.copyWith(height: 1.4, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Footer with time and expiry info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  oglas.time,
                  style: TextStyle(
                    fontSize: 13,
                    color: iconColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                if (oglas.isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kOrangePale,
                      borderRadius: kRadius8,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: kOrange),
                        SizedBox(width: 4),
                        Text(
                          'Expiring soon',
                          style: TextStyle(
                            fontSize: 13,
                            color: kOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
