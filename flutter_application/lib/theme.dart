import 'package:flutter/material.dart';

class AppColors {
  static const ivory = Color(0xFFF8F5EF);
  static const sage = Color(0xFF4F7C68);
  static const coral = Color(0xFFF28C6B);
  static const mint = Color(0xFFE8F2EC);
  static const charcoal = Color(0xFF222222);
  static const gray = Color(0xFF777777);
  static const line = Color(0xFFE8E1D8);
  static const white = Color(0xFFFFFFFF);
  static const blue = Color(0xFF5D8CCB);
  static const green = Color(0xFF61A377);
  static const orange = Color(0xFFE49B58);
  static const purple = Color(0xFF8B78C8);
}

final softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.045),
    blurRadius: 18,
    offset: const Offset(0, 8),
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
    ),
    scaffoldBackgroundColor: AppColors.ivory,
    fontFamily: 'sans-serif',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w800,
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
