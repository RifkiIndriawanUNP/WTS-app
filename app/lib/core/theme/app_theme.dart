import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.secondary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? AppColors.secondary : AppColors.navy,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          surface: dark ? AppColors.navyDeep : AppColors.tertiary,
          onSurface: dark ? const Color(0xFFF1F5F9) : AppColors.navy,
          onSurfaceVariant: dark
              ? const Color(0xFF9FB0C8)
              : const Color(0xFF475569),
          error: AppColors.error,
        );

    final text = _textTheme(brightness)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      // Semua Scaffold transparan agar LiquidBackground (di app.dart) terlihat.
      scaffoldBackgroundColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.secondary,
        selectionHandleColor: AppColors.secondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1E2B4A) : AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  /// Headline: Plus Jakarta Sans. Body & label: Inter (sesuai Figma).
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final body = GoogleFonts.interTextTheme(base);
    final head = GoogleFonts.plusJakartaSansTextTheme(base);
    return body.copyWith(
      displayLarge: head.displayLarge,
      displayMedium: head.displayMedium,
      displaySmall: head.displaySmall,
      headlineLarge: head.headlineLarge,
      headlineMedium: head.headlineMedium,
      headlineSmall: head.headlineSmall,
      titleLarge: head.titleLarge,
    );
  }
}
