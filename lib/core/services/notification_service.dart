import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'price_alerts';
  static const String _channelName = 'Price Alerts';
  static const String _channelDesc =
      'Notifikasi alert pergerakan harga saham.';
  static const int _dailyReminderId = 2001;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    await _configureLocalTimeZone();

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Fallback to UTC if local timezone cannot be resolved.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> showTestNotification() async {
    if (!_initialized) {
      await init();
    }
    await _plugin.show(
      1001,
      'Tick Watchers',
      'Notifikasi test berhasil 🎉',
      _details(),
    );
  }

  static Future<void> showPriceAlert({
    required String ticker,
    required double changeUp,
    required double threshold,
  }) async {
    if (!_initialized) {
      await init();
    }
    await _plugin.show(
      ticker.hashCode & 0x7fffffff,
      'Alert Harga: $ticker',
      '$ticker naik ${changeUp.toStringAsFixed(2)}% (>= ${threshold.toStringAsFixed(2)}%)',
      _details(),
    );
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) {
      await init();
    }

    // Cancel any existing reminder before scheduling a new one.
    await _plugin.cancel(_dailyReminderId);

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = _nextInstanceOfTime(hour, minute);

    // If user sets the time to "now" (same minute), show immediately
    // and schedule the next day to avoid missing the reminder.
    if (scheduled.difference(now).inSeconds <= 30) {
      await _plugin.show(
        _dailyReminderId,
        'Pengingat Harian',
        'Cek watchlist kamu hari ini. ✅',
        _details(),
      );
      final tomorrow = scheduled.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Pengingat Harian',
        'Cek watchlist kamu hari ini. ✅',
        tomorrow,
        _details(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return;
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Pengingat Harian',
      'Cek watchlist kamu hari ini. ✅',
      scheduled,
      _details(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelDailyReminder() async {
    if (!_initialized) {
      await init();
    }
    await _plugin.cancel(_dailyReminderId);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFD4A843), // Retro gold
      ledColor: Color(0xFFD4A843),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: '@mipmap/ic_launcher',
    );
    return const NotificationDetails(android: androidDetails);
  }
}
