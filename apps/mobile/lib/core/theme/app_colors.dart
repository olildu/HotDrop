import 'package:flutter/material.dart';

class AppColors {
  // Primary (Electric)
  static const Color primary = Color(0xFFADC6FF);
  static const Color primaryContainer = Color(0xFF4B8EFF);
  static const Color inversePrimary = Color(0xFF005BC1);
  static const Color primaryFixedDim = Color(0xFFADC6FF);

  // Surface (The Void)
  static const Color surface = Color(0xFF121416);
  static const Color surfaceContainerLow = Color(0xFF1A1C1E);
  static const Color surfaceContainerHigh = Color(0xFF2A2D30);
  static const Color surfaceContainerHighest = Color(0xFF33373B);
  static const Color surfaceContainerLowest = Color(0xFF0C0E10);
  static const Color surfaceVariant = Color(0xFF44474E);
  static const Color surfaceBright = Color(0xFF38393F);

  // On-Surface (Text & Icons)
  static const Color onSurface = Color(0xFFE2E2E5);
  static const Color onSurfaceVariant = Color(0xFFC4C6D0);

  // Accents & Others
  static const Color outlineVariant = Color(0x26C4C6D0);

  // Legacy neutral palette used by existing light widgets.
  static const Color legacyNeutralStrong = Color(0xFF49454F);
  static const Color legacyNeutralMuted = Color(0xFF7A7A7A);
  static const Color legacyNeutralMid = Color(0xFF858585);
  static const Color legacyBorderSubtle = Color(0xFFEBEBEB);
  static const Color legacyBorderLight = Color(0xFFE8E8E8);
  static const Color legacySearchBackground = Color(0xFFE2E2E2);
  static const Color legacyProgressTrack = Color(0xFFE0E0E0);

  // Generic semantic/status helpers.
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4CAF50);
  static const Color successAccent = Color(0xFF69F0AE);
  static const Color errorAccent = Color(0xFFFF5252);
  static const Color actionButtonSecondary = Color(0xFF232527);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );
}
