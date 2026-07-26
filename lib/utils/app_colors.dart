import 'package:flutter/material.dart';

/// Central color palette for RouteSafe.
///
/// Brand: deep blue (trust, safety) with a warm amber accent (school-bus
/// yellow) and clear status colors for trip states.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF1E4FD8); // main brand blue
  static const Color primaryDark = Color(0xFF15369E); // headers / gradients
  static const Color primaryLight = Color(0xFFE8EEFE); // tints, chips, icons

  static const Color accent = Color(0xFFFFB020); // school-bus amber

  // Status
  static const Color success = Color(0xFF19A974); // on-time / active / safe
  static const Color successLight = Color(0xFFE3F7EE);
  static const Color warning = Color(0xFFF59E0B); // delayed
  static const Color warningLight = Color(0xFFFEF3E2);
  static const Color danger = Color(0xFFE5484D); // emergency / stop
  static const Color dangerLight = Color(0xFFFCEAEA);

  // Neutrals
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE3E8F1);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
}
