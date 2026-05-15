import 'package:flutter/material.dart';
import 'theme.dart';

class RecipeSuggestionsPage extends StatelessWidget {
  final List<String> ingredients;
  const RecipeSuggestionsPage({super.key, required this.ingredients});

  // Very lightweight mock recipe generator based on ingredient names
  List<_Recipe> get _recipes {
    final all = <_Recipe>[
      _Recipe(
        name: 'Jabolčni zavitek',
        time: '45 min',
        difficulty: 'Srednje',
        ingredients: ['Jabolka', 'Moka', 'Sladkor', 'Maslo'],
        icon: Icons.cake,
        color: const Color(0xFFE8F5E9),
      ),
      _Recipe(
        name: 'Paradižnikova juha',
        time: '30 min',
        difficulty: 'Enostavno',
        ingredients: ['Paradižnik', 'Čebula', 'Česen', 'Olivno olje'],
        icon: Icons.soup_kitchen,
        color: const Color(0xFFFFEBEE),
      ),
      _Recipe(
        name: 'Domači kruh',
        time: '90 min',
        difficulty: 'Srednje',
        ingredients: ['Moka', 'Voda', 'Kvas', 'Sol'],
        icon: Icons.bakery_dining,
        color: const Color(0xFFF5F5F5),
      ),
      _Recipe(
        name: 'Zelenjavna enolončnica',
        time: '40 min',
        difficulty: 'Enostavno',
        ingredients: ['Paradižnik', 'Jabolka', 'Korenje', 'Čebula'],
        icon: Icons.rice_bowl,
        color: const Color(0xFFF9FBE7),
      ),
      _Recipe(
        name: 'Sadna solata',
        time: '10 min',
        difficulty: 'Enostavno',
        ingredients: ['Jabolka', 'Pomaranče', 'Med', 'Limona'],
        icon: Icons.local_florist,
        color: const Color(0xFFFFF8E1),
      ),
    ];

    if (ingredients.isEmpty) return all;

    // Score recipes by matching ingredients
    final lower = ingredients.map((e) => e.toLowerCase()).toList();
    final scored = all.map((r) {
      int score = 0;
      for (final ri in r.ingredients) {
        for (final ui in lower) {
          if (ri.toLowerCase().contains(ui) || ui.contains(ri.toLowerCase())) {
            score++;
          }
        }
      }
      return (r, score);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return scored.map((e) => e.$1).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            if (ingredients.isNotEmpty) _buildIngredientStrip(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Text('Predlagani recepti', style: kHeading3),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreenPale, borderRadius: kRadiusFull,
                    ),
                    child: Text('${_recipes.length} receptov',
                        style: const TextStyle(
                            color: kGreenMid, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: _recipes.length,
                itemBuilder: (_, i) => _RecipeCard(recipe: _recipes[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kGreenPale, borderRadius: kRadius12,
              ),
              child: const Icon(Icons.arrow_back, color: kGreenMid, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Predlogi receptov', style: kHeading2),
                Text('Na podlagi izbranih sestavin',
                    style: TextStyle(fontSize: 12, color: kTextLight)),
              ],
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kGreenMid, borderRadius: kRadius12,
              boxShadow: kElevatedShadow,
            ),
            child: const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Izbrane sestavine',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: kTextLight)),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ingredients.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kGreenMid,
                  borderRadius: kRadiusFull,
                ),
                child: Text(ingredients[i],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Recipe {
  final String name;
  final String time;
  final String difficulty;
  final List<String> ingredients;
  final IconData icon;
  final Color color;

  const _Recipe({
    required this.name, required this.time, required this.difficulty,
    required this.ingredients, required this.icon, required this.color,
  });
}

class _RecipeCard extends StatefulWidget {
  final _Recipe recipe;
  const _RecipeCard({super.key, required this.recipe});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: kRadius16,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: widget.recipe.color,
                    borderRadius: kRadius12,
                  ),
                  child: Icon(widget.recipe.icon,
                      color: kGreenMid, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.recipe.name, style: kBodyBold),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Tag(Icons.timer_outlined, widget.recipe.time),
                          const SizedBox(width: 8),
                          _Tag(Icons.bar_chart_outlined,
                              widget.recipe.difficulty),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: kGreenPale, borderRadius: kRadius8,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: kGreenMid, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: kBorder, height: 1),
                  const SizedBox(height: 10),
                  const Text('Sestavine:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: kTextMid)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: widget.recipe.ingredients
                        .map((ing) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: kRadiusFull,
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(ing,
                          style: const TextStyle(
                              fontSize: 11, color: kTextMid)),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: const Text('Prikaži recept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
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

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: kTextLight),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextLight)),
      ],
    );
  }
}
