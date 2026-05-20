import 'package:flutter/material.dart';
import '../common/theme.dart';

class RecipeSuggestionsPage extends StatelessWidget {
  final List<String> ingredients;
  const RecipeSuggestionsPage({super.key, required this.ingredients});

  static const _recipes = [
    {'name': 'Zelenjavna juha', 'icon': Icons.soup_kitchen, 'time': '30 min', 'needs': ['Paradižnik', 'Moka']},
    {'name': 'Jabolčni zavitek', 'icon': Icons.bakery_dining, 'time': '45 min', 'needs': ['Jabolka', 'Moka']},
    {'name': 'Paradižnikova omaka', 'icon': Icons.rice_bowl, 'time': '20 min', 'needs': ['Paradižnik']},
    {'name': 'Sadna solata', 'icon': Icons.grass, 'time': '10 min', 'needs': ['Jabolka']},
    {'name': 'Domač kruh', 'icon': Icons.bakery_dining, 'time': '60 min', 'needs': ['Moka']},
  ];

  List<Map<String, dynamic>> get _suggested {
    if (ingredients.isEmpty) return List<Map<String, dynamic>>.from(_recipes);
    return _recipes.where((r) {
      final needs = r['needs'] as List;
      return needs.any((n) => ingredients.any((i) => i.toLowerCase().contains(n.toString().toLowerCase())));
    }).toList().cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggested.isNotEmpty ? _suggested : List<Map<String, dynamic>>.from(_recipes);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Predlogi receptov', style: TextStyle(fontWeight: FontWeight.w800, fontSize: kFontLarge)),
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: ingredients.map((i) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                  child: Text(i, style: const TextStyle(color: kGreenMid, fontSize: kFontSmall, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('${suggestions.length} receptov', style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: suggestions.length,
              itemBuilder: (_, i) {
                final r = suggestions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: kRadius16, boxShadow: kCardShadow),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
                      child: Icon(r['icon'] as IconData, color: kGreenMid, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['name'] as String, style: kBodyBold),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time, size: kFontSmall, color: kTextLight),
                        const SizedBox(width: 4),
                        Text(r['time'] as String, style: kCaption),
                      ]),
                    ])),
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadius8),
                      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}