import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for local Hive database — offline caching, preferences, search history.
class LocalDbService {
  static const _stockCacheBox = 'stockCache';
  static const _userPrefsBox = 'userPrefs';
  static const _searchHistoryBox = 'searchHistory';
  static const _savedTickersKey = 'saved_tickers';

  /// Initialize Hive — call once in main() before runApp().
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_stockCacheBox);
    await Hive.openBox(_userPrefsBox);
    await Hive.openBox<String>(_searchHistoryBox);
  }

  // ── Stock Cache ──

  /// Cache stock data as JSON. Stored with timestamp for expiry.
  static Future<void> cacheStocks(List<Map<String, dynamic>> stocksJson) async {
    final box = Hive.box(_stockCacheBox);
    await box.put('stocks_data', jsonEncode(stocksJson));
    await box.put('stocks_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached stocks. Returns null if cache is empty or expired (>1 hour).
  static List<Map<String, dynamic>>? getCachedStocks() {
    final box = Hive.box(_stockCacheBox);
    final timestamp = box.get('stocks_timestamp') as int?;
    if (timestamp == null) return null;

    // Cache expires after 1 hour
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 3600000) return null;

    final raw = box.get('stocks_data') as String?;
    if (raw == null) return null;

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Clear the stock cache.
  static Future<void> clearStockCache() async {
    final box = Hive.box(_stockCacheBox);
    await box.delete('stocks_data');
    await box.delete('stocks_timestamp');
  }

  // ── User Preferences ──

  /// Save a user preference.
  static Future<void> savePreference(String key, dynamic value) async {
    final box = Hive.box(_userPrefsBox);
    await box.put(key, value);
  }

  /// Get a user preference.
  static T? getPreference<T>(String key) {
    final box = Hive.box(_userPrefsBox);
    return box.get(key) as T?;
  }

  // ── Saved Tickers ──

  /// Save ticker list for quick access.
  static Future<void> saveTickers(List<String> tickers) async {
    final box = Hive.box(_userPrefsBox);
    await box.put(_savedTickersKey, tickers);
  }

  /// Get saved tickers (empty if none).
  static List<String> getSavedTickers() {
    final box = Hive.box(_userPrefsBox);
    final raw = box.get(_savedTickersKey);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  // ── Search History ──

  /// Add a ticker to search history (max 20 items, most recent first).
  static Future<void> addSearchHistory(String ticker) async {
    final box = Hive.box<String>(_searchHistoryBox);
    final existing = box.values.toList();
    existing.remove(ticker);
    existing.insert(0, ticker);
    if (existing.length > 20) existing.removeLast();
    await box.clear();
    for (final item in existing) {
      await box.add(item);
    }
  }

  /// Get search history.
  static List<String> getSearchHistory() {
    final box = Hive.box<String>(_searchHistoryBox);
    return box.values.toList();
  }

  /// Clear search history.
  static Future<void> clearSearchHistory() async {
    final box = Hive.box<String>(_searchHistoryBox);
    await box.clear();
  }
}
