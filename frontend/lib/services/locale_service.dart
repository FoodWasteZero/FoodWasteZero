import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton koji pamti i mijenja jezik aplikacije.
/// Koristiti: LocaleService.instance.setLocale('bs')
class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const _key = 'app_locale';

  Locale _locale = const Locale('sl');
  Locale get locale => _locale;
  String get code => _locale.languageCode;

  /// Učitaj sačuvani jezik iz SharedPreferences (pozovi u main).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'sl';
    _locale = Locale(code);
    notifyListeners();
  }

  /// Promijeni jezik i sačuvaj u SharedPreferences.
  Future<void> setLocale(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
    debugPrint('[LocaleService] Jezik promijenjen na: $languageCode');
    notifyListeners();
  }
}
