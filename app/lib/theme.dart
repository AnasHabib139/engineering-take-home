import 'package:flutter/material.dart';

/// Design tokens. Read DESIGN.md before adding a colour or a text style.
abstract final class AppColors {
  static const ink = Color(0xFF18233A);
  static const inkMuted = Color(0xFF5A6478);
  static const paper = Color(0xFFF3F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDE2EA);
  static const primary = Color(0xFF2F3E9E);
  static const error = Color(0xFFB3261E);
}

const fontFamily = 'Atkinson Hyperlegible';

abstract final class Space {
  static const double xs = 4, s = 8, m = 16, l = 24, xl = 40;

  /// Content never gets wider than a large phone, even in a desktop browser.
  static const double maxContentWidth = 560;
}

abstract final class Radii {
  static const card = BorderRadius.all(Radius.circular(16));
  static const control = BorderRadius.all(Radius.circular(12));
}

/// The mood scale, 1 (very low) to 5 (very good): stormy to sunny.
/// Never show a mood by colour alone; pair it with [label].
abstract final class Mood {
  static const _labels = ['Very low', 'Low', 'Okay', 'Good', 'Very good'];
  static const _colors = [
    Color(0xFF4B4E8C),
    Color(0xFF5272A6),
    Color(0xFFA9B4C4),
    Color(0xFFF0C75E),
    Color(0xFFF59E3D),
  ];

  static const values = [1, 2, 3, 4, 5];
  static String label(int mood) => _labels[mood - 1];
  static Color color(int mood) => _colors[mood - 1];
  static Color onColor(int mood) => mood <= 2 ? Colors.white : AppColors.ink;
}

ThemeData buildTheme() {
  const outline = OutlineInputBorder(
    borderRadius: Radii.control,
    borderSide: BorderSide(color: AppColors.line),
  );
  return ThemeData(
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outlineVariant: AppColors.line,
      error: AppColors.error,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: AppColors.inkMuted),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 14, color: AppColors.inkMuted),
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: Color(0xFFE3E7F7),
      side: BorderSide(color: AppColors.line),
      shape: StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}
