class Recipe {
  final String name;
  final String description;
  final String difficulty;
  final String prepTime;
  final List<String> claimedIngredients;
  final List<String> reservedIngredients;

  Recipe({
    required this.name,
    required this.description,
    required this.difficulty,
    required this.prepTime,
    required this.claimedIngredients,
    required this.reservedIngredients,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'srednja',
      prepTime: json['prepTime'] as String? ?? '',
      claimedIngredients: List<String>.from(json['claimedIngredients'] as List? ?? []),
      reservedIngredients: List<String>.from(json['reservedIngredients'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'difficulty': difficulty,
    'prepTime': prepTime,
    'claimedIngredients': claimedIngredients,
    'reservedIngredients': reservedIngredients,
  };
}
