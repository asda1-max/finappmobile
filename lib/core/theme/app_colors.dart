import 'package:flutter/material.dart';

/// Premium dark color palette for Tick Watchers.
class AppColors {
  AppColors._();

  // ── Base background & surface ──
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFF1E293B);
  static const Color card = Color(0xFF151C2E);
  static const Color cardBorder = Color(0xFF1E2A45);

  // ── Primary accent ──
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // ── Secondary accent ──
  static const Color accent = Color(0xFF0EA5E9);
  static const Color accentLight = Color(0xFF38BDF8);

  // ── Decision colors ──
  static const Color buyGreen = Color(0xFF22C55E);
  static const Color buyGreenLight = Color(0xFF4ADE80);
  static const Color buyGreenBg = Color(0xFF052E16);

  static const Color sellRed = Color(0xFFEF4444);
  static const Color sellRedLight = Color(0xFFF87171);
  static const Color sellRedBg = Color(0xFF450A0A);

  static const Color holdAmber = Color(0xFFF59E0B);
  static const Color holdAmberLight = Color(0xFFFBBF24);
  static const Color holdAmberBg = Color(0xFF451A03);

  static const Color riskOrange = Color(0xFFF97316);

  // ── Quality labels ──
  static const Color qualityPremium = Color(0xFFEAB308);
  static const Color qualitySolid = Color(0xFF3B82F6);
  static const Color qualityStandard = Color(0xFF94A3B8);
  static const Color qualityWeak = Color(0xFFEF4444);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF475569);

  // ── Gradient presets ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buyGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF10B981)],
  );

  static const LinearGradient sellGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF151C2E), Color(0xFF0F1624)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glassmorphism ──
  static Color glassWhite = Colors.white.withValues(alpha: 0.05);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);

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
