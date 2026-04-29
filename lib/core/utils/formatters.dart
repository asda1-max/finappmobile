import 'package:intl/intl.dart';

/// Formatting utilities for financial data display.
class Formatters {
  Formatters._();

  static final _currencyIDR = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _percentFormat = NumberFormat('0.##');
  static final _scoreFormat = NumberFormat('0.000');
  static final _ratioFormat = NumberFormat('0.##');

  /// Format price in IDR: Rp 9,850
  static String price(double value) {
    if (value == 0) return '-';
    return _currencyIDR.format(value);
  }

  /// Format large numbers compactly: 1.2T, 345B
  static String compact(double value) {
    if (value == 0) return '-';
    if (value.abs() >= 1e12) {
      return '${_ratioFormat.format(value / 1e12)}T';
    }
    if (value.abs() >= 1e9) {
      return '${_ratioFormat.format(value / 1e9)}B';
    }
    if (value.abs() >= 1e6) {
      return '${_ratioFormat.format(value / 1e6)}M';
    }
    return value.toStringAsFixed(0);
  }

  /// Format percentage: 12.34%
  static String percent(double? value) {
    if (value == null) return '-';
    return '${_percentFormat.format(value)}%';
  }

  /// Format a score (0..1): 0.523
  static String score(double? value) {
    if (value == null) return '-';
    return _scoreFormat.format(value);
  }

  /// Format a ratio: 2.34x
  static String ratio(double? value) {
    if (value == null || value == 0) return '-';
    return '${_ratioFormat.format(value)}x';
  }

  /// Format a change with sign: +12.34% or -5.67%
  static String signedPercent(double? value) {
    if (value == null) return '-';
    final sign = value > 0 ? '+' : '';
    return '$sign${_percentFormat.format(value)}%';
  }

  /// Format a down/drop value with arrow: ▼ 3.2%
  static String dropPercent(double value) {
    if (value > 0) return '▼ ${_percentFormat.format(value)}%';
    if (value < 0) return '▲ ${_percentFormat.format(value.abs())}%';
    return '— 0%';
  }
}
