import 'package:flutter/material.dart';

abstract final class FolooColors {
  static const ink = Color(0xFF1F1F1F);
  static const paper = Color(0xFFEFEDE3);
  static const surface = Color(0xFFFFFFFF);
  static const lime = Color(0xFFC9FA00);
  static const gray = Color(0xFF888888);
  static const line = Color(0xFF9A9A96);
  static const success = Color(0xFF3B7517);
  static const warning = Color(0xFFC28B00);
  static const error = Color(0xFFC52B1D);
  static const pending = Color(0xFFDBA008);

  // Compatibility aliases retained for the existing prototype code.
  static const cobalt = ink;
  static const pine = success;
  static const amber = warning;
}

abstract final class FolooTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF242424) : FolooColors.surface;
    final paper = dark ? const Color(0xFF151515) : FolooColors.paper;
    final ink = dark ? const Color(0xFFF7F5ED) : FolooColors.ink;
    final line = dark ? const Color(0xFF666661) : FolooColors.line;
    final field = dark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F6);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: FolooColors.lime,
      onPrimary: FolooColors.ink,
      secondary: FolooColors.lime,
      onSecondary: FolooColors.ink,
      error: FolooColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
    );
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(15)),
      borderSide: BorderSide(color: line, width: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      dividerColor: line,
      fontFamily: 'Arial',
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(color: ink, fontSize: 16),
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        labelStyle: TextStyle(
          color: ink.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(color: ink, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(color: FolooColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(color: FolooColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: line, width: 1.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FolooColors.lime,
          foregroundColor: FolooColors.ink,
          minimumSize: const Size(44, 56),
          shape: const StadiumBorder(
            side: BorderSide(color: FolooColors.ink, width: 1.2),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(44, 52),
          side: BorderSide(color: ink, width: 1.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: FolooColors.lime.withValues(alpha: 0.32),
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        scrimColor: Colors.black.withValues(alpha: 0.42),
      ),
    );
  }
}
