import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Channel: Price Alerts ──
  static const String _priceChannelId = 'price_alerts';
  static const String _priceChannelName = 'Price Alerts';
  static const String _priceChannelDesc =
      'Notifikasi alert pergerakan harga saham.';

  // ── Channel: Ticker Saved ──
  static const String _tickerSavedChannelId = 'ticker_saved';
  static const String _tickerSavedChannelName = 'Ticker Tersimpan';
  static const String _tickerSavedChannelDesc =
      'Notifikasi saat ticker baru berhasil disimpan ke database.';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  // ── Test Notification ──

  static Future<void> showTestNotification() async {
    if (!_initialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      _priceChannelId,
      _priceChannelName,
      channelDescription: _priceChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFD4A843),
      ledColor: Color(0xFFD4A843),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        '🎉 Notifikasi berhasil!\n\n'
        'Tick Watchers siap mengirim alert harga saham secara real-time.\n'
        'Atur threshold di Settings untuk memantau pergerakan ticker favoritmu.',
        htmlFormatBigText: false,
        contentTitle: '✅ Tick Watchers - Test OK',
        summaryText: 'Notifikasi Aktif',
      ),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1001,
      '✅ Tick Watchers',
      'Notifikasi test berhasil! Tap untuk detail.',
      details,
    );
  }

  // ── Price Alert ──

  static Future<void> showPriceAlert({
    required String ticker,
    required double changeUp,
    required double threshold,
  }) async {
    if (!_initialized) {
      await init();
    }

    final emoji = changeUp >= 10 ? '🔥' : (changeUp >= 5 ? '📈' : '💹');
    final subtitle =
        '$ticker naik ${changeUp.toStringAsFixed(2)}% (threshold: ${threshold.toStringAsFixed(1)}%)';

    final bigText = '$emoji $ticker mengalami kenaikan signifikan!\n\n'
        '• Perubahan: +${changeUp.toStringAsFixed(2)}%\n'
        '• Threshold: ≥${threshold.toStringAsFixed(1)}%\n'
        '• Status: BREAKOUT ALERT\n\n'
        'Buka Tick Watchers untuk analisis lebih lanjut.';

    final androidDetails = AndroidNotificationDetails(
      _priceChannelId,
      _priceChannelName,
      channelDescription: _priceChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      color: const Color(0xFF5B9A6F),
      ledColor: const Color(0xFF5B9A6F),
      ledOnMs: 500,
      ledOffMs: 250,
      icon: '@mipmap/ic_launcher',
      ticker: '$emoji Alert: $ticker +${changeUp.toStringAsFixed(1)}%',
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: '$emoji Alert Harga: $ticker',
        summaryText: subtitle,
      ),
      category: AndroidNotificationCategory.recommendation,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      groupKey: 'price_alerts_group',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      ticker.hashCode & 0x7fffffff,
      '$emoji Alert: $ticker',
      subtitle,
      details,
    );
  }

  // ── Ticker Saved Notification ──

  /// Show a notification when a ticker is successfully fetched and saved
  /// to the database.
  static Future<void> showTickerSaved({
    required String tickerName,
  }) async {
    if (!_initialized) {
      await init();
    }

    final androidDetails = AndroidNotificationDetails(
      _tickerSavedChannelId,
      _tickerSavedChannelName,
      channelDescription: _tickerSavedChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: const Color(0xFF5B9A6F),
      ledColor: const Color(0xFF5B9A6F),
      ledOnMs: 800,
      ledOffMs: 400,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        '✅ $tickerName berhasil di simpan ke database.\n\n'
        'Data fundamental telah diambil dan tersimpan di watchlist kamu.\n'
        'Buka Tick Watchers untuk melihat analisis lengkapnya.',
        htmlFormatBigText: false,
        contentTitle: '💾 Ticker Tersimpan',
        summaryText: tickerName,
      ),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );
    final details = NotificationDetails(android: androidDetails);

    debugPrint('[NotificationService] showTickerSaved → $tickerName');

    await _plugin.show(
      tickerName.hashCode & 0x7fffffff,
      '💾 Ticker Tersimpan',
      '$tickerName berhasil di simpan ke database',
      details,
    );
  }
}

