import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/stock_data.dart';

/// Repository handling all stock-related API calls to the FastAPI backend.
class StockRepository {
  final Dio _dio = ApiClient.instance;

  /// Fetch fundamental data for multiple tickers.
  /// Returns a list of [StockData] parsed from the backend response.
  Future<List<StockData>> fetchStocks(List<String> tickers) async {
    if (tickers.isEmpty) return [];

    final tickerParam = tickers.join(',');
    final response = await _dio.get(
      ApiConstants.stocks,
      queryParameters: {'tickers': tickerParam},
    );

    final data = response.data as List<dynamic>;
    return data
        .map((json) => StockData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch data for a single ticker.
  Future<StockData?> fetchSingleStock(String ticker) async {
    if (ticker.isEmpty) return null;
    final results = await fetchStocks([ticker]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get list of saved tickers from the backend.
  Future<List<String>> getSavedTickers() async {
    final response = await _dio.get(ApiConstants.savedTickers);
    final data = response.data as Map<String, dynamic>;
    final tickers = data['tickers'] as List<dynamic>? ?? [];
    return tickers.map((t) => t.toString()).toList();
  }

  /// Add a ticker to saved list.
  Future<List<String>> addTicker(String ticker) async {
    final response = await _dio.post(
      ApiConstants.savedTickers,
      data: {'ticker': ticker.trim()},
    );
    final data = response.data as Map<String, dynamic>;
    final tickers = data['tickers'] as List<dynamic>? ?? [];
    return tickers.map((t) => t.toString()).toList();
  }

  /// Delete a ticker from saved list and CAGR data.
  Future<bool> deleteTicker(String ticker) async {
    final response = await _dio.delete(ApiConstants.deleteEntry(ticker));
    final data = response.data as Map<String, dynamic>;
    return data['deleted'] as bool? ?? false;
  }

  /// Reset all saved data (requires confirmation).
  Future<void> resetAll() async {
    await _dio.post(
      ApiConstants.resetAll,
      data: {'confirmation': 'yes, i want to reset'},
    );
  }

  /// Trigger auto CAGR decision for a list of tickers.
  Future<Map<String, dynamic>> triggerAutoDecision(
      List<String> tickers) async {
    final items = tickers.map((t) => {'ticker': t.trim()}).toList();
    final response = await _dio.post(
      ApiConstants.decisionCagrAuto,
      data: {'items': items},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch price history for a ticker.
  Future<Map<String, dynamic>> fetchPriceHistory(
    String ticker, {
    String period = '1y',
    String interval = '1wk',
  }) async {
    final response = await _dio.get(
      ApiConstants.priceHistory,
      queryParameters: {
        'ticker': ticker,
        'period': period,
        'interval': interval,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch performance overview (YTD/1Y/3Y/5Y returns vs benchmark).
  Future<Map<String, dynamic>> fetchPerformanceOverview(
    String ticker, {
    String benchmark = '^JKSE',
  }) async {
    final response = await _dio.get(
      ApiConstants.performanceOverview,
      queryParameters: {
        'ticker': ticker,
        'benchmark': benchmark,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch hybrid weight configuration from backend.
  Future<Map<String, dynamic>> fetchHybridConfig() async {
    final response = await _dio.get(ApiConstants.hybridConfig);
    return response.data as Map<String, dynamic>;
  }

  /// Save hybrid weight configuration to backend.
  Future<void> saveHybridConfig({
    required List<double> useCagrWeights,
    required double useCagrRec,
    required double useCagrBuy,
    required double useCagrRisk,
    required List<double> noCagrWeights,
    required double noCagrRec,
    required double noCagrBuy,
    required double noCagrRisk,
  }) async {
    await _dio.post(
      ApiConstants.hybridConfig,
      data: {
        'use_cagr': {
          'weights': useCagrWeights,
          'recommended': useCagrRec,
          'buy': useCagrBuy,
          'risk': useCagrRisk,
        },
        'no_cagr': {
          'weights': noCagrWeights,
          'recommended': noCagrRec,
          'buy': noCagrBuy,
          'risk': noCagrRisk,
        },
      },
    );
  }
}
