import 'package:flutter/material.dart';

class CotahubTheme {
  static const Color background = Color(0xFF090C12);
  static const Color surface = Color(0xFF131821);
  static const Color surfaceAlt = Color(0xFF19202B);
  static const Color surfaceSoft = Color(0xFF222B38);
  static const Color surfaceWarm = Color(0xFF223042);
  static const Color overlay = Color(0xB3111720);
  static const Color textPrimary = Color(0xFFF3F6FB);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color line = Color(0xFF2A3545);
  static const Color primary = Color(0xFFF3F6FB);
  static const Color accent = Color(0xFF78A4FF);
  static const Color blue = Color(0xFF4F7DFF);
  static const Color green = Color(0xFF58C59B);
  static const Color gold = Color(0xFF8EA4D8);

  static ThemeData buildTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: background,
      secondary: blue,
      onSecondary: textPrimary,
      error: Color(0xFFFF6B6B),
      onError: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      primaryContainer: surfaceAlt,
      onPrimaryContainer: textPrimary,
      secondaryContainer: surfaceSoft,
      onSecondaryContainer: textPrimary,
      tertiary: accent,
      onTertiary: textPrimary,
      tertiaryContainer: surfaceWarm,
      onTertiaryContainer: textPrimary,
      errorContainer: Color(0xFF3A1D22),
      onErrorContainer: textPrimary,
      outline: line,
      outlineVariant: Color(0xFF151B24),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: background,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: line,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceSoft,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: line),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
