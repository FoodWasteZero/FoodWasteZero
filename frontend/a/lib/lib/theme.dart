import 'package:flutter/material.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const kGreen       = Color(0xFF1B5E20);
const kGreenMid    = Color(0xFF2E7D32);
const kGreenLight  = Color(0xFF4CAF50);
const kGreenPale   = Color(0xFFE8F5E9);
const kGreenAccent = Color(0xFF00C853);

const kOrange      = Color(0xFFFF6F00);
const kOrangePale  = Color(0xFFFFF8E1);

const kSurface     = Color(0xFFF7FAF7);
const kCard        = Colors.white;
const kBorder      = Color(0xFFE0E0E0);

const kTextDark    = Color(0xFF1A1A1A);
const kTextMid     = Color(0xFF555555);
const kTextLight   = Color(0xFF9E9E9E);

// ── Shadows ───────────────────────────────────────────────────────────────────
List<BoxShadow> get kCardShadow => [
  BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
];

List<BoxShadow> get kElevatedShadow => [
  BoxShadow(
    color: kGreenMid.withOpacity(0.15),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

// ── Text styles ───────────────────────────────────────────────────────────────
const kHeading1 = TextStyle(
  fontSize: 28, fontWeight: FontWeight.w900,
  color: kTextDark, letterSpacing: -0.5,
);
const kHeading2 = TextStyle(
  fontSize: 20, fontWeight: FontWeight.w800,
  color: kTextDark,
);
const kHeading3 = TextStyle(
  fontSize: 16, fontWeight: FontWeight.w700,
  color: kTextDark,
);
const kBody = TextStyle(
  fontSize: 14, fontWeight: FontWeight.w400,
  color: kTextMid,
);
const kBodyBold = TextStyle(
  fontSize: 14, fontWeight: FontWeight.w600,
  color: kTextDark,
);
const kCaption = TextStyle(
  fontSize: 12, fontWeight: FontWeight.w400,
  color: kTextLight,
);

// ── Border radius ─────────────────────────────────────────────────────────────
const kRadius8  = BorderRadius.all(Radius.circular(8));
const kRadius12 = BorderRadius.all(Radius.circular(12));
const kRadius16 = BorderRadius.all(Radius.circular(16));
const kRadius24 = BorderRadius.all(Radius.circular(24));
const kRadiusFull = BorderRadius.all(Radius.circular(100));
