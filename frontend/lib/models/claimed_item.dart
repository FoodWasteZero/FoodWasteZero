import 'package:flutter/material.dart';

// ── Claimed ingredient model ──────────────────────────────────────────────────
class ClaimedItem {
  final String id;
  final String name;
  final String quantity;
  final String type;       // 'Kuhano' | 'Sestavine'
  final IconData icon;
  final Color color;
  bool isSelected;

  ClaimedItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.type,
    required this.icon,
    required this.color,
    this.isSelected = false,
  });
}

final List<ClaimedItem> kSampleClaimedItems = [
  ClaimedItem(
    id: 'c1', name: 'Jabolka', quantity: '5 kg',
    type: 'Sestavine', icon: Icons.apple,
    color: const Color(0xFFE8F5E9),
  ),
  ClaimedItem(
    id: 'c2', name: 'Paradižnik', quantity: '2 kg',
    type: 'Sestavine', icon: Icons.grass,
    color: const Color(0xFFFFEBEE),
  ),
  ClaimedItem(
    id: 'c3', name: 'Moka', quantity: '1 kg',
    type: 'Sestavine', icon: Icons.bakery_dining,
    color: const Color(0xFFF5F5F5),
  ),
  ClaimedItem(
    id: 'c4', name: 'Golaž', quantity: '1 posoda',
    type: 'Kuhano', icon: Icons.soup_kitchen,
    color: const Color(0xFFFFE0B2),
  ),
  ClaimedItem(
    id: 'c5', name: 'Rižota', quantity: '2 obroki',
    type: 'Kuhano', icon: Icons.rice_bowl,
    color: const Color(0xFFF9FBE7),
  ),
];