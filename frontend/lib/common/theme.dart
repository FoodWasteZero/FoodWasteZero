import 'package:flutter/material.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const kGreen       = Color(0xFF1B5E20);
const kGreenMid    = Color(0xFF2E7D32);
const kGreenLight  = Color(0xFF4CAF50);
const kGreenPale   = Color(0xFFE8F5E9);
const kGreenAccent = Color(0xFF00C853);

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
const kRadius8  = BorderRadius.all(Radius.circular(8));
const kRadius12 = BorderRadius.all(Radius.circular(12));
const kRadius16 = BorderRadius.all(Radius.circular(16));
const kRadius24 = BorderRadius.all(Radius.circular(24));
const kRadiusFull = BorderRadius.all(Radius.circular(100));