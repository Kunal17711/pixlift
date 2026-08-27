import 'package:flutter/material.dart';

/// Brand color palette — extracted from the PixLift logo (blue, cyan,
/// purple/pink highlights on deep navy). Used throughout the interface.
class BrandColors {
  BrandColors._();

  static const Color deepNavy = Color(0xFF0A1226);
  static const Color deepNavyAlt = Color(0xFF0E1A38);
  static const Color brandBlue = Color(0xFF2F6BFF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color mint = Color(0xFF34E6CB);
  static const Color purple = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFF472B6);
  static const Color textOnDark = Color(0xFFEAF0FF);
  static const Color textMutedDark = Color(0xFF9FB0CD);

  /// Primary gradient used for CTAs and accents.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brandBlue, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient deepGradient = LinearGradient(
    colors: [deepNavy, deepNavyAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aurora = LinearGradient(
    colors: [brandBlue, cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
  );
}
