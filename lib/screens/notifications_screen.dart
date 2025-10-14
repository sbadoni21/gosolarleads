
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/notification.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/services/fcm_service.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final fcmService = FCMService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await fcmService.markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All marked as read')),
              );
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final currentUser = ref.read(currentUserProvider).value;
              final isRead = notif.isReadBy(currentUser?.uid ?? '');

              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  fcmService.deleteNotification(notif.id);
                },
                child: ListTile(
                  leading: _getNotificationIcon(notif.type),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(notif.body),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(notif.createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (!isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      fcmService.markAsRead(notif.id);
                    }
                    // Navigate based on actionUrl or type
                    _handleNotificationTap(context, notif);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'lead_created':
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case 'lead_assigned':
        icon = Icons.assignment_turned_in;
        color = Colors.green;
        break;
      case 'lead_unassigned':
        icon = Icons.assignment_late;
        color = Colors.orange;
        break;
      case 'sla_warning':
        icon = Icons.warning;
        color = Colors.amber;
        break;
      case 'sla_breach':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'group_message':
        icon = Icons.chat;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _handleNotificationTap(BuildContext context, AppNotification notif) {
    // Implement navigation based on notification type
    final leadId = notif.data['leadId'];
    final groupId = notif.data['groupId'];

    switch (notif.type) {
      case 'lead_created':
      case 'lead_assigned':
      case 'sla_warning':
      case 'sla_breach':
        if (leadId != null) {
          // Navigate to lead details
          // Navigator.pushNamed(context, '/leads/$leadId');
        }
        break;
      case 'group_message':
        if (groupId != null) {
          // Navigate to chat
          // Navigator.pushNamed(context, '/chat/$groupId');
        }
        break;
    }
  }
}
