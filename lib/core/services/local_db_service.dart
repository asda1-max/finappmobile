import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Service for local SQLite database — offline caching, preferences, search history.
class LocalDbService {
  static Database? _db;

  static const _tablePrefs = 'preferences';
  static const _tableTickers = 'saved_tickers';
  static const _tableSearch = 'search_history';
  static const _tableCache = 'stock_cache';

  static final Map<String, dynamic> _prefsCache = {};
  static List<String> _savedTickersCache = [];
  static List<String> _searchHistoryCache = [];
  static String? _cachedStocksJson;
  static int? _cachedStocksTimestamp;

  /// Initialize SQLite — call once in main() before runApp().
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'finapp_local.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_tablePrefs (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tableTickers (
            ticker TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tableSearch (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticker TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tableCache (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );

    await _warmCaches();
  }

  static Future<void> _warmCaches() async {
    if (_db == null) return;

    final prefs = await _db!.query(_tablePrefs);
    _prefsCache
      ..clear()
      ..addEntries(prefs.map((row) {
        final key = row['key'] as String;
        final raw = row['value'] as String?;
        dynamic decoded;
        try {
          decoded = raw == null ? null : jsonDecode(raw);
        } catch (_) {
          decoded = raw;
        }
        return MapEntry(key, decoded);
      }));

    final tickers = await _db!.query(_tableTickers, orderBy: 'ticker ASC');
    _savedTickersCache = tickers.map((row) => row['ticker'] as String).toList();

    final searches = await _db!.query(
      _tableSearch,
      orderBy: 'created_at DESC',
      limit: 20,
    );
    _searchHistoryCache =
        searches.map((row) => row['ticker'] as String).toList();

    final cacheRows = await _db!.query(_tableCache);
    for (final row in cacheRows) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (key == 'stocks_data') {
        _cachedStocksJson = value;
      } else if (key == 'stocks_timestamp') {
        _cachedStocksTimestamp = int.tryParse(value ?? '');
      }
    }
  }

  // ── Stock Cache ──

  /// Cache stock data as JSON. Stored with timestamp for expiry.
  static Future<void> cacheStocks(List<Map<String, dynamic>> stocksJson) async {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = jsonEncode(stocksJson);
    _cachedStocksJson = raw;
    _cachedStocksTimestamp = now;
    await _db!.insert(
      _tableCache,
      {'key': 'stocks_data', 'value': raw},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db!.insert(
      _tableCache,
      {'key': 'stocks_timestamp', 'value': now.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached stocks. Returns null if cache is empty or expired (>1 hour).
  static List<Map<String, dynamic>>? getCachedStocks() {
    final timestamp = _cachedStocksTimestamp;
    if (timestamp == null) return null;

    // Cache expires after 1 hour
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 3600000) return null;

    final raw = _cachedStocksJson;
    if (raw == null) return null;

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Clear the stock cache.
  static Future<void> clearStockCache() async {
    if (_db == null) return;
    _cachedStocksJson = null;
    _cachedStocksTimestamp = null;
    await _db!.delete(_tableCache, where: 'key = ?', whereArgs: ['stocks_data']);
    await _db!
        .delete(_tableCache, where: 'key = ?', whereArgs: ['stocks_timestamp']);
  }

  // ── User Preferences ──

  /// Save a user preference.
  static Future<void> savePreference(String key, dynamic value) async {
    if (_db == null) return;
    _prefsCache[key] = value;
    await _db!.insert(
      _tablePrefs,
      {'key': key, 'value': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a user preference.
  static T? getPreference<T>(String key) {
    final value = _prefsCache[key];
    if (value == null) return null;
    return value as T?;
  }

  // ── Saved Tickers ──

  /// Save ticker list for quick access.
  static Future<void> saveTickers(List<String> tickers) async {
    if (_db == null) return;
    final clean = tickers.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    _savedTickersCache = clean;
    final batch = _db!.batch();
    batch.delete(_tableTickers);
    for (final t in clean) {
      batch.insert(
        _tableTickers,
        {'ticker': t},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get saved tickers (empty if none).
  static List<String> getSavedTickers() {
    return List<String>.from(_savedTickersCache);
  }

  // ── Search History ──

  /// Add a ticker to search history (max 20 items, most recent first).
  static Future<void> addSearchHistory(String ticker) async {
    if (_db == null) return;
    final clean = ticker.trim();
    if (clean.isEmpty) return;

    _searchHistoryCache.remove(clean);
    _searchHistoryCache.insert(0, clean);
    if (_searchHistoryCache.length > 20) {
      _searchHistoryCache = _searchHistoryCache.take(20).toList();
    }

    final batch = _db!.batch();
    batch.delete(_tableSearch, where: 'ticker = ?', whereArgs: [clean]);
    batch.insert(_tableSearch, {
      'ticker': clean,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await batch.commit(noResult: true);
  }

  /// Get search history.
  static List<String> getSearchHistory() {
    return List<String>.from(_searchHistoryCache);
  }

  /// Clear search history.
  static Future<void> clearSearchHistory() async {
    if (_db == null) return;
    _searchHistoryCache = [];
    await _db!.delete(_tableSearch);
  }
}
