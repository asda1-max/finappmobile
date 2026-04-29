import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/ticker_metrics.dart';

/// When running as a Flutter web app the browser blocks direct calls to Yahoo
/// Finance due to CORS.  Route those requests through the local proxy server
/// (proxy/server.js, listening on port 8080) which forwards them server-side.
/// On native targets (Android / iOS / Desktop) we call Yahoo directly.
Uri _yahooUri(String path) {
  if (kIsWeb) {
    // Local CORS proxy: http://localhost:8080/<path>
    return Uri.http('localhost:8080', path);
  }
  return Uri.https('query1.finance.yahoo.com', path);
}

class YahooFinanceService {
  YahooFinanceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  Future<TickerMetrics> fetchMetrics(String symbol) async {
    final quoteUri = _yahooUri(
      '/v10/finance/quoteSummary/$symbol',
    ).replace(queryParameters: {
      'modules':
          'price,summaryDetail,defaultKeyStatistics,financialData,earnings,incomeStatementHistory',
    });

    final chartUri = _yahooUri('/v8/finance/chart/$symbol').replace(
      queryParameters: {
        'range': '1mo',
        'interval': '1d',
        'includePrePost': 'false',
      },
    );

    final responses = await Future.wait([
      _get(quoteUri),
      _get(chartUri),
    ]);

    final quoteResponse = responses[0];
    final chartResponse = responses[1];

    if (quoteResponse.statusCode != 200) {
      throw Exception(
        'Yahoo Finance quoteSummary failed for $symbol (HTTP ${quoteResponse.statusCode})',
      );
    }
    if (chartResponse.statusCode != 200) {
      throw Exception(
        'Yahoo Finance chart failed for $symbol (HTTP ${chartResponse.statusCode})',
      );
    }

    final quoteJson = jsonDecode(quoteResponse.body) as Map<String, dynamic>;
    final chartJson = jsonDecode(chartResponse.body) as Map<String, dynamic>;

    final result = _firstResult(quoteJson, ['quoteSummary', 'result']);
    if (result == null) {
      throw Exception('No data found for $symbol');
    }

    final price = result['price'] as Map<String, dynamic>?;
    final summary = result['summaryDetail'] as Map<String, dynamic>?;
    final stats = result['defaultKeyStatistics'] as Map<String, dynamic>?;
    final financial = result['financialData'] as Map<String, dynamic>?;
    final earnings = result['earnings'] as Map<String, dynamic>?;
    final incomeHistory = result['incomeStatementHistory'] as Map<String, dynamic>?;

    final currentPrice = _raw(price?['regularMarketPrice']);
    final eps = _raw(stats?['trailingEps']);
    final pe = _raw(summary?['trailingPE']);
    final high52 = _raw(summary?['fiftyTwoWeekHigh']);
    final low52 = _raw(summary?['fiftyTwoWeekLow']);
    final bvps = _raw(stats?['bookValue']);
    final roe = _raw(financial?['returnOnEquity']);
    final pbv = _raw(stats?['priceToBook']);
    final dividendYield = _raw(summary?['dividendYield']);
    final dividendRate = _raw(summary?['dividendRate']);
    final payoutRatio = _raw(summary?['payoutRatio']);
    final trailingDividendRate = _raw(stats?['trailingAnnualDividendRate']);

    final cagrRevenue = _calcCagrFromIncomeHistory(incomeHistory, 'totalRevenue');
    final cagrNetIncome = _calcCagrFromIncomeHistory(incomeHistory, 'netIncome');
    final cagrEps = _calcCagrFromEarnings(earnings);

    final dividendGrowth = _calcDividendGrowth(dividendRate, trailingDividendRate);

    final grahamNumber = _calcGrahamNumber(eps, bvps);
    final marginOfSafety = _calcMarginOfSafety(currentPrice, grahamNumber);

    final dropMetrics = _extractPriceDrops(chartJson);

    return TickerMetrics(
      symbol: symbol,
      currentPrice: currentPrice,
      eps: eps,
      pe: pe,
      high52: high52,
      low52: low52,
      bvps: bvps,
      roe: roe == null ? null : roe * 100,
      grahamNumber: grahamNumber,
      marginOfSafety: marginOfSafety,
      pbv: pbv,
      dividendYield: dividendYield,
      dividendRate: dividendRate,
      dividendPayoutRatio: payoutRatio,
      dividendGrowth: dividendGrowth,
      cagrRevenue: cagrRevenue,
      cagrNetIncome: cagrNetIncome,
      cagrEps: cagrEps,
      dropDay: dropMetrics['day'],
      dropWeek: dropMetrics['week'],
      dropMonth: dropMetrics['month'],
    );
  }

  Map<String, dynamic>? _firstResult(Map<String, dynamic> json, List<String> path) {
    dynamic cursor = json;
    for (final key in path) {
      if (cursor is Map<String, dynamic> && cursor.containsKey(key)) {
        cursor = cursor[key];
      } else {
        return null;
      }
    }
    if (cursor is List && cursor.isNotEmpty && cursor.first is Map<String, dynamic>) {
      return cursor.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<http.Response> _get(Uri uri) async {
    return _client.get(uri, headers: _headers).timeout(_requestTimeout);
  }

  double? _raw(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is Map<String, dynamic>) {
      final raw = value['raw'];
      if (raw is num) return raw.toDouble();
    }
    return null;
  }

  double? _calcDividendGrowth(double? dividendRate, double? trailingDividendRate) {
    if (dividendRate == null || trailingDividendRate == null || trailingDividendRate == 0) {
      return null;
    }
    return ((dividendRate - trailingDividendRate) / trailingDividendRate) * 100;
  }

  double? _calcGrahamNumber(double? eps, double? bvps) {
    if (eps == null || bvps == null || eps <= 0 || bvps <= 0) return null;
    return sqrt(22.5 * eps * bvps);
  }

  double? _calcMarginOfSafety(double? price, double? grahamNumber) {
    if (price == null || grahamNumber == null || price <= 0) return null;
    return ((grahamNumber - price) / price) * 100;
  }

  double? _calcCagrFromIncomeHistory(Map<String, dynamic>? history, String field) {
    final list = history?['incomeStatementHistory'];
    if (list is! List || list.length < 2) return null;

    final latest = _raw(list.first[field]);
    final oldest = _raw(list.last[field]);
    if (latest == null || oldest == null || latest <= 0 || oldest <= 0) return null;

    final years = list.length - 1;
    return (_cagr(oldest, latest, years) * 100);
  }

  double? _calcCagrFromEarnings(Map<String, dynamic>? earnings) {
    final list = earnings?['financialsChart']?['yearly'];
    if (list is! List || list.length < 2) return null;

    final latest = _raw(list.first['earnings'] ?? list.first['eps']);
    final oldest = _raw(list.last['earnings'] ?? list.last['eps']);
    if (latest == null || oldest == null || latest <= 0 || oldest <= 0) return null;

    final years = list.length - 1;
    return (_cagr(oldest, latest, years) * 100);
  }

  double _cagr(double start, double end, int years) {
    return pow(end / start, 1 / years) - 1;
  }

  Map<String, double?> _extractPriceDrops(Map<String, dynamic> chartJson) {
    final result = chartJson['chart']?['result'];
    if (result is! List || result.isEmpty) {
      return {'day': null, 'week': null, 'month': null};
    }

    final quote = result.first['indicators']?['quote'];
    if (quote is! List || quote.isEmpty) {
      return {'day': null, 'week': null, 'month': null};
    }

    final closesRaw = quote.first['close'];
    if (closesRaw is! List) {
      return {'day': null, 'week': null, 'month': null};
    }

    final closes = closesRaw.whereType<num>().map((e) => e.toDouble()).toList();
    if (closes.length < 2) {
      return {'day': null, 'week': null, 'month': null};
    }

    final last = closes.last;
    final prev = closes[closes.length - 2];
    final weekIndex = closes.length > 5 ? closes.length - 6 : null;
    final week = weekIndex == null ? null : closes[weekIndex];
    final month = closes.first;

    return {
      'day': _percentChange(last, prev),
      'week': week == null ? null : _percentChange(last, week),
      'month': _percentChange(last, month),
    };
  }

  double _percentChange(double latest, double base) {
    return ((latest - base) / base) * 100;
  }
}
