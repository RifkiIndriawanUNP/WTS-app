import 'package:flutter/material.dart';

/// Warna dasar WTS (tema liquid glass: biru muda + kaca buram).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2F6BFF);
  static const primarySoft = Color(0xFFDCE8FF);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
  );
}
