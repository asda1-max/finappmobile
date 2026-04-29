/// Data model for a single stock's complete fundamental and decision data.
///
/// Maps directly to the JSON response from the FastAPI /stocks endpoint.
class StockData {
  final String ticker;
  final String name;
  final String sector;
  final String industry;
  final double price;
  final double revenueAnnual;
  final double epsNow;
  final double perNow;
  final double high52;
  final double low52;
  final double shares;
  final double marketCap;
  final double downFromHigh;
  final double downFromMonth;
  final double downFromWeek;
  final double downFromToday;
  final double riseFromLow;
  final double bvpPerShare;
  final double roe;
  final double grahamNumber;
  final double mos;
  final double freeCashflow;
  final double pbv;
  final double? pbvMean3Y;
  final double? mosGraham;
  final double? mosPbv;
  final double? netProfitMargin;
  final double? debtToEquity;
  final double? currentRatio;
  final double qualityScore;
  final String qualityLabel;
  final double? dividendYield;
  final double? dividendGrowth;
  final double? payoutRatio;
  final double? autoCagrNetIncome;
  final double? autoCagrRevenue;
  final double? autoCagrEps;
  final String decisionBuy;
  final String decisionDiscount;
  final double discountScore;
  final String decisionDividend;
  final bool isRateLimited;

  // Hybrid decision fields
  final double? hybridScore;
  final String? hybridCategory;
  final String? baseDecisionBuy;
  final double? baseHybridScore;
  final String? baseHybridCategory;
  final String? finalDecisionBuy;
  final double? finalHybridScore;
  final String? finalHybridCategory;
  final double? absoluteHybridScore;
  final String? executionDecision;
  final String? safetyCheck;
  final String? qualityVerdict;
  final String? discountTimingVerdict;

  // CAGR tracking
  final bool? cagrApplied;
  final String? cagrSource;
  final double? cagrNetIncomeUsed;
  final double? cagrRevenueUsed;
  final double? cagrEpsUsed;

  const StockData({
    required this.ticker,
    required this.name,
    required this.sector,
    required this.industry,
    required this.price,
    required this.revenueAnnual,
    required this.epsNow,
    required this.perNow,
    required this.high52,
    required this.low52,
    required this.shares,
    required this.marketCap,
    required this.downFromHigh,
    required this.downFromMonth,
    required this.downFromWeek,
    required this.downFromToday,
    required this.riseFromLow,
    required this.bvpPerShare,
    required this.roe,
    required this.grahamNumber,
    required this.mos,
    required this.freeCashflow,
    required this.pbv,
    this.pbvMean3Y,
    this.mosGraham,
    this.mosPbv,
    this.netProfitMargin,
    this.debtToEquity,
    this.currentRatio,
    required this.qualityScore,
    required this.qualityLabel,
    this.dividendYield,
    this.dividendGrowth,
    this.payoutRatio,
    this.autoCagrNetIncome,
    this.autoCagrRevenue,
    this.autoCagrEps,
    required this.decisionBuy,
    required this.decisionDiscount,
    required this.discountScore,
    required this.decisionDividend,
    required this.isRateLimited,
    this.hybridScore,
    this.hybridCategory,
    this.baseDecisionBuy,
    this.baseHybridScore,
    this.baseHybridCategory,
    this.finalDecisionBuy,
    this.finalHybridScore,
    this.finalHybridCategory,
    this.absoluteHybridScore,
    this.executionDecision,
    this.safetyCheck,
    this.qualityVerdict,
    this.discountTimingVerdict,
    this.cagrApplied,
    this.cagrSource,
    this.cagrNetIncomeUsed,
    this.cagrRevenueUsed,
    this.cagrEpsUsed,
  });

  /// The effective decision (highest priority)
  String get effectiveDecision =>
      executionDecision ?? finalDecisionBuy ?? baseDecisionBuy ?? decisionBuy;

  /// The effective hybrid score
  double get effectiveHybridScore =>
      finalHybridScore ?? baseHybridScore ?? hybridScore ?? 0.0;

    /// Display score aligned with base (no-CAGR) score when available
    double get displayHybridScore =>
        absoluteHybridScore ?? baseHybridScore ?? hybridScore ?? finalHybridScore ?? 0.0;

  /// The effective hybrid category
  String get effectiveCategory =>
      finalHybridCategory ??
      baseHybridCategory ??
      hybridCategory ??
      "Don't Buy";

  /// Dividend yield as a percentage (normalized)
  double get dividendYieldPercent {
    final dy = dividendYield ?? 0.0;
    // yfinance sometimes returns as ratio (0.05 = 5%)
    return (dy > 0 && dy < 1) ? dy * 100 : dy;
  }

  factory StockData.fromJson(Map<String, dynamic> json) {
    return StockData(
      ticker: json['Ticker'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      sector: json['Sector'] as String? ?? '-',
      industry: json['Industry'] as String? ?? '-',
      price: _toDouble(json['Price']),
      revenueAnnual: _toDouble(json['Revenue Annual (Prev)']),
      epsNow: _toDouble(json['EPS NOW']),
      perNow: _toDouble(json['PER NOW']),
      high52: _toDouble(json['HIGH 52']),
      low52: _toDouble(json['LOW 52']),
      shares: _toDouble(json['Shares']),
      marketCap: _toDouble(json['Market Cap']),
      downFromHigh: _toDouble(json['Down From High 52 (%)']),
      downFromMonth: _toDouble(json['Down From This Month (%)']),
      downFromWeek: _toDouble(json['Down From This Week (%)']),
      downFromToday: _toDouble(json['Down From Today (%)']),
      riseFromLow: _toDouble(json['Rise From Low 52 (%)']),
      bvpPerShare: _toDouble(json['BVP Per S']),
      roe: _toDouble(json['ROE (%)']),
      grahamNumber: _toDouble(json['Graham Number']),
      mos: _toDouble(json['MOS (%)']),
      freeCashflow: _toDouble(json['Free Cashflow']),
      pbv: _toDouble(json['PBV']),
      pbvMean3Y: _toDoubleOrNull(json['PBV Mean 3Y']),
      mosGraham: _toDoubleOrNull(json['MOS Graham (%)']),
      mosPbv: _toDoubleOrNull(json['MOS PBV (%)']),
      netProfitMargin: _toDoubleOrNull(json['Net Profit Margin (%)']),
      debtToEquity: _toDoubleOrNull(json['Debt To Equity (%)']),
      currentRatio: _toDoubleOrNull(json['Current Ratio']),
      qualityScore: _toDouble(json['Quality Score']),
      qualityLabel: json['Quality Label'] as String? ?? '-',
      dividendYield: _toDoubleOrNull(json['Dividend Yield (%)']),
      dividendGrowth: _toDoubleOrNull(json['Dividend Growth (%)']),
      payoutRatio: _toDoubleOrNull(json['Payout Ratio (%)']),
      autoCagrNetIncome: _toDoubleOrNull(json['Auto CAGR Net Income (%)']),
      autoCagrRevenue: _toDoubleOrNull(json['Auto CAGR Revenue (%)']),
      autoCagrEps: _toDoubleOrNull(json['Auto CAGR EPS (%)']),
      decisionBuy: json['Decision Buy'] as String? ?? 'NO BUY',
      decisionDiscount: json['Decision Discount'] as String? ?? '-',
      discountScore: _toDouble(json['Discount Score']),
      decisionDividend: json['Decision Dividend'] as String? ?? '-',
      isRateLimited: json['Is Rate Limited'] as bool? ?? false,
      hybridScore: _toDoubleOrNull(json['Hybrid Score']),
      hybridCategory: json['Hybrid Category'] as String?,
      baseDecisionBuy: json['Base Decision Buy'] as String?,
      baseHybridScore: _toDoubleOrNull(json['Base Hybrid Score']),
      baseHybridCategory: json['Base Hybrid Category'] as String?,
      finalDecisionBuy: json['Final Decision Buy'] as String?,
      finalHybridScore: _toDoubleOrNull(json['Final Hybrid Score']),
      finalHybridCategory: json['Final Hybrid Category'] as String?,
      absoluteHybridScore: _toDoubleOrNull(json['Absolute Hybrid Score']),
      executionDecision: json['Execution Decision'] as String?,
      safetyCheck: json['Safety Check'] as String?,
      qualityVerdict: json['Quality Verdict'] as String?,
      discountTimingVerdict: json['Discount Timing Verdict'] as String?,
      cagrApplied: json['CAGR Applied'] as bool?,
      cagrSource: json['CAGR Source'] as String?,
      cagrNetIncomeUsed: _toDoubleOrNull(json['CAGR Net Income Used (%)']),
      cagrRevenueUsed: _toDoubleOrNull(json['CAGR Revenue Used (%)']),
      cagrEpsUsed: _toDoubleOrNull(json['CAGR EPS Used (%)']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v.isNaN || v.isInfinite ? 0.0 : v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v.isNaN || v.isInfinite ? null : v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
