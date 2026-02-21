import 'package:flutter/material.dart';

/// Finora app color palette
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFE5F7FC);
  static const Color primary = Color(0xFF1F4689);
  static const Color widgetBackground = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF000000);
  static const Color secondary = Color(0xFF5170A6);

  // Convenience shades for borders, highlights, etc.
  static Color get secondaryLight => secondary.withOpacity(0.3);
  static Color get primaryLight => primary.withOpacity(0.12);
  static Color get primaryVeryLight => primary.withOpacity(0.06);
  static Color get border => secondary.withOpacity(0.4);
  static Color get textMuted => text.withOpacity(0.6);
}
