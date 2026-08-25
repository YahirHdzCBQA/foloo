import 'package:flutter/material.dart';

/// Closed visual vocabulary extracted from `Foloo Mockups Basic.html`.
abstract final class FolooColors {
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F1F1F);
  static const lime = Color(0xFFC9FA00);
  static const gray = Color(0xFF888888);

  static const paper = Color(0xFFF5F5F5);
  static const board = Color(0xFFEBEBEB);
  static const line = Color(0xFFE0E0E0);
  static const secondary = Color(0xFF5C5C5C);
  static const limeTint = Color(0xFFF7FEDF);

  // Status hues are copied from the rendered Basic mockup. Do not replace
  // them with the former dark prototype colors.
  static const success = Color(0xFF3F6B15);
  static const warning = Color(0xFFB4790A);
  static const error = Color(0xFFB3261E);
  static const pending = warning;

  // Interest semaphore and record rails are deliberately brighter than the
  // semantic status palette, exactly as rendered in the Basic mockups.
  static const interestLow = lime;
  static const interestMedium = Color(0xFFFFF900);
  static const interestHigh = Color(0xFFFF2500);
  static const uploadPendingTint = Color(0xFFDDDDDD);

  static const darkSurface = Color(0xFF2A2A2A);
  static const darkPaper = Color(0xFF171717);
  static const darkLine = Color(0xFF3B3B3B);
  static const darkSuccess = Color(0xFFA6D96A);
  static const darkWarning = Color(0xFFE3B341);
  static const darkError = Color(0xFFF0827B);

  // Compatibility aliases retained while the prototype is migrated.
  static const cobalt = ink;
  static const pine = success;
  static const amber = warning;
}

@immutable
class FolooPalette extends ThemeExtension<FolooPalette> {
  const FolooPalette({
    required this.paper,
    required this.card,
    required this.sunken,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.line,
    required this.lineStrong,
    required this.success,
    required this.successTint,
    required this.pending,
    required this.pendingTint,
    required this.error,
    required this.errorTint,
  });

  final Color paper;
  final Color card;
  final Color sunken;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color line;
  final Color lineStrong;
  final Color success;
  final Color successTint;
  final Color pending;
  final Color pendingTint;
  final Color error;
  final Color errorTint;

  static FolooPalette of(BuildContext context) =>
      Theme.of(context).extension<FolooPalette>()!;

  @override
  FolooPalette copyWith({
    Color? paper,
    Color? card,
    Color? sunken,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? line,
    Color? lineStrong,
    Color? success,
    Color? successTint,
    Color? pending,
    Color? pendingTint,
    Color? error,
    Color? errorTint,
  }) => FolooPalette(
    paper: paper ?? this.paper,
    card: card ?? this.card,
    sunken: sunken ?? this.sunken,
    ink: ink ?? this.ink,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkMuted: inkMuted ?? this.inkMuted,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    success: success ?? this.success,
    successTint: successTint ?? this.successTint,
    pending: pending ?? this.pending,
    pendingTint: pendingTint ?? this.pendingTint,
    error: error ?? this.error,
    errorTint: errorTint ?? this.errorTint,
  );

  @override
  FolooPalette lerp(covariant FolooPalette other, double t) => FolooPalette(
    paper: Color.lerp(paper, other.paper, t)!,
    card: Color.lerp(card, other.card, t)!,
    sunken: Color.lerp(sunken, other.sunken, t)!,
    ink: Color.lerp(ink, other.ink, t)!,
    inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
    inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
    line: Color.lerp(line, other.line, t)!,
    lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
    success: Color.lerp(success, other.success, t)!,
    successTint: Color.lerp(successTint, other.successTint, t)!,
    pending: Color.lerp(pending, other.pending, t)!,
    pendingTint: Color.lerp(pendingTint, other.pendingTint, t)!,
    error: Color.lerp(error, other.error, t)!,
    errorTint: Color.lerp(errorTint, other.errorTint, t)!,
  );
}

abstract final class FolooSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const gutter = 20.0;
  static const touch = 48.0;
  static const dock = 56.0;
}

abstract final class FolooRadii {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class FolooBorders {
  static const borderlessField = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(FolooRadii.md)),
    borderSide: BorderSide.none,
  );
}

abstract final class FolooTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = FolooPalette(
      paper: dark ? FolooColors.darkPaper : FolooColors.paper,
      card: dark ? FolooColors.darkSurface : FolooColors.white,
      sunken: dark ? const Color(0xFF141414) : FolooColors.paper,
      ink: dark ? FolooColors.white : FolooColors.ink,
      inkSecondary: dark ? FolooColors.gray : FolooColors.secondary,
      inkMuted: dark ? const Color(0xFF7A7A7A) : FolooColors.gray,
      line: dark ? FolooColors.darkLine : FolooColors.line,
      lineStrong: dark ? const Color(0xFF4A4A4A) : FolooColors.gray,
      success: dark ? FolooColors.darkSuccess : FolooColors.success,
      successTint: dark
          ? FolooColors.darkSuccess.withValues(alpha: .16)
          : FolooColors.success.withValues(alpha: .13),
      pending: dark ? FolooColors.darkWarning : FolooColors.warning,
      pendingTint: dark
          ? FolooColors.darkWarning.withValues(alpha: .16)
          : FolooColors.warning.withValues(alpha: .14),
      error: dark ? FolooColors.darkError : FolooColors.error,
      errorTint: dark
          ? FolooColors.darkError.withValues(alpha: .16)
          : FolooColors.error.withValues(alpha: .13),
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: FolooColors.lime,
      onPrimary: FolooColors.ink,
      secondary: FolooColors.lime,
      onSecondary: FolooColors.ink,
      error: palette.error,
      onError: dark ? FolooColors.ink : FolooColors.white,
      surface: palette.card,
      onSurface: palette.ink,
    );
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(FolooRadii.md)),
      borderSide: BorderSide(color: palette.lineStrong),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.paper,
      dividerColor: palette.line,
      extensions: [palette],
      // Poppins, DM Sans and Nexa binaries are not present as installable
      // Flutter assets. D-12 remains open; platform sans is the safe fallback.
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: palette.ink,
          fontSize: 44,
          height: .91,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.6,
        ),
        headlineSmall: TextStyle(
          color: palette.ink,
          fontSize: 26,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -.8,
        ),
        titleLarge: TextStyle(
          color: palette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -.3,
        ),
        titleMedium: TextStyle(
          color: palette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: palette.ink, fontSize: 17, height: 1.5),
        bodyMedium: TextStyle(color: palette.ink, fontSize: 15, height: 1.45),
        bodySmall: TextStyle(color: palette.inkSecondary, fontSize: 13),
        labelLarge: TextStyle(
          color: palette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.paper,
        hintStyle: TextStyle(color: palette.inkMuted),
        labelStyle: TextStyle(color: palette.ink, fontWeight: FontWeight.w500),
        border: border,
        enabledBorder: border.copyWith(
          borderSide: BorderSide(color: palette.lineStrong),
        ),
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: palette.ink, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolooRadii.lg),
          side: BorderSide(color: palette.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FolooColors.lime,
          foregroundColor: FolooColors.ink,
          minimumSize: const Size(FolooSpace.touch, FolooSpace.dock),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: FolooColors.lime,
          foregroundColor: FolooColors.ink,
          minimumSize: const Size(FolooSpace.touch, FolooSpace.dock),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(FolooSpace.touch, FolooSpace.touch),
          side: BorderSide(color: palette.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolooRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.paper,
        selectedColor: FolooColors.lime.withValues(alpha: .34),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: palette.ink, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.card,
        scrimColor: FolooColors.ink.withValues(alpha: .42),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: TextStyle(color: palette.card),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolooRadii.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
