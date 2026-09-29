import 'package:flutter/material.dart';

/// Premium modern color palette for RouteSafe with Royal Blue & School Bus Yellow accent.
class AppColors {
  // Primary Royal Blue Palette
  static const Color primary = Color(0xFF1E40AF); // Deep Royal Blue
  static const Color primaryDark = Color(0xFF1E3A8A); // Slate Indigo Navy
  static const Color primaryLight = Color(0xFFEFF6FF); // Soft Blue Tint
  static const Color skyBlue = Color(0xFF0284C7); // Electric Sky Cyan

  // Yellow & Gold Accents (School Bus Theme)
  static const Color accentYellow = Color(0xFFF59E0B); // Warm School Bus Yellow / Amber
  static const Color yellowLight = Color(0xFFFFFBEB); // Soft Yellow Tint
  static const Color accentGold = Color(0xFFFBBF24); // Electric Gold

  // Secondary & Accents
  static const Color accent = Color(0xFFF59E0B); // Yellow accent
  static const Color accentLight = Color(0xFFFFFBEB);

  // Status Indicators
  static const Color success = Color(0xFF059669); // Emerald Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706); // Amber Gold
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626); // Crimson Red
  static const Color dangerLight = Color(0xFFFEF2F2);

  // Surface & Neutrals
  static const Color background = Color(0xFFF8FAFC); // Clean Slate Background
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
}

extension ColorWithAlpha on Color {
  Color withOpacityCompat(double opacity) {
    return withAlpha((opacity * 255).clamp(0, 255).round());
  }
}