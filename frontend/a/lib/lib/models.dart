import 'package:flutter/material.dart';

// ── Food listing status ───────────────────────────────────────────────────────
enum OglasStatus { naRazpolago, rezervirano, prevzeto }

// ── Food listing model ────────────────────────────────────────────────────────
class FoodOglas {
  final String id;
  final String title;
  final String location;
  final String time;
  final OglasStatus status;
  final String? username;
  final Color imageColor;
  final String category;   // 'Kuhano' | 'Sestavine' | 'Peka' | 'Sadje & zelenjava'
  final bool isFree;
  final bool isExpiringSoon;
  final double distanceKm;
  final IconData icon;

  const FoodOglas({
    required this.id,
    required this.title,
    required this.location,
    required this.time,
    required this.status,
    this.username,
    required this.imageColor,
    required this.category,
    this.isFree = true,
    this.isExpiringSoon = false,
    this.distanceKm = 1.2,
    required this.icon,
  });
}

// ── Sample listings ───────────────────────────────────────────────────────────
final List<FoodOglas> kSampleOglasi = [
  const FoodOglas(
    id: '1',
    title: 'Domača jabolka z vrta (cca 5 kg)',
    location: 'Maribor, Center',
    time: 'Pred 32 min',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFE8F5E9),
    category: 'Sadje & zelenjava',
    isFree: true,
    distanceKm: 0.4,
    icon: Icons.apple,
  ),
  const FoodOglas(
    id: '2',
    title: 'Polna posoda Golaža',
    location: 'Tezno, Maribor',
    time: 'Pred 1 uro',
    status: OglasStatus.rezervirano,
    username: '@AnaMarija',
    imageColor: Color(0xFFFFE0B2),
    category: 'Kuhano',
    isFree: true,
    isExpiringSoon: true,
    distanceKm: 1.8,
    icon: Icons.soup_kitchen,
  ),
  const FoodOglas(
    id: '3',
    title: 'Svež domač kmečki kruh (polovica)',
    location: 'Hoče',
    time: 'Pred 2 urama',
    status: OglasStatus.prevzeto,
    username: '@LukaP',
    imageColor: Color(0xFFEFEBE9),
    category: 'Peka',
    isFree: false,
    distanceKm: 3.1,
    icon: Icons.bakery_dining,
  ),
  const FoodOglas(
    id: '4',
    title: 'Rižota s piščancem',
    location: 'Center, Maribor',
    time: 'Pred 3 urama',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFF9FBE7),
    category: 'Kuhano',
    isFree: true,
    distanceKm: 0.7,
    icon: Icons.rice_bowl,
  ),
  const FoodOglas(
    id: '5',
    title: 'Paradižnik iz vrta (2 kg)',
    location: 'Pobrežje',
    time: 'Pred 20 min',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFFFEBEE),
    category: 'Sadje & zelenjava',
    isFree: true,
    isExpiringSoon: true,
    distanceKm: 2.3,
    icon: Icons.grass,
  ),
];

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

// ── Helpers ───────────────────────────────────────────────────────────────────
Color statusColor(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago: return const Color(0xFF4CAF50);
    case OglasStatus.rezervirano: return const Color(0xFFFFA726);
    case OglasStatus.prevzeto:    return const Color(0xFF78909C);
  }
}

String statusLabel(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago: return 'NA RAZPOLAGO';
    case OglasStatus.rezervirano: return 'REZERVIRANO';
    case OglasStatus.prevzeto:    return 'PREVZETO';
  }
}
