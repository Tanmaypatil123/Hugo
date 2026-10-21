import 'package:flutter/material.dart';

/// Hugo's palette. The app is dark-only.
abstract final class HugoColors {
  static const background = Color(0xFF0E0F12);
  static const surface = Color(0xFF17191E);
  static const surfaceHigh = Color(0xFF1F2228);
  static const bar = Color(0xFF121418);
  static const border = Color(0xFF2A2E36);
  static const divider = Color(0xFF23262D);

  static const text = Color(0xFFECEDEF);
  static const textSecondary = Color(0xFFC9CDD4);
  static const textMuted = Color(0xFF9AA0AA);
  static const textFaint = Color(0xFF8B919C);

  static const amber = Color(0xFFF5B83D);
  static const onAmber = Color(0xFF1A1300);
  static const amberSoft = Color(0xFF2A2310);
  static const blue = Color(0xFF7AA2FF);
  static const blueSoft = Color(0xFF18233D);
  static const blueText = Color(0xFF9DB8FF);
  static const green = Color(0xFF7FD9BC);
  static const greenSoft = Color(0xFF13302A);
  static const danger = Color(0xFFFF8A80);
}

const kMonoFamily = 'monospace';
const kMonoFallback = ['Menlo', 'Courier New', 'Courier'];

const TextStyle kMono = TextStyle(
  fontFamily: kMonoFamily,
  fontFamilyFallback: kMonoFallback,
);

ThemeData buildHugoTheme() {
  const scheme = ColorScheme.dark(
    primary: HugoColors.amber,
    onPrimary: HugoColors.onAmber,
    secondary: HugoColors.blue,
    onSecondary: HugoColors.background,
    surface: HugoColors.background,
    onSurface: HugoColors.text,
    surfaceContainerLowest: HugoColors.background,
    surfaceContainerLow: HugoColors.bar,
    surfaceContainer: HugoColors.surface,
    surfaceContainerHigh: HugoColors.surfaceHigh,
    surfaceContainerHighest: HugoColors.surfaceHigh,
    onSurfaceVariant: HugoColors.textMuted,
    outline: HugoColors.border,
    outlineVariant: HugoColors.divider,
    error: HugoColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: HugoColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: HugoColors.text,
      displayColor: HugoColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HugoColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: HugoColors.text,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HugoColors.bar,
      surfaceTintColor: Colors.transparent,
      indicatorColor: HugoColors.amberSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? HugoColors.amber
              : HugoColors.textFaint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? HugoColors.amber
              : HugoColors.textFaint,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: HugoColors.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HugoColors.surface,
      hintStyle: const TextStyle(color: HugoColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HugoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HugoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HugoColors.amber),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HugoColors.amber,
        foregroundColor: HugoColors.onAmber,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HugoColors.text,
        backgroundColor: HugoColors.surface,
        side: const BorderSide(color: HugoColors.border),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: HugoColors.blue),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: HugoColors.surface,
      selectedColor: HugoColors.amberSoft,
      side: const BorderSide(color: HugoColors.border),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: HugoColors.textSecondary,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HugoColors.amber,
      ),
      checkmarkColor: HugoColors.amber,
      shape: const StadiumBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: HugoColors.surfaceHigh,
      contentTextStyle: TextStyle(color: HugoColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HugoColors.bar,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFF3A3F48),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(HugoColors.text),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? HugoColors.amber
            : const Color(0xFF3A3F48),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HugoColors.amber,
    ),
  );
}
