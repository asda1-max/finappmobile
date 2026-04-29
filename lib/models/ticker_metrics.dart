class TickerMetrics {
  final String symbol;
  final double? currentPrice;
  final double? eps;
  final double? pe;
  final double? high52;
  final double? low52;
  final double? bvps;
  final double? roe;
  final double? grahamNumber;
  final double? marginOfSafety;
  final double? pbv;
  final double? dividendYield;
  final double? dividendRate;
  final double? dividendPayoutRatio;
  final double? dividendGrowth;
  final double? cagrRevenue;
  final double? cagrNetIncome;
  final double? cagrEps;
  final double? dropDay;
  final double? dropWeek;
  final double? dropMonth;

  const TickerMetrics({
    required this.symbol,
    required this.currentPrice,
    required this.eps,
    required this.pe,
    required this.high52,
    required this.low52,
    required this.bvps,
    required this.roe,
    required this.grahamNumber,
    required this.marginOfSafety,
    required this.pbv,
    required this.dividendYield,
    required this.dividendRate,
    required this.dividendPayoutRatio,
    required this.dividendGrowth,
    required this.cagrRevenue,
    required this.cagrNetIncome,
    required this.cagrEps,
    required this.dropDay,
    required this.dropWeek,
    required this.dropMonth,
  });
}
