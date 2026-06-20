import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftio/data/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<int>? _countSub;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void init(String userId) {
    _notifSub = _service.watchNotifications(userId).listen((notifs) {
      _notifications = notifs;
      notifyListeners();
    });

    _countSub = _service.watchUnreadCount(userId).listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _service.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    for (final n in _notifications) {
      if (n['is_read'] == false) {
        await _service.markAsRead(n['id'] as String);
      }
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _countSub?.cancel();
    super.dispose();
  }
}
