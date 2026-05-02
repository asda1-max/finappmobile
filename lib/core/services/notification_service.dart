import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'price_alerts';
  static const String _channelName = 'Price Alerts';
  static const String _channelDesc =
      'Notifikasi alert pergerakan harga saham.';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
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

  static NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    return const NotificationDetails(android: androidDetails);
  }
}
