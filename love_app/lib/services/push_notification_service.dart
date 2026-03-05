import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel _loveAppChannel = AndroidNotificationChannel(
  'love_app_messages',
  'Love App Messages',
  description: 'Notifications for new messages and pair requests',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler intentionally minimal.
  // FCM handles notification display if payload contains notification fields.
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _registeredUid;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Push permission status: ${settings.authorizationStatus}');

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_loveAppChannel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened app: ${message.messageId}');
    });

    _initialized = true;
  }

  Future<void> registerUserToken(String uid) async {
    if (!_initialized) {
      await initialize();
    }

    if (_registeredUid == uid) return;

    _registeredUid = uid;

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      await _saveToken(uid, newToken);
    });
  }

  Future<void> clearUserTokenBinding() async {
    _registeredUid = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _saveToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdateAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null || kIsWeb) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Love App',
      body: notification.body ?? 'Nouveau message reçu',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _loveAppChannel.id,
          _loveAppChannel.name,
          channelDescription: _loveAppChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }
}
