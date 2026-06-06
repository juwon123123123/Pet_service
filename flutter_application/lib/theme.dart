import 'package:flutter/material.dart';

class AppColors {
  static const ivory = Color(0xFFF5F6F8);
  static const sage = Color(0xFF0A84FF);
  static const coral = Color(0xFFFF453A);
  static const mint = Color(0xFFEAF4FF);
  static const charcoal = Color(0xFF111827);
  static const gray = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const white = Color(0xFFFFFFFF);
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
}

final softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.055),
    blurRadius: 28,
    offset: const Offset(0, 14),
  ),
];

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      primary: AppColors.sage,
      secondary: AppColors.coral,
      surface: AppColors.white,
      error: AppColors.coral,
    ),
    scaffoldBackgroundColor: AppColors.ivory,
    fontFamily: 'sans-serif',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ivory,
      foregroundColor: AppColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.charcoal,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.charcoal,
      contentTextStyle: const TextStyle(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      hintStyle: const TextStyle(color: AppColors.gray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.mint,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.sage
              : AppColors.gray,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.sage
              : AppColors.gray,
          size: 24,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(color: AppColors.charcoal, letterSpacing: 0),
      bodyMedium: TextStyle(color: AppColors.charcoal, letterSpacing: 0),
    ),
  );
}

String categoryLabel(String category) {
  switch (category) {
    case 'vaccine':
      return '예방접종';
    case 'parasite':
    case 'dental':
    case 'hygiene':
    case 'feeding':
      return '생활관리';
    case 'neuter':
    case 'checkup':
      return '병원 상담';
    case 'socialization':
      return 'AI 추천';
    default:
      return category;
  }
}
