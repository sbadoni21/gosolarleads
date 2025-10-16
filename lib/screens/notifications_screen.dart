// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:gosolarleads/models/notification.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/services/fcm_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with AutomaticKeepAliveClientMixin {
  final _fcm = FCMService();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    // small delay so the RefreshIndicator anim feels right
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context); // capture early (avoids deactivated ancestor)
              try {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mark all as read?'),
                    content: const Text('This will mark every notification as read.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark all')),
                    ],
                  ),
                );
                if (confirm != true) return;

                await _fcm.markAllAsRead();
                messenger?.showSnackBar(const SnackBar(content: Text('All marked as read')));
                await _refresh();
              } catch (e) {
                messenger?.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(14),
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          // empty state
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none, size: 72, color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'You’re all caught up!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'New notifications will appear here.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            );
          }

          // group by day
          final groups = _groupByDay(list);
          final totalUnread = list.where((n) => !n.isReadBy(currentUser?.uid ?? '')).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _headerSummary(total: list.length, unread: totalUnread),
                  ),
                ),
                for (final entry in groups.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: _dayHeader(entry.key),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: entry.value.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final notif = entry.value[i];
                      final isRead = notif.isReadBy(currentUser?.uid ?? '');
                      return _NotificationCard(
                        notification: notif,
                        isRead: isRead,
                        onTap: () async {
                          if (!isRead) {
                            await _safeMarkRead(notif.id);
                          }
                          _handleNotificationTap(context, notif);
                        },
                        onDelete: () async {
                          await _safeDelete(notif.id);
                        },
                      );
                    },
                  ).pad(const EdgeInsets.symmetric(horizontal: 16)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- helpers ---

  Map<DateTime, List<AppNotification>> _groupByDay(List<AppNotification> list) {
    // normalize date to day
    DateTime atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);
    final map = <DateTime, List<AppNotification>>{};
    for (final n in list..sort((a, b) => b.createdAt.compareTo(a.createdAt))) {
      final key = atMidnight(n.createdAt);
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }

  Widget _headerSummary({required int total, required int unread}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$total notifications',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.markunread_outlined, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 6),
                  Text('$unread unread', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayHeader(DateTime date) {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final isYesterday = DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)));
    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('EEE, dd MMM').format(date);
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.black12)),
      ],
    );
  }

  Future<void> _safeMarkRead(String id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _fcm.markAsRead(id);
      // don’t show toast for every single tap; keep UI calm.
      ref.invalidate(notificationsProvider);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Failed to mark as read: $e')));
    }
  }

  Future<void> _safeDelete(String id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _fcm.deleteNotification(id);
      ref.invalidate(notificationsProvider);
      messenger?.showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _handleNotificationTap(BuildContext context, AppNotification notif) {
    // Implement navigation based on notification type or data
    final leadId = notif.data['leadId'];
    final groupId = notif.data['groupId'];

    switch (notif.type) {
      case 'lead_created':
      case 'lead_assigned':
      case 'sla_warning':
      case 'sla_breach':
        if (leadId != null && leadId.toString().isNotEmpty) {
          // Navigator.pushNamed(context, '/leads/$leadId');
        }
        break;
      case 'group_message':
        if (groupId != null && groupId.toString().isNotEmpty) {
          // Navigator.pushNamed(context, '/chat/$groupId');
        }
        break;
      default:
        // no-op or show details
        break;
    }
  }
}

// ------------------- UI Card -------------------

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  Color get _accent {
    switch (notification.type) {
      case 'lead_created':
        return Colors.blue;
      case 'lead_assigned':
        return Colors.green;
      case 'lead_unassigned':
        return Colors.orange;
      case 'sla_warning':
        return Colors.amber.shade700;
      case 'sla_breach':
        return Colors.red;
      case 'group_message':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'lead_created':
        return Icons.person_add;
      case 'lead_assigned':
        return Icons.assignment_turned_in;
      case 'lead_unassigned':
        return Icons.assignment_late;
      case 'sla_warning':
        return Icons.warning_amber_rounded;
      case 'sla_breach':
        return Icons.error_outline;
      case 'group_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications;
    }
  }

  String _rel(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    // Dismissible + confirm
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete notification?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async => onDelete(),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 26),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              // left accent
              Container(
                width: 6,
                height: 88,
                decoration: BoxDecoration(
                  color: isRead ? _accent.withOpacity(.35) : _accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _accent.withOpacity(.12),
                        child: Icon(_icon, color: _accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // title + time
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: Colors.black87,
                                      letterSpacing: -.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _rel(notification.createdAt),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.25),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _chip(notification.type),
                                if (!isRead) _unreadPill(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    final label = text.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _accent.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _accent, letterSpacing: .4),
      ),
    );
  }

  Widget _unreadPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 10, color: Colors.black87),
          SizedBox(width: 4),
          Text('UNREAD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// -------------- small extension to pad slivers --------------
extension _SliverPad on Widget {
  Widget pad(EdgeInsets insets) => SliverPadding(padding: insets, sliver: this);
}
