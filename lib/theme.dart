import 'package:flutter/material.dart';

/// Same brand accent as the SafeHer mobile app, applied to a desktop/web
/// admin-dashboard layout rather than a phone UI.
class AppColors {
  AppColors._();
  static const primary = Color(0xFFFF5C02);
  static const dark = Color(0xFF1D1D1D);
  static const neutral900 = Color(0xFF4A4A4A);
  static const neutral400 = Color(0xFFBBBBBB);
  static const neutral300 = Color(0xFFD2D2D2);
  static const neutral200 = Color(0xFFE8E8E8);
  static const surface = Color(0xFFFAFAFA);
  static const sidebar = Color(0xFF1A1A1A);
  static const danger = Color(0xFFE0334D);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
}

ThemeData buildAdminTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.dark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.neutral200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.neutral300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
