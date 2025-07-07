import 'package:flutter/material.dart';

/// AppColors defines the color palette for the CampusRide application.
/// This uses a pastel color scheme as the primary palette.
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFFBBDEFB);
  static const Color primaryDark = Color(0xFF1976D2);

  // Secondary Colors
  static const Color secondary = Color(0xFF03A9F4);
  static const Color secondaryLight = Color(0xFFB3E5FC);
  static const Color secondaryDark = Color(0xFF0288D1);

  // Accent Colors
  static const Color accentMint = Color(0xFFB2DFDB); // Pastel Mint
  static const Color accentPeach = Color(0xFFFFCCBC); // Pastel Peach
  static const Color accentLavender = Color(0xFFD1C4E9); // Pastel Lavender
  static const Color accentYellow = Color(0xFFFFF9C4); // Pastel Yellow

  // Neutral Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color card = Color(0xFFF8F9FB);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Status Colors
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFB00020);
  static const Color info = Color(0xFF1976D2);

  // Glassmorphism
  static const Color glassFill = Color(0x40FFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);

  // Gradients
  static const List<Color> primaryGradient = [
    primary,
    primaryDark,
  ];

  static const List<Color> secondaryGradient = [
    secondary,
    secondaryDark,
  ];

  static const List<Color> accentGradient = [
    accentMint,
    accentLavender,
  ];

  static const Color accent = Color(0xFF00BCD4);
  static const Color divider = Color(0xFFBDBDBD);
}
