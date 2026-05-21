import 'package:flutter/material.dart';

class AppColors {
  static const Color stravaOrange = Color(0xFFFC4C02);
  static const Color darkBackground = Color(0xFF111111);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color subtleGrey = Color(0xFF8E8E93);
  static const Color lightGrey = Color(0xFFEFEFEF);
}

/// Continuous-corner ("squircle") shape used across the app for cards,
/// buttons, dialogs and sheets. Visually smoother than RoundedRectangleBorder.
ShapeBorder appShape(double radius) =>
    ContinuousRectangleBorder(borderRadius: BorderRadius.circular(radius));

ShapeBorder appShapeTop(double radius) => ContinuousRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    );

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.stravaOrange,
      secondary: AppColors.stravaOrange,
      surface: AppColors.cardBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.06),
      elevation: 0,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardBackground,
      shape: appShape(28),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.cardBackground,
      shape: appShapeTop(32),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.stravaOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.stravaOrange,
          width: 1.5,
        ),
      ),
      labelStyle: const TextStyle(color: AppColors.subtleGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      selectedItemColor: AppColors.stravaOrange,
      unselectedItemColor: AppColors.subtleGrey,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 0,
    ),
    scaffoldBackgroundColor: Colors.transparent,
  );
}
