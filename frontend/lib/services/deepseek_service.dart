import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeepSeekService {
  // Ključ še vedno vlečemo iz okolja (okoljskih spremenljivk) ob zagonu
  static const String _apiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  DeepSeekService() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Manjka OPENROUTER_API_KEY. Aplikacijo zaženi z --dart-define=OPENROUTER_API_KEY=...'
      );
    }
  }

  Future<String> generateRecipeSuggestions(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return 'Prosimo, izberite vsaj eno sestavino.';
    }

    final ingredientList = ingredients.join(', ');
    final prompt = '''Predlagaj 5 receptov v slovenščini na podlagi teh sestavin: $ingredientList.

Za vsak recept navedi:
- Ime recepta
- Čas priprave (npr. 30 min)
- Stopnja težavnosti (lahka, srednja, zahtevna)
- Potrebne sestavine
- Kratka navodila za pripravo

Formatiran odgovorem kot seznam receptov, ločenih z dvojno črto (--).''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          // OpenRouter opcijska (vendar priporočljiva) headerja:
          'HTTP-Referer': 'https://localhost', 
          'X-Title': 'Recipe App',
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-chat', // Uporabimo DeepSeek-V3
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        final content = decodedBody['choices'][0]['message']['content'];
        return content ?? 'Napaka pri branju odgovora.';
      } else {
        return 'Napaka strežnika (Status: ${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      return 'Napaka pri povezavi: $e';
    }
  }
}