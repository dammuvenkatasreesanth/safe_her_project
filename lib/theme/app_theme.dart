import 'package:flutter/material.dart';

/// Design tokens pulled from the SafeHer Figma file.
class AppColors {
  AppColors._();

  static const primary = Color(0xFFFF5C02);
  static const primaryGrey = Color(0xFF202124);
  static const neutral200 = Color(0xFFE8E8E8);
  static const neutral300 = Color(0xFFD2D2D2);
  static const neutral400 = Color(0xFFBBBBBB);
  static const neutral900 = Color(0xFF4A4A4A);
  static const fieldFill = Color(0xFFFAFAFA);
  static const navBackground = Color(0xFFF3F3F3);
  static const navInactive = Color(0xFF676767);
  static const dot = Color(0xFFD9D9D9);
  static const black = Color(0xFF000000);
}

class AppRadius {
  AppRadius._();

  static const r4 = 8.0;
  static const r5 = 10.0;
  static const r6 = 12.0;
}

class AppTextStyles {
  AppTextStyles._();

  static const _base = TextStyle(color: AppColors.black, height: 1.0);

  static final h5 = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 38 / 32,
  );
  static final calloutBold = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.32,
  );
  static final b1 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 27 / 18,
  );
  static final b2 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );
  static final b3 = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 21 / 14,
  );
  static final b4 = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
  );
  static final b5 = _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 15 / 10,
  );
  static final semibold16 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 15 / 16,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.black,
      displayColor: AppColors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(57),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r6),
        ),
        textStyle: AppTextStyles.b1,
        elevation: 0,
      ),
    ),
  );
}
