import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color gradientStart = Color(0xFF0B4C56);
  static const Color gradientEnd = Color(0xFF13A2B4);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  static const Color logoAda = Color(0xFF13A2B4);
  static const Color logoTamu = Color(0xFFF6E84B);
  static const Color logoIcon = Color(0xFF13A2B4);
  static const Color welcomeText = Color(0xFFF6E84B);
  static const Color buttonDashboardBackground = Color(0xFFF6E84B);
  static const Color buttonFormBackground = Color(0xFFF6E84B);
  static const Color buttonText = Color(0xFF0B2B30);

  static const Color formBackground = Color(0xFFEDEDED);
  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color inputFillFocused = Color(0xFFCDEBEF);
  static const Color inputBorderFocused = Color(0xFF13A2B4);
  static const Color labelText = Color(0xFF0B2B30);
}

class AppTextStyles {
  AppTextStyles._();
  static String get fontFamily => 'Georgia';

  static TextStyle get welcomeTitle => const TextStyle(
        fontFamily: fontFamilyConst,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.welcomeText,
      );

  static TextStyle get logoAdaText => const TextStyle(
        fontFamily: fontFamilyConst,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.logoAda,
      );

  static TextStyle get logoTamuText => const TextStyle(
        fontFamily: fontFamilyConst,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.logoTamu,
      );

  static TextStyle get fieldLabel => const TextStyle(
        fontFamily: fontFamilyConst,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.labelText,
      );

  static TextStyle get buttonLabel => const TextStyle(
        fontFamily: fontFamilyConst,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.buttonText,
      );

  static const String fontFamilyConst = 'Georgia';
}
