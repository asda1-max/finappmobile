import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Channel: Price Alerts ──
  static const String _priceChannelId = 'price_alerts';
  static const String _priceChannelName = 'Price Alerts';
  static const String _priceChannelDesc =
      'Notifikasi alert pergerakan harga saham.';

  // ── Channel: Daily Reminder ──
  static const String _reminderChannelId = 'daily_reminder';
  static const String _reminderChannelName = 'Pengingat Harian';
  static const String _reminderChannelDesc =
      'Pengingat harian untuk cek watchlist.';

  // Use separate IDs: one for the immediate "show" and one for the
  // scheduled repeating alarm so they never collide.
  static const int _dailyReminderId = 2001;
  static const int _dailyReminderImmediateId = 2002;

  // Track a fallback timer for near-future reminders so we can cancel it
  // if the user reschedules before it fires.
  static Timer? _nearFutureTimer;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    await _configureLocalTimeZone();

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      // Request exact alarm permission (Android 12+).
      // Without this, zonedSchedule may silently fail or use inexact timing.
      await androidImpl.requestExactAlarmsPermission();
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

  // ── Daily Reminder ──

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) {
      await init();
    }

    // ── 1. Clean up ALL previous reminders ──
    // Cancel the scheduled repeating alarm
    await _plugin.cancel(_dailyReminderId);
    // Cancel any immediate notification from a previous "show now"
    await _plugin.cancel(_dailyReminderImmediateId);
    // Cancel any pending near-future timer
    _nearFutureTimer?.cancel();
    _nearFutureTimer = null;

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = _nextInstanceOfTime(hour, minute);
    final diffSeconds = scheduled.difference(now).inSeconds;

    final formattedTime =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    const reminderAndroid = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: _reminderChannelDesc,
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
        '⏰ Waktunya cek watchlist!\n\n'
        'Lihat perubahan harga terbaru dan peluang baru di portofoliomu.\n'
        'Tetap update setiap hari untuk keputusan investasi yang lebih baik. 📊',
        htmlFormatBigText: false,
        contentTitle: '⏰ Pengingat Harian',
        summaryText: 'Tick Watchers',
      ),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    const reminderDetails = NotificationDetails(android: reminderAndroid);

    debugPrint('[NotificationService] scheduleDailyReminder → '
        '$formattedTime (in ${diffSeconds}s)');

    // ── 2. Handle "now or very soon" (within 30s) ──
    if (diffSeconds <= 30) {
      // Show immediately using a DIFFERENT id so the scheduled alarm
      // (id 2001) is not blocked.
      await _plugin.show(
        _dailyReminderImmediateId,
        '⏰ Pengingat Harian',
        'Cek watchlist kamu hari ini — $formattedTime ✅',
        reminderDetails,
      );

      // Schedule the repeating daily alarm for TOMORROW
      final tomorrow = scheduled.add(const Duration(days: 1));
      await _scheduleRepeating(tomorrow, formattedTime, reminderDetails);
      return;
    }

    // ── 3. Handle near-future (within 5 minutes) ──
    // Android Doze can delay inexact alarms 10-15 min, and even exact
    // alarms may need special permission. Use a Dart Timer as a reliable
    // fallback for the first occurrence, then set the daily repeating alarm.
    if (diffSeconds <= 300) {
      debugPrint('[NotificationService] Using Timer fallback '
          'for near-future (${diffSeconds}s)');

      _nearFutureTimer = Timer(Duration(seconds: diffSeconds), () async {
        await _plugin.show(
          _dailyReminderImmediateId,
          '⏰ Pengingat Harian',
          'Cek watchlist kamu hari ini — $formattedTime ✅',
          reminderDetails,
        );
      });

      // Also schedule the repeating daily alarm (it may fire late today
      // due to Doze, but from tomorrow it will be on time).
      await _scheduleRepeating(scheduled, formattedTime, reminderDetails);
      return;
    }

    // ── 4. Normal future scheduling ──
    await _scheduleRepeating(scheduled, formattedTime, reminderDetails);
  }

  /// Schedule a repeating daily alarm via [zonedSchedule].
  /// Tries exact mode first; falls back to inexact if permission is denied.
  static Future<void> _scheduleRepeating(
    tz.TZDateTime scheduledDate,
    String formattedTime,
    NotificationDetails details,
  ) async {
    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        '⏰ Pengingat Harian',
        'Cek watchlist kamu hari ini — $formattedTime ✅',
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('[NotificationService] Scheduled EXACT alarm at '
          '$scheduledDate');
    } catch (e) {
      // Exact alarm permission not granted → fall back to inexact.
      debugPrint('[NotificationService] Exact alarm failed ($e), '
          'falling back to inexact');
      await _plugin.zonedSchedule(
        _dailyReminderId,
        '⏰ Pengingat Harian',
        'Cek watchlist kamu hari ini — $formattedTime ✅',
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelDailyReminder() async {
    if (!_initialized) {
      await init();
    }
    await _plugin.cancel(_dailyReminderId);
    await _plugin.cancel(_dailyReminderImmediateId);
    _nearFutureTimer?.cancel();
    _nearFutureTimer = null;
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
}
