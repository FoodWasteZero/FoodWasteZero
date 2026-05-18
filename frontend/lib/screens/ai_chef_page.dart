import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';

class AIChefPage extends StatefulWidget {
  const AIChefPage({super.key});

  @override
  State<AIChefPage> createState() => _AIChefPageState();
}

class _AIChefPageState extends State<AIChefPage> {
  late GeminiService _geminiService;
  List<String> _selectedIngredients = [];
  String? _recipeSuggestions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
  }

  List<String> _extractIngredientsFromDocs(List<DocumentSnapshot> docs) {
    final ingredients = <String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      
      final title = data['title'] as String? ?? '';
      final description = data['description'] as String? ?? '';
      final category = data['category'] as String? ?? '';
      
      _extractIngredients(title, ingredients);
      _extractIngredients(description, ingredients);
      _extractIngredients(category, ingredients);
    }
    return ingredients.toList()..sort();
  }

  void _extractIngredients(String text, Set<String> ingredients) {
    final parts = text.split(RegExp(r'[,;|/\n]'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && trimmed.length > 2 && trimmed.length < 50) {
        ingredients.add(trimmed);
      }
    }
  }

  Future<void> _generateRecipes() async {
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prosimo, izberite vsaj eno sestavino')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final suggestions = await _geminiService.generateRecipeSuggestions(_selectedIngredients);
      setState(() => _recipeSuggestions = suggestions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
                  decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_outline_rounded, size: 40, color: kGreenMid),
                ),
                const SizedBox(height: 20),
                const Text('Niste prijavljeni', style: kHeading2),
                const SizedBox(height: 8),
                const Text(
                  'Za uporabo AI Chefa\nse prijavite v račun.',
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
        title: const Text('AI Chef 👨‍🍳', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('oglasi')
            .where('status', whereIn: ['rezervirano', 'prevzeto'])
            .where('uid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kGreenMid),
            );
          }

          final allIngredients = snap.hasData 
              ? _extractIngredientsFromDocs(snap.data!.docs)
              : [];

          if (allIngredients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant_rounded, size: 40, color: kGreenMid),
                  ),
                  const SizedBox(height: 20),
                  const Text('Ni dostopnih sestavin', style: kHeading2),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Ko rezervirate ali prevzamete oglas,\nboste imeli dostopne sestavine.',
                      style: kBody,
                      textAlign: TextAlign.center,
                    ),
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
                  const Text('Vaše dostopne sestavine', style: kHeading3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allIngredients.map((ingredient) {
                      final isSelected = _selectedIngredients.contains(ingredient);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIngredients.remove(ingredient);
                            } else {
                              _selectedIngredients.add(ingredient);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? kGreenMid : Colors.white,
                            borderRadius: kRadiusFull,
                            border: Border.all(
                              color: isSelected ? kGreenMid : kGreenPale,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected ? kGreenMid : Colors.grey).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            ingredient,
                            style: TextStyle(
                              color: isSelected ? Colors.white : kTextDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _generateRecipes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: kRadius12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Generiraj recepte',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  if (_recipeSuggestions != null) ...[
                    const SizedBox(height: 32),
                    const Text('Predlagani recepti', style: kHeading3),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: kRadius16,
                        boxShadow: kCardShadow,
                      ),
                      child: SelectableText(
                        _recipeSuggestions!,
                        style: kBody.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
