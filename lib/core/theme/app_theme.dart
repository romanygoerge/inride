import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary (White)
  static const Color primary = Colors.white;
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;

  // Secondary Gradient Blues
  static const Color lightBlue = Color(0xFF42A5F5); // أزرق فاتح
  static const Color mediumBlue = Color(0xFF1E88E5); // أزرق متوسط
  static const Color darkBlue = Color(0xFF0D47A1); // أزرق غامق
  static const Color accentBlue = Color(0xFF2979FF); // أزرق مميز

  // Blue Gradient List (From Light to Dark)
  static const List<Color> blueGradient = [
    Color(0xFF2196F3),
    Color(0xFF1976D2),
    Color(0xFF0D47A1),
  ];

  static const List<Color> lightBlueGradient = [
    Color(0xFF64B5F6),
    Color(0xFF1E88E5),
  ];

  // Neutral colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

class AppTheme {
  static ButtonStyle elevatedButtonStyleFrom({
    required double elevation,
    required EdgeInsets padding,
    required RoundedRectangleBorder shape,
    required TextStyle textStyle,
  }) {
    return ElevatedButton.styleFrom(
      elevation: elevation,
      padding: padding,
      shape: shape,
      textStyle: textStyle,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.mediumBlue,
        secondary: AppColors.darkBlue,
        surface: AppColors.cardBackground,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        centerTitle: true,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shadowColor: AppColors.textLight.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.mediumBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mediumBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.cairo(color: AppColors.textLight, fontSize: 14),
      ),
    );
  }
}
