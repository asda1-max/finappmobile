import 'package:flutter/foundation.dart';

/// API configuration constants for the FastAPI backend.
///
/// Change [baseUrl] to point to your FastAPI backend:
/// - Web (Chrome): http://127.0.0.1:8000
/// - Android emulator: http://10.0.2.2:8000
/// - Physical device (same WiFi): http://YOUR-PC-IP:8000
/// - Cloud deploy: https://your-server.com
class ApiConstants {
  ApiConstants._();

  /// Base URL for the FastAPI backend.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  // ── Endpoints ──
  static const String stocks = '/stocks';
  static const String savedTickers = '/saved-tickers';
  static const String hybridConfig = '/hybrid-config';
  static const String decisionCagr = '/decision-cagr';
  static const String decisionCagrAuto = '/decision-cagr-auto';
  static const String resetAll = '/reset-all';
  static const String priceHistory = '/price-history';
  static const String performanceOverview = '/performance-overview';
  static const String rankingData = '/ranking-data';

  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authMe = '/auth/me';

  /// Delete a specific ticker entry
  static String deleteEntry(String ticker) => '/entry/$ticker';

  /// CAGR raw data for a specific ticker
  static String cagrRaw(String ticker) => '/cagr-raw/$ticker';

  /// Timeout durations
  static const Duration connectTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration sendTimeout = Duration(seconds: 120);
}
