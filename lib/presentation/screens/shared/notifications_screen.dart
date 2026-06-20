import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Označi sve kao pročitano kad se otvori ekran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = context.watch<NotificationProvider>().notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obaveštenja'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: notifications.isEmpty
          ? _EmptyNotifications()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = notifications[i];
                return _NotificationCard(notification: n);
              },
            ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationCard({required this.notification});

  IconData get _icon {
    switch (notification['type']) {
      case 'shift':
        return Icons.calendar_today_rounded;
      case 'request':
        return Icons.inbox_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _iconColor {
    switch (notification['type']) {
      case 'shift':
        return AppColors.primary;
      case 'request':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = (timestamp as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Upravo';
      if (diff.inHours < 1) return 'Pre ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Pre ${diff.inHours}h';
      if (diff.inDays < 7) return 'Pre ${diff.inDays}d';
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRead = notification['is_read'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead
            ? (isDark ? AppColors.cardDark : AppColors.cardLight)
            : (isDark
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.infoLight),
        borderRadius: BorderRadius.circular(16),
        border: isRead
            ? null
            : Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ikona
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Sadržaj
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] ?? '',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(notification['created_at']),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification['body'] ?? '',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Unread dot
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4, left: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────
class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('Nema obaveštenja', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Nova obaveštenja će se pojaviti ovde',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
