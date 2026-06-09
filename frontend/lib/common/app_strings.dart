import 'package:flutter/material.dart';
import '../services/locale_service.dart';

/// Prijevodi za FoodWasteZero.
/// Koristiti: final s = AppStrings.of(context);
///
/// Kako dodati novi string:
///   1. Dodaj getter u AppStrings (sl/bs/en)
///   2. Zamijeni hardcoded tekst sa s.imeGettera
class AppStrings {
  final String _code;
  const AppStrings._(this._code);

  static AppStrings of(BuildContext context) {
    final code = LocaleService.instance.code;
    return AppStrings._(code);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _t(String sl, String bs, String en) => switch (_code) {
    'bs' => bs,
    'en' => en,
    _ => sl,
  };

  // ── Općenito / Splošno / General ─────────────────────────────────────────────
  String get ok            => _t('V redu',     'U redu',    'OK');
  String get cancel        => _t('Prekliči',   'Otkaži',    'Cancel');
  String get save          => _t('Shrani',     'Sačuvaj',   'Save');
  String get delete        => _t('Izbriši',    'Obriši',    'Delete');
  String get close         => _t('Zapri',      'Zatvori',   'Close');
  String get confirm       => _t('Potrdi',     'Potvrdi',   'Confirm');
  String get loading       => _t('Nalaganje…', 'Učitavanje…', 'Loading…');
  String get error         => _t('Napaka',     'Greška',    'Error');
  String get yes           => _t('Da',         'Da',        'Yes');
  String get no            => _t('Ne',         'Ne',        'No');

  // ── Navigacija / Navigation ─────────────────────────────────────────────────
  String get home          => _t('Domov',      'Početna',   'Home');
  String get profile       => _t('Profil',     'Profil',    'Profile');
  String get settings      => _t('Nastavitve', 'Postavke',  'Settings');
  String get myListings    => _t('Moje objave','Moji oglasi','My listings');
  String get notifications => _t('Obvestila',  'Obavijesti','Notifications');

  // ── Settings screen ──────────────────────────────────────────────────────────
  String get settingsTitle         => _t('Nastavitve',   'Postavke',     'Settings');
  String get sectionAppearance     => _t('Videz',        'Izgled',       'Appearance');
  String get darkMode              => _t('Temni način',  'Tamni način',  'Dark mode');
  String get darkModeOn            => _t('Vklopljeno',   'Uključeno',    'On');
  String get darkModeOff           => _t('Izklopljeno',  'Isključeno',   'Off');
  String get darkModeSoon          => _t(
    'Temni način bo na voljo v naslednji posodobitvi',
    'Tamni način bit će dostupan u sljedećoj nadogradnji',
    'Dark mode will be available in the next update',
  );

  String get sectionLanguage       => _t('Jezik in regija',   'Jezik i regija',    'Language & Region');
  String get appLanguage           => _t('Jezik aplikacije',  'Jezik aplikacije',  'App language');
  String get searchRadius          => _t('Radij iskanja',     'Radijus pretrage',  'Search radius');
  String get langPickerTitle       => _t('Jezik aplikacije',  'Jezik aplikacije',  'App language');

  String get sectionNotifications  => _t('Obvestila',         'Obavijesti',        'Notifications');
  String get pushNotifications     => _t('Push obvestila',    'Push obavijesti',   'Push notifications');
  String get pushNotifSubtitle     => _t(
    'Novi oglasi in rezervacije',
    'Novi oglasi i rezervacije',
    'New listings and reservations',
  );

  String get sectionLocation       => _t('Lokacija',          'Lokacija',          'Location');
  String get allowLocation         => _t('Dovoli lokacijo',   'Dozvoli lokaciju',  'Allow location');
  String get allowLocationSubtitle => _t(
    'Za iskanje hrane blizu vas',
    'Za traženje hrane u blizini',
    'To find food near you',
  );

  String get sectionAbout          => _t('O aplikaciji',      'O aplikaciji',      'About');
  String get version               => _t('Različica',         'Verzija',           'Version');
  String get project               => _t('Projekt',           'Projekat',          'Project');

  // ── Language names ───────────────────────────────────────────────────────────
  String get langSlovenian         => 'Slovenščina';
  String get langBosnian           => 'Bosanski';
  String get langEnglish           => 'English';

  /// Ime trenutno odabranog jezika
  String labelForCode(String code) => switch (code) {
    'sl' => langSlovenian,
    'bs' => langBosnian,
    'en' => langEnglish,
    _ => langSlovenian,
  };

  // ── Home / Oglasi ────────────────────────────────────────────────────────────
  String get searchHint    => _t('Iskanje hrane…',   'Pretraži hranu…',  'Search food…');
  String get freeOnly      => _t('Samo brezplačno',  'Samo besplatno',   'Free only');
  String get nearMe        => _t('V moji bližini',   'U mojoj blizini',  'Near me');
  String get reserve       => _t('Rezerviraj',       'Rezerviraj',       'Reserve');
  String get reserved      => _t('Rezervirano',      'Rezervirano',      'Reserved');
  String get available     => _t('Na voljo',         'Dostupno',         'Available');
  String get expires       => _t('Poteče',           'Ističe',           'Expires');

  // ── Auth ────────────────────────────────────────────────────────────────────
  String get login         => _t('Prijava',      'Prijava',     'Sign in');
  String get register      => _t('Registracija', 'Registracija','Sign up');
  String get logout        => _t('Odjava',       'Odjava',      'Sign out');
  String get email         => _t('E-pošta',      'E-mail',      'Email');
  String get password      => _t('Geslo',        'Lozinka',     'Password');
  String get name          => _t('Ime',          'Ime',         'Name');

  // ── Profile ─────────────────────────────────────────────────────────────────
  String get editProfile   => _t('Uredi profil',  'Uredi profil', 'Edit profile');
  String get myReserv      => _t('Moje rezervacije', 'Moje rezervacije', 'My reservations');
  String get claimed       => _t('Prevzeto',      'Preuzeto',    'Claimed');
}
