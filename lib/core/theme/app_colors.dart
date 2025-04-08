import 'package:flutter/material.dart';

/// AppColors defines the color palette for the CampusRide application.
/// This uses a pastel color scheme as the primary palette.
class AppColors {
  // Primary Colors
  static const Color primaryLight = Color(0xFFBBDEFB); // Light Pastel Blue
  static const Color primary = Color(0xFF90CAF9);      // Pastel Blue
  static const Color primaryDark = Color(0xFF64B5F6);  // Medium Pastel Blue
  
  // Secondary Colors
  static const Color secondaryLight = Color(0xFFE1BEE7); // Light Pastel Purple
  static const Color secondary = Color(0xFFCE93D8);      // Pastel Purple
  static const Color secondaryDark = Color(0xFFBA68C8);  // Medium Pastel Purple
  
  // Accent Colors
  static const Color accentMint = Color(0xFFB2DFDB);     // Pastel Mint
  static const Color accentPeach = Color(0xFFFFCCBC);    // Pastel Peach
  static const Color accentLavender = Color(0xFFD1C4E9); // Pastel Lavender
  static const Color accentYellow = Color(0xFFFFF9C4);   // Pastel Yellow
  
  // Neutral Colors
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF8F9FB);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color textHint = Color(0xFF9E9E9E);
  
  // Status Colors
  static const Color success = Color(0xFFA5D6A7);
  static const Color warning = Color(0xFFFFE082);
  static const Color error = Color(0xFFEF9A9A);
  static const Color info = Color(0xFF81D4FA);
  
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
} 