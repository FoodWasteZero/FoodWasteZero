import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';

/// Static recipes database
const List<Map<String, dynamic>> _staticRecipes = [
  {
    'name': 'Zelenjavna juha',
    'ingredients': ['Paradižnik', 'Zelenjava'],
    'time': '30 min',
    'difficulty': 'lahka',
    'description': 'Domača zelenjavna juha s svežimi sestavinami.'
  },
  {
    'name': 'Paradižnikova omaka',
    'ingredients': ['Paradižnik'],
    'time': '20 min',
    'difficulty': 'lahka',
    'description': 'Enostavna paradižnikova omaka za testenine.'
  },
  {
    'name': 'Sadna solata',
    'ingredients': ['Jabolka', 'Sadje'],
    'time': '10 min',
    'difficulty': 'lahka',
    'description': 'Sveža solata iz različnega sadja.'
  },
  {
    'name': 'Jabolčni zavitek',
    'ingredients': ['Jabolka'],
    'time': '45 min',
    'difficulty': 'srednja',
    'description': 'Tradicionalni jabolčni zavitek.'
  },
  {
    'name': 'Domač kruh',
    'ingredients': ['Moka'],
    'time': '60 min',
    'difficulty': 'zahtevna',
    'description': 'Pečen domač kruh iz najboljših sestavin.'
  },
];

/// Recipe Page - displays ingredients as buttons, tap to see recipes
class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  StreamSubscription<User?>? _authSub;
  String? _selectedIngredient;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Sestavine iz oglasov, ki jih je uporabnik rezerviral ali prevzel (ne glede na objavitelja).
  Future<Set<String>> _getAvailableIngredients(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('oglasi')
        .where('reservedByUid', isEqualTo: uid)
        .get();

    const ingredientCategories = {'Sadje & zelenjava', 'Sestavine'};
    const activeStatuses = {'rezervirano', 'prevzeto'};

    final ingredients = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (!activeStatuses.contains(status)) continue;
      final category = data['category'] as String? ?? '';
      if (!ingredientCategories.contains(category)) continue;

      final title = (data['title'] as String?)?.split(RegExp(r'[,;|/\n]')) ?? [];
      for (final part in title) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty && trimmed.length > 2 && trimmed.length < 50) {
          ingredients.add(trimmed);
        }
      }
    }
    return ingredients;
  }

  /// Get recipes that use the selected ingredient
  List<Map<String, dynamic>> _getRecipesForIngredient(String ingredient) {
    return _staticRecipes
        .where((recipe) {
          final ingredients = List<String>.from(recipe['ingredients'] as List);
          return ingredients.any(
            (ing) => ing.toLowerCase().contains(ingredient.toLowerCase()) ||
                ingredient.toLowerCase().contains(ing.toLowerCase()),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: kSurface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: kGreenMid,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Niste prijavljeni', style: kHeading2),
                const SizedBox(height: 8),
                const Text(
                  'Prijavite se, da vidite sestavine\niz svojih rezervacij.',
                  style: kBody,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: Text(
          _selectedIngredient == null ? 'Recepti' : 'Recepti',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: kFontLarge),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0,
        leading: _selectedIngredient != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _selectedIngredient = null);
                },
              )
            : null,
      ),
      body: _selectedIngredient == null
          ? _buildIngredientsView(user.uid)
          : _buildRecipesView(_selectedIngredient!),
    );
  }

  /// Build ingredients view - show as buttons
  Widget _buildIngredientsView(String uid) {
    return FutureBuilder<Set<String>>(
      future: _getAvailableIngredients(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kGreenMid),
          );
        }

        if (!snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 40,
                    color: kGreenMid,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Ni sestavin', style: kHeading2),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Rezervirajte ali prevzemite oglase\nkategorij Sadje & zelenjava ali Sestavine.',
                    style: kBody,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final ingredients = snap.data!.toList()..sort();

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vaše sestavine', style: kHeading3),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ingredients.map((ingredient) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIngredient = ingredient);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: kRadius12,
                          border: Border.all(color: kGreenMid, width: 2),
                          boxShadow: kCardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, size: 18, color: kGreenMid),
                            const SizedBox(width: 8),
                            Text(
                              ingredient,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: kGreenMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build recipes view - show static recipes for selected ingredient
  Widget _buildRecipesView(String ingredient) {
    final recipes = _getRecipesForIngredient(ingredient);

    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kOrangePale,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                size: 40,
                color: kOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Ni receptov', style: kHeading2),
            const SizedBox(height: 8),
            Text(
              'Za $ingredient trenutno ni receptov.',
              style: kBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recepti z $ingredient', style: kHeading3),
            const SizedBox(height: 16),
            ...recipes.map((recipe) {
              final difficulty = recipe['difficulty'] as String;
              final diffColor = difficulty == 'lahka'
                  ? kGreenAccent
                  : difficulty == 'srednja'
                      ? kOrange
                      : const Color(0xFFE57373);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kRadius16,
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['name'] as String,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 16, color: kTextLight),
                        const SizedBox(width: 6),
                        Text(
                          recipe['time'] as String,
                          style: kCaption,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.15),
                            borderRadius: kRadius8,
                          ),
                          child: Text(
                            difficulty,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: diffColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recipe['description'] as String,
                      style: kBody.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (recipe['ingredients'] as List<String>)
                          .map((ing) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kGreenPale,
                              borderRadius: kRadius8,
                            ),
                            child: Text(
                              ing,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kGreenMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                          .toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Convert Firestore document to FoodOglas object
  FoodOglas _docToOglas(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final statusStr = d['status'] as String? ?? 'naRazpolago';
    final status = statusStr == 'rezervirano'
        ? OglasStatus.rezervirano
        : statusStr == 'prevzeto'
            ? OglasStatus.prevzeto
            : OglasStatus.naRazpolago;

    final category = d['category'] as String? ?? 'Sestavine';
    final IconData icon;
    switch (category) {
      case 'Sadje & zelenjava':
        icon = Icons.apple_rounded;
        break;
      case 'Sestavine':
        icon = Icons.grass_rounded;
        break;
      default:
        icon = Icons.grass_rounded;
    }

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

    bool expiringSoon = d['expiringSoon'] as bool? ?? false;
    if (expiryDate != null) {
      final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
      if (hoursLeft <= 24 && hoursLeft >= 0) expiringSoon = true;
    }

    return FoodOglas(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      location: d['location'] as String? ?? '',
      time: _timeAgo(createdAt),
      status: status,
      username: d['username'] as String?,
      imageColor: const Color(0xFFE8F5E9),
      category: category,
      isFree: d['isFree'] as bool? ?? true,
      isExpiringSoon: expiringSoon,
      distanceKm: 0.0,
      icon: icon,
      expiryDate: expiryDate,
    );
  }

  /// Format time ago for display
  String _timeAgo(DateTime? date) {
    if (date == null) return 'Unknown';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'Over a week ago';
  }
}
