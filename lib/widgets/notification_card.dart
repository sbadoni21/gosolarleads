import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/notification.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

// Notification Card Widget
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isRead ? Colors.white : AppTheme.primaryBlue.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'lead_created':
      case 'lead_created_location':
        icon = Icons.location_on;
        color = AppTheme.primaryOrange;
        break;
      case 'lead_assigned':
        icon = Icons.person_add;
        color = AppTheme.primaryBlue;
        break;
      case 'lead_unassigned':
        icon = Icons.person_remove;
        color = AppTheme.warningAmber;
        break;
      case 'sla_warning':
        icon = Icons.warning_amber_rounded;
        color = AppTheme.warningAmber;
        break;
      case 'sla_breach':
        icon = Icons.error;
        color = AppTheme.errorRed;
        break;
      case 'registration_completed':
        icon = Icons.how_to_reg;
        color = AppTheme.successGreen;
        break;
      case 'installation_completed':
        icon = Icons.check_circle;
        color = AppTheme.successGreen;
        break;
      case 'group_message':
        icon = Icons.chat_bubble;
        color = AppTheme.primaryBlue;
        break;
      case 'daily_digest':
        icon = Icons.assessment;
        color = AppTheme.primaryBlue;
        break;
      default:
        icon = Icons.notifications;
        color = AppTheme.primaryBlue;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

// Notification Badge for AppBar
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadCountProvider);

    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.notifications_outlined),
          unreadCountAsync.when(
            data: (count) {
              if (count > 0) {
                return Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      onPressed: () {
        Navigator.pushNamed(context, '/notifications');
      },
    );
  }
}

// ========================================
// HOW TO USE IN YOUR LEAD TAB:
// ========================================
/*
@override
Widget build(BuildContext context) {
  final leadsAsync = ref.watch(allLeadsProvider);

  return Scaffold(
    appBar: AppBar(
      title: const Text('Leads'),
      actions: const [
        NotificationBadge(),  // <-- Add this
        SizedBox(width: 8),
      ],
    ),
    body: Column(
      children: [
        // Your existing filter chips and leads list
      ],
    ),
    floatingActionButton: // Your existing FAB
  );
}
*/