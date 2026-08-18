import 'package:flutter/material.dart';

abstract final class FolooColors {
  static const ink = Color(0xFF17232F);
  static const paper = Color(0xFFEBE9E1);
  static const surface = Color(0xFFFFFFFF);
  static const cobalt = Color(0xFF1E44D8);
  static const pine = Color(0xFF145C42);
  static const amber = Color(0xFF9A6700);
  static const line = Color(0xFFD3CDC0);
  static const error = Color(0xFFB3261E);
}

abstract final class FolooTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: FolooColors.cobalt,
      brightness: Brightness.light,
      primary: FolooColors.cobalt,
      surface: FolooColors.surface,
      error: FolooColors.error,
    );
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: FolooColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FolooColors.paper,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: FolooColors.ink,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: FolooColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        titleMedium: TextStyle(
          color: FolooColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: FolooColors.ink, fontSize: 16),
        bodyMedium: TextStyle(color: FolooColors.ink, fontSize: 14),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFFAFAF7),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: FolooColors.cobalt, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: FolooColors.error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        color: FolooColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: FolooColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FolooColors.cobalt,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FolooColors.ink,
          minimumSize: const Size(44, 48),
          side: const BorderSide(color: FolooColors.ink),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFAFAF7),
        selectedColor: FolooColors.cobalt.withValues(alpha: 0.12),
        side: const BorderSide(color: FolooColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(
          color: FolooColors.ink,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}
