import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background message handler — mora biti top-level funkcija
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM poruka: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ─── INIT ─────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Traži dozvole (iOS + Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'shiftio_main',
      'Shiftio Obaveštenja',
      description: 'Obaveštenja o smenama i zahtevima',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Init local notifications
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(initSettings);

    // Foreground poruke
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App otvorena klikom na notifikaciju (background state)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App pokrenuta klikom na notifikaciju (terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // ─── TOKEN ────────────────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> saveTokenToFirestore(String uid) async {
    final token = await getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).update({'fcm_token': token});

    // Osvježi token ako se promijeni
    _fcm.onTokenRefresh.listen((newToken) async {
      await _db.collection('users').doc(uid).update({'fcm_token': newToken});
    });
  }

  // ─── FOREGROUND HANDLER ───────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shiftio_main',
          'Shiftio Obaveštenja',
          channelDescription: 'Obaveštenja o smenama i zahtevima',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─── TAP HANDLER ─────────────────────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    // Navigacija po tipu notifikacije
    final type = message.data['type'];
    debugPrint('Notifikacija kliknuta, tip: $type');
    // Navigacija će biti implementirana kroz GlobalKey<NavigatorState>
  }

  // ─── SEND NOTIFICATION (Admin šalje radniku) ──────────────────────────────────

  /// Šalje notifikaciju svim radnicima iz liste (čuva u Firestore,
  /// Cloud Functions šalju FCM na osnovu tokena)
  Future<void> sendShiftNotification({
    required String companyId,
    required List<String> workerIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    for (final workerId in workerIds) {
      final docRef = _db.collection('notifications').doc();
      batch.set(docRef, {
        'recipient_id': workerId,
        'company_id': companyId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'is_read': false,
        'created_at': Timestamp.fromDate(now),
        'type': 'shift',
      });
    }

    await batch.commit();
  }

  Future<void> sendRequestNotification({
    required String recipientId,
    required String companyId,
    required String title,
    required String body,
    required String requestId,
  }) async {
    await _db.collection('notifications').add({
      'recipient_id': recipientId,
      'company_id': companyId,
      'title': title,
      'body': body,
      'data': {'request_id': requestId},
      'is_read': false,
      'created_at': Timestamp.fromDate(DateTime.now()),
      'type': 'request',
    });
  }

  // ─── READ NOTIFICATION ────────────────────────────────────────────────────────

  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'is_read': true,
      'read_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return _db
        .collection('notifications')
        .where('recipient_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<List<Map<String, dynamic>>> watchNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('recipient_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
