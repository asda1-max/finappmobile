import 'package:flutter/material.dart';

/// Premium dark color palette for Tick Watchers.
class AppColors {
  AppColors._();

  // ── Base background & surface ──
  static const Color background = Color(0xFF1A1814);
  static const Color surface = Color(0xFF231F1B);
  static const Color surfaceLight = Color(0xFF2E2924);
  static const Color card = Color(0xFF2A2520);
  static const Color cardBorder = Color(0xFF3A342E);

  // ── Primary accent ──
  static const Color primary = Color(0xFFD4A843);
  static const Color primaryLight = Color(0xFFE5C173);
  static const Color primaryDark = Color(0xFFA67C22);

  // ── Secondary accent ──
  static const Color accent = Color(0xFFC17D3E);
  static const Color accentLight = Color(0xFFD99B62);

  // ── Decision colors ──
  static const Color buyGreen = Color(0xFF5B9A6F);
  static const Color buyGreenLight = Color(0xFF7CB88F);
  static const Color buyGreenBg = Color(0xFF1E3125);

  static const Color sellRed = Color(0xFFC45B4A);
  static const Color sellRedLight = Color(0xFFDF7A6B);
  static const Color sellRedBg = Color(0xFF3D1C17);

  static const Color holdAmber = Color(0xFFB8863B);
  static const Color holdAmberLight = Color(0xFFD4A45A);
  static const Color holdAmberBg = Color(0xFF382912);

  static const Color riskOrange = Color(0xFFC45B4A);

  // ── Quality labels ──
  static const Color qualityPremium = Color(0xFFD4A843);
  static const Color qualitySolid = Color(0xFFB8863B);
  static const Color qualityStandard = Color(0xFFA89880);
  static const Color qualityWeak = Color(0xFFC45B4A);

  // ── Text ──
  static const Color textPrimary = Color(0xFFE8DFD0);
  static const Color textSecondary = Color(0xFFA89880);
  static const Color textTertiary = Color(0xFF8C7E6A);
  static const Color textMuted = Color(0xFF6B6052);

  // ── Gradient presets ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD4A843), Color(0xFFC17D3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buyGradient = LinearGradient(
    colors: [Color(0xFF5B9A6F), Color(0xFF4A825C)],
  );

  static const LinearGradient sellGradient = LinearGradient(
    colors: [Color(0xFFC45B4A), Color(0xFFA8483A)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF2A2520), Color(0xFF231F1B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glassmorphism (Retro version) ──
  static Color glassWhite = const Color(0xFFE8DFD0).withValues(alpha: 0.05);
  static Color glassBorder = const Color(0xFFE8DFD0).withValues(alpha: 0.08);

  /// Get color for a decision string
  static Color decisionColor(String decision) {
    switch (decision.toUpperCase()) {
      case 'BUY':
        return buyGreen;
      case 'NO BUY':
        return sellRed;
      case 'HOLD':
        return holdAmber;
      default:
        return textSecondary;
    }
  }

  /// Get color for a hybrid category
  static Color categoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('recommended')) return buyGreen;
    if (lower == 'buy') return buyGreenLight;
    if (lower.contains('risk')) return holdAmber;
    return sellRed;
  }

  /// Get color for quality label
  static Color qualityColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('premium')) return qualityPremium;
    if (lower.contains('solid')) return qualitySolid;
    if (lower.contains('standard')) return qualityStandard;
    return qualityWeak;
  }

  /// Get color for a score value (0..1)
  static Color scoreColor(double score) {
    if (score >= 0.7) return buyGreen;
    if (score >= 0.5) return buyGreenLight;
    if (score >= 0.35) return holdAmber;
    if (score >= 0.2) return riskOrange;
    return sellRed;
  }
}
