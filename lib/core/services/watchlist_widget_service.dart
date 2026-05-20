import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/stock_data.dart';
import '../utils/formatters.dart';

class WatchlistWidgetService {
  WatchlistWidgetService._();

  static const MethodChannel _channel = MethodChannel('watchlist_widget');

  static Future<void> updateFromStocks(List<StockData> stocks) async {
    final top = <Map<String, String>>[];
    if (stocks.isNotEmpty) {
      final sorted = List<StockData>.from(stocks)
        ..sort((a, b) => b.displayHybridScore.compareTo(a.displayHybridScore));
      top.addAll(sorted.take(3).map((stock) {
        final change = -stock.downFromToday;
        final changeText = _signedPercent(change);
        final rangeText = '${Formatters.price(stock.low52, ticker: stock.ticker)} - '
            '${Formatters.price(stock.high52, ticker: stock.ticker)}';
        return {
          'ticker': stock.ticker,
          'price': Formatters.price(stock.price, ticker: stock.ticker),
          'score': Formatters.score(stock.displayHybridScore),
          'decision': stock.effectiveDecision,
          'change': changeText,
          'sector': stock.sector,
          'range': rangeText,
        };
      }));
    }

    final payload = jsonEncode(top);
    try {
      await _channel.invokeMethod('setWatchlistData', payload);
    } catch (_) {
      // ignore widget update errors
    }
  }

  static Future<String?> consumeOpenTarget() async {
    try {
      final target = await _channel.invokeMethod<String>('consumeOpenTarget');
      return target;
    } catch (_) {
      return null;
    }
  }

  static String _signedPercent(double value) {
    final sign = value > 0 ? '+' : value < 0 ? '-' : '';
    final abs = value.abs();
    return '$sign${abs.toStringAsFixed(2)}%';
  }
}
