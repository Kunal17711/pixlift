import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Material 3 based theme. PixLift ships both light and dark modes.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.brandBlue,
      brightness: brightness,
      primary: BrandColors.brandBlue,
      secondary: BrandColors.cyan,
      tertiary: BrandColors.purple,
      error: const Color(0xFFE5484D),
      surface: isDark ? const Color(0xFF101A36) : const Color(0xFFF7F9FF),
    );

    final baseText = isDark ? const Color(0xFFEAF0FF) : const Color(0xFF0A1226);
    final mutedText = isDark
        ? BrandColors.textMutedDark
        : const Color(0xFF57637E);

    final textTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: baseText, displayColor: baseText)
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 34,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: baseText,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: baseText,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: baseText,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: baseText,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: baseText),
          bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: mutedText),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? BrandColors.deepNavy
          : const Color(0xFFF7F9FF),
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black12,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark
            ? const Color(0xFF1B2A52)
            : const Color(0xFF10203F),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );

    return theme;
  }
}
