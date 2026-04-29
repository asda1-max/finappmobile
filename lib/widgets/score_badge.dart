import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A pill-shaped badge for decisions, quality labels, and categories.
class ScoreBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const ScoreBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 10,
    this.padding,
  });

  /// Convenience factory for buy/no buy decisions
  factory ScoreBadge.decision(String decision) {
    return ScoreBadge(
      label: decision.toUpperCase(),
      color: AppColors.decisionColor(decision),
      fontSize: 11,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  /// Convenience factory for hybrid category
  factory ScoreBadge.category(String category) {
    return ScoreBadge(
      label: category,
      color: AppColors.categoryColor(category),
    );
  }

  /// Convenience factory for quality label
  factory ScoreBadge.quality(String label) {
    return ScoreBadge(
      label: label,
      color: AppColors.qualityColor(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
