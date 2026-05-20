import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

class StockPriceChart extends StatelessWidget {
  final List<String> dates;
  final List<double> closePrices;
  final String? ticker;

  const StockPriceChart({
    super.key,
    required this.dates,
    required this.closePrices,
    this.ticker,
  });

  @override
  Widget build(BuildContext context) {
    if (closePrices.isEmpty || dates.isEmpty) {
      return const Center(child: Text('No chart data available'));
    }

    final double startPrice = closePrices.first;
    final double endPrice = closePrices.last;
    final bool isUp = endPrice >= startPrice;
    final Color chartColor = isUp ? AppColors.buyGreen : AppColors.sellRed;

    double minPrice = closePrices.reduce((a, b) => a < b ? a : b);
    double maxPrice = closePrices.reduce((a, b) => a > b ? a : b);
    final double padding = (maxPrice - minPrice) * 0.1;
    minPrice -= padding;
    maxPrice += padding;

    final spots = List.generate(closePrices.length, (index) {
      return FlSpot(index.toDouble(), closePrices[index]);
    });

    final hasTime = dates.any((d) => d.contains(':'));
    final xInterval = _xInterval(spots.length);
    final yInterval = _yInterval(minPrice, maxPrice);

    return AspectRatio(
      aspectRatio: 1.70,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.card,
                        strokeWidth: 2,
                        strokeColor: chartColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.card,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.spotIndex;
                  final dateLabel = _tooltipDateLabel(dates, index, hasTime);
                  final change = _deltaPercent(closePrices, index);
                  final changeText = change == null
                      ? ''
                      : ' • ${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%';
                  return LineTooltipItem(
                    '${Formatters.price(spot.y, ticker: ticker)}\n$dateLabel$changeText',
                    TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 72,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 64,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          Formatters.price(value, ticker: ticker),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: xInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _axisDateLabel(dates[index], hasTime),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (closePrices.length - 1).toDouble(),
          minY: minPrice,
          maxY: maxPrice,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: chartColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    chartColor.withOpacity(0.3),
                    chartColor.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _xInterval(int length) {
    if (length <= 4) return 1;
    final step = (length / 4).floor();
    return step <= 0 ? 1 : step.toDouble();
  }

  double _yInterval(double minPrice, double maxPrice) {
    final range = (maxPrice - minPrice).abs();
    if (range == 0) return 1;
    return range / 4;
  }

  String _axisDateLabel(String raw, bool hasTime) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return hasTime ? DateFormat('HH:mm').format(parsed) : DateFormat('d MMM').format(parsed);
  }

  String _tooltipDateLabel(List<String> values, int index, bool hasTime) {
    if (index < 0 || index >= values.length) return '';
    final parsed = DateTime.tryParse(values[index]);
    if (parsed == null) return values[index];
    return hasTime ? DateFormat('d MMM yyyy, HH:mm').format(parsed) : DateFormat('d MMM yyyy').format(parsed);
  }

  double? _deltaPercent(List<double> values, int index) {
    if (index <= 0 || index >= values.length) return null;
    final prev = values[index - 1];
    if (prev == 0) return null;
    return ((values[index] - prev) / prev) * 100;
  }
}
