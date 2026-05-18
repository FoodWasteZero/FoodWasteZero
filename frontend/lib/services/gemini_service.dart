import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyDFi_2CIti0nJQ-PtEq9EfADrtUBkcAFDg';
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
  }

  Future<String> generateRecipeSuggestions(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return 'Prosimo, izberite vsaj eno sestavino.';
    }

    final ingredientList = ingredients.join(', ');
    final prompt = '''Predlagi 5 receptov na slovenščini na podlagi teh sestavin: $ingredientList.

Za vsak recept navedi:
- Ime recepta
- Čas priprave (npr. 30 min)
- Stopnja težavnosti (lahka, srednja, zahtevna)
- Potrebne sestavine
- Kratka navodila za pripravo

Formatiran odgovorem kot seznam receptov, ločenih z dvojno črto (--).''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'Napaka pri pridobivanju predlogov.';
    } catch (e) {
      return 'Napaka: $e';
    }
  }
}
