import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppTheme {
  const AppTheme._();

  static const background = Color(0xFFF4F7FC);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFD8E2F1);
  static const success = Color(0xFF07966F);
  static const warning = Color(0xFFE98A00);
  static const danger = Color(0xFFE23D4F);

  static ThemeData fromBranding(
    BrandingData branding, {
    Brightness brightness = Brightness.light,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: branding.primary,
      primary: branding.primary,
      secondary: branding.secondary,
      surface: dark ? const Color(0xFF121A2B) : Colors.white,
      error: danger,
      brightness: brightness,
    );
    final themeBackground = dark ? const Color(0xFF0A1020) : background;
    final themeInk = dark ? const Color(0xFFF1F5F9) : ink;
    final themeMuted = dark ? const Color(0xFF9DABC2) : muted;
    final themeBorder = dark ? const Color(0xFF28354C) : border;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: themeBackground,
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: themeInk,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          color: themeInk,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: themeInk,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: themeInk, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: themeMuted, fontSize: 13, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: themeBackground,
        foregroundColor: themeInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: themeInk,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: themeBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: themeMuted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: themeBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: themeBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: branding.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        hintStyle: TextStyle(color: themeMuted, fontSize: 13),
        errorStyle: const TextStyle(color: danger, fontSize: 11),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: branding.button,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: branding.primary,
        indicatorColor: branding.secondary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          );
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        overlayColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.08),
        ),
      ),
      dividerColor: themeBorder,
    );
  }
}
