import 'package:flutter/material.dart';

/// ✅ UI/UX Improvement: Centralized color constants for theme consistency
/// All app colors defined in one place
class AppColors {
  // Primary colors
  static const primary = Color(0xFF4facfe);
  static const primaryDark = Color(0xFF00f2fe);
  static const secondary = Color(0xFF667eea);
  static const accent = Color(0xFF764ba2);

  // Background colors
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F3F4);

  // Semantic colors
  static const error = Color(0xFFE74C3C);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF39C12);
  static const info = Color(0xFF3498DB);

  // Budget status colors
  static const budgetGood = Color(0xFF2ECC71);
  static const budgetWarning = Color(0xFFF39C12);
  static const budgetOver = Color(0xFFE74C3C);

  // Text colors
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  // Border colors
  static const borderLight = Color(0xFFE1E5E9);
  static const borderMedium = Color(0xFFD1D5DB);

  // Bottom navigation
  static const primaryDarkBlue = Color(0xFF16213e);
  static const bottomNavBackground = Color(0xFF16213e);
  static const bottomNavSelected = primaryDarkBlue;
  static const bottomNavUnselected = Color(0xFF9CA3AF);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Helper methods
  static Color getBudgetColor(double percentage) {
    if (percentage < 70) return budgetGood;
    if (percentage < 100) return budgetWarning;
    return budgetOver;
  }

  static String getBudgetStatusText(double percentage) {
    if (percentage < 70) return 'On track';
    if (percentage < 100) return 'Watch spending';
    return 'Over budget';
  }

  static IconData getBudgetStatusIcon(double percentage) {
    if (percentage < 70) return Icons.check_circle;
    if (percentage < 100) return Icons.warning;
    return Icons.error;
  }
}

