import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton koji pamti i mijenja temu aplikacije.
/// Koristiti: ThemeService.instance.setDark(true)
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'app_theme_dark';

  bool _isDark = false;
  bool get isDark => _isDark;

  /// Učitaj sačuvanu temu iz SharedPreferences (pozovi u main).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Promijeni temu i sačuvaj u SharedPreferences.
  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    debugPrint('[ThemeService] Tema promijenjena na: ${value ? "tamna" : "svijetla"}');
    notifyListeners();
  }
}