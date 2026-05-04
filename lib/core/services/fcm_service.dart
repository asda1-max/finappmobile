import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api_client.dart';
import 'local_db_service.dart';
import 'notification_service.dart';
import 'session_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.init();

  final notification = message.notification;
  final title = notification?.title ?? message.data['title'];
  final body = notification?.body ?? message.data['body'];

  if (title != null || body != null) {
    await NotificationService.showRemoteNotification(
      title: title ?? 'Tick Watchers',
      body: body ?? '',
    );
  }
}

class FcmService {
  FcmService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    _syncToken();
    messaging.onTokenRefresh.listen(_registerToken);

    _initialized = true;
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await NotificationService.init();

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];

    if (title != null || body != null) {
      await NotificationService.showRemoteNotification(
        title: title ?? 'Tick Watchers',
        body: body ?? '',
      );
    }
  }

  static Future<void> _syncToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }
  }

  static Future<void> _registerToken(String token) async {
    final loggedIn = await SessionService.isLoggedIn();
    if (!loggedIn) return;

    final cached = LocalDbService.getPreference<String>('fcm_token');
    if (cached == token) return;

    final platform = Platform.isAndroid ? 'android' : Platform.operatingSystem;

    try {
      await ApiClient.instance.post(
        '/push/register',
        data: {
          'token': token,
          'platform': platform,
        },
      );
      await LocalDbService.savePreference('fcm_token', token);
    } catch (_) {
      // Ignore transient failures; token will be retried on next launch.
    }
  }
}
