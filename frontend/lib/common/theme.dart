import 'package:flutter/material.dart';

// ── Dark mode colours ─────────────────────────────────────────────────────────
// Accessible via Theme.of(context).extension<AppColors>()
const kDarkSurface    = Color(0xFF121212);
const kDarkCard       = Color(0xFF1E1E1E);
const kDarkCardAlt    = Color(0xFF2C2C2C);
const kDarkBorder     = Color(0xFF333333);
const kDarkTextDark   = Color(0xFFF5F5F5);
const kDarkTextMid    = Color(0xFFAAAAAA);
const kDarkTextLight  = Color(0xFF666666);

// ── Brand colours ─────────────────────────────────────────────────────────────
const kGreen       = Color(0xFF1B5E20);
const kGreenDark   = Color(0xFF1B5E20);
const kGreenMid    = Color(0xFF2E7D32);
const kGreenLight  = Color(0xFF4CAF50);
const kGreenPale   = Color(0xFFE8F5E9);
const kGreenAccent = Color(0xFF00C853);

const kYellow      = Color(0xFFFBC02D);
const kYellowPale  = Color(0xFFFFF9C4);

const kOrange      = Color(0xFFFF6F00);
const kOrangePale  = Color(0xFFFFF8E1);

const kSurface     = Color(0xFFF0F4F0);
const kCard        = Colors.white;
const kBorder      = Color(0xFFE0E0E0);

const kTextDark    = Color(0xFF1A1A1A);
const kTextMid     = Color(0xFF555555);
const kTextLight   = Color(0xFF9E9E9E);

// ── Shadows ───────────────────────────────────────────────────────────────────
List<BoxShadow> get kCardShadow => [
  BoxShadow(
    color: Colors.black.withOpacity(0.10),
    blurRadius: 20,
    offset: const Offset(0, 6),
  ),
  BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

List<BoxShadow> get kElevatedShadow => [
  BoxShadow(
    color: kGreenMid.withOpacity(0.20),
    blurRadius: 28,
    offset: const Offset(0, 10),
  ),
  BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 8,
    offset: const Offset(0, 3),
  ),
];

// ── Standard font sizes ───────────────────────────────────────────────────────
const double kFontXSmall  = 12.0;
const double kFontSmall   = 14.0;
const double kFontBase    = 16.0;
const double kFontMedium  = 18.0;
const double kFontLarge   = 20.0;
const double kFontXLarge  = 24.0;
const double kFont2XLarge = 28.0;
const double kFont3XLarge = 32.0;

// ── Text styles ───────────────────────────────────────────────────────────────
const kHeading1 = TextStyle(
  fontSize: kFont3XLarge, fontWeight: FontWeight.w900,
  color: kTextDark, letterSpacing: -0.5,
);
const kHeading2 = TextStyle(
  fontSize: kFontXLarge, fontWeight: FontWeight.w800,
  color: kTextDark,
);
const kHeading3 = TextStyle(
  fontSize: kFontMedium, fontWeight: FontWeight.w700,
  color: kTextDark,
);
const kBody = TextStyle(
  fontSize: kFontBase, fontWeight: FontWeight.w400,
  color: kTextMid,
);
const kBodyBold = TextStyle(
  fontSize: kFontBase, fontWeight: FontWeight.w600,
  color: kTextDark,
);
const kCaption = TextStyle(
  fontSize: kFontSmall, fontWeight: FontWeight.w400,
  color: kTextLight,
);

// ── Additional semantic text styles ───────────────────────────────────────────
const kButtonText = TextStyle(
  fontSize: kFontBase, fontWeight: FontWeight.w700,
  color: Colors.white,
);
const kSmallCaption = TextStyle(
  fontSize: kFontXSmall, fontWeight: FontWeight.w400,
  color: kTextLight,
);

// ── Border radius ─────────────────────────────────────────────────────────────
const kRadius6  = BorderRadius.all(Radius.circular(6));
const kRadius8  = BorderRadius.all(Radius.circular(8));
const kRadius12 = BorderRadius.all(Radius.circular(12));
const kRadius16 = BorderRadius.all(Radius.circular(16));
const kRadius24 = BorderRadius.all(Radius.circular(24));
const kRadiusFull = BorderRadius.all(Radius.circular(100));

// ── AppTheme ──────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGreenMid,
      primary: kGreenMid,
      surface: kSurface,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: kSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kTextDark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardColor: Colors.white,
    dividerColor: kBorder,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreenMid,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGreenMid,
        side: const BorderSide(color: kGreenMid),
        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    tabBarTheme: const TabBarThemeData(dividerColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kGreenMid,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: kRadius12),
    ),
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: kGreenMid,
      primary: kGreenLight,
      surface: kDarkSurface,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: kDarkSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: kDarkCard,
      foregroundColor: kDarkTextDark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardColor: kDarkCard,
    dividerColor: kDarkBorder,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreenMid,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGreenLight,
        side: const BorderSide(color: kGreenLight),
        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    tabBarTheme: const TabBarThemeData(dividerColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kGreenMid,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: kRadius12),
    ),
  );
}
// ── Dark-aware color helpers ──────────────────────────────────────────────────
// Koristiti ovako: final c = AppColors.of(context);
// c.card, c.surface, c.textDark, itd.
class AppColors {
  final Color card;
  final Color cardAlt;
  final Color surface;
  final Color border;
  final Color textDark;
  final Color textMid;
  final Color textLight;

  const AppColors._({
    required this.card,
    required this.cardAlt,
    required this.surface,
    required this.border,
    required this.textDark,
    required this.textMid,
    required this.textLight,
  });

  static AppColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? _dark : _light;
  }

  static const _light = AppColors._(
    card: Colors.white,
    cardAlt: Color(0xFFF5F5F5),
    surface: kSurface,
    border: kBorder,
    textDark: kTextDark,
    textMid: kTextMid,
    textLight: kTextLight,
  );

  static const _dark = AppColors._(
    card: kDarkCard,
    cardAlt: kDarkCardAlt,
    surface: kDarkSurface,
    border: kDarkBorder,
    textDark: kDarkTextDark,
    textMid: kDarkTextMid,
    textLight: kDarkTextLight,
  );
}
