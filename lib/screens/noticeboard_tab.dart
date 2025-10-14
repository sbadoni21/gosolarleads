import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/notice.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/services/notice_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NoticeBoardTab extends ConsumerWidget {
  const NoticeBoardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesStreamProvider);
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.role == 'admin' || user?.role == 'superadmin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showCreateNoticeDialog(context, ref, user!),
              tooltip: 'Create Notice',
            ),
        ],
      ),
      body: noticesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (notices) {
          if (notices.isEmpty) {
            return _buildEmptyState(context, isAdmin);
          }

          final pinnedNotices = notices.where((n) => n.isPinned).toList();
          final regularNotices = notices.where((n) => !n.isPinned).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(noticesStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pinnedNotices.isNotEmpty) ...[
                  _buildSectionHeader('Pinned Notices', Icons.push_pin),
                  const SizedBox(height: 12),
                  ...pinnedNotices.map((notice) => _buildNoticeCard(
                        context,
                        ref,
                        notice,
                        user,
                        isAdmin,
                      )),
                  const SizedBox(height: 24),
                ],
                if (regularNotices.isNotEmpty) ...[
                  _buildSectionHeader('All Notices', Icons.notifications_outlined),
                  const SizedBox(height: 12),
                  ...regularNotices.map((notice) => _buildNoticeCard(
                        context,
                        ref,
                        notice,
                        user,
                        isAdmin,
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isAdmin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 80,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Notices Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Create your first notice to inform your team'
                : 'Check back later for announcements',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.mediumGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard(
    BuildContext context,
    WidgetRef ref,
    Notice notice,
    dynamic user,
    bool isAdmin,
  ) {
    final isRead = user != null && notice.isReadBy(user.uid);
    final typeColor = _getTypeColor(notice.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showNoticeDetails(context, ref, notice, user),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? AppTheme.mediumGrey.withOpacity(0.2)
                  : typeColor.withOpacity(0.5),
              width: isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withOpacity(0.1),
                      typeColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notice.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notice.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkGrey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (notice.isPinned)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.push_pin,
                                          size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Pinned',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 12, color: AppTheme.mediumGrey),
                              const SizedBox(width: 4),
                              Text(
                                notice.createdByName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time,
                                  size: 12, color: AppTheme.mediumGrey),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(notice.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),

              // Content Preview
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  notice.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkGrey,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Footer
              if (isAdmin || notice.attachments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (notice.attachments.isNotEmpty) ...[
                        Icon(Icons.attach_file,
                            size: 16, color: AppTheme.mediumGrey),
                        const SizedBox(width: 4),
                        Text(
                          '${notice.attachments.length} attachment${notice.attachments.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isAdmin) ...[
                        IconButton(
                          icon: Icon(
                            notice.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            size: 20,
                            color: notice.isPinned
                                ? AppTheme.primaryOrange
                                : AppTheme.mediumGrey,
                          ),
                          onPressed: () => _togglePin(ref, notice),
                          tooltip: 'Toggle Pin',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppTheme.errorRed),
                          onPressed: () => _deleteNotice(context, ref, notice),
                          tooltip: 'Delete',
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning':
        return AppTheme.warningAmber;
      case 'urgent':
        return AppTheme.errorRed;
      case 'celebration':
        return AppTheme.successGreen;
      case 'info':
      default:
        return AppTheme.primaryBlue;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  void _showNoticeDetails(
    BuildContext context,
    WidgetRef ref,
    Notice notice,
    dynamic user,
  ) {
    // Mark as read
    if (user != null && !notice.isReadBy(user.uid)) {
      ref.read(noticeServiceProvider).markAsRead(notice.id, user.uid);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoticeDetailSheet(notice: notice),
    );
  }

  Future<void> _togglePin(WidgetRef ref, Notice notice) async {
    try {
      await ref
          .read(noticeServiceProvider)
          .togglePin(notice.id, notice.isPinned);
    } catch (e) {
      print('Error toggling pin: $e');
    }
  }

  Future<void> _deleteNotice(
    BuildContext context,
    WidgetRef ref,
    Notice notice,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: const Text(
          'This notice will be permanently deleted for all users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(noticeServiceProvider).deleteNotice(notice.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreateNoticeDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => CreateNoticeDialog(user: user),
    );
  }
}

// Notice Detail Sheet
class NoticeDetailSheet extends StatelessWidget {
  final Notice notice;

  const NoticeDetailSheet({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(notice.type);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mediumGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            typeColor.withOpacity(0.2),
                            typeColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                notice.icon,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  notice.title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: typeColor),
                              const SizedBox(width: 6),
                              Text(
                                notice.createdByName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.darkGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: typeColor),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(notice.createdAt),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Content
                    Text(
                      notice.content,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.darkGrey,
                        height: 1.6,
                      ),
                    ),

                    if (notice.imageUrl != null) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          notice.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],

                    if (notice.attachments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...notice.attachments.map((url) => _buildAttachment(url)),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachment(String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              url.split('/').last,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            onPressed: () {
              // Implement download
            },
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning':
        return AppTheme.warningAmber;
      case 'urgent':
        return AppTheme.errorRed;
      case 'celebration':
        return AppTheme.successGreen;
      case 'info':
      default:
        return AppTheme.primaryBlue;
    }
  }
}

// Create Notice Dialog
class CreateNoticeDialog extends ConsumerStatefulWidget {
  final dynamic user;

  const CreateNoticeDialog({super.key, required this.user});

  @override
  ConsumerState<CreateNoticeDialog> createState() => _CreateNoticeDialogState();
}

class _CreateNoticeDialogState extends ConsumerState<CreateNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _selectedType = 'info';
  String _selectedPriority = 'normal';
  bool _isPinned = false;
  bool _sendNotification = true;
  bool _isLoading = false;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: AppTheme.primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Create Notice',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGrey.withOpacity(0.5),
                        ),
                        validator: (val) =>
                            val?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Content
                      TextFormField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Content *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGrey.withOpacity(0.5),
                        ),
                        validator: (val) =>
                            val?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGrey.withOpacity(0.5),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('📢 Info')),
                          DropdownMenuItem(
                              value: 'warning', child: Text('⚠️ Warning')),
                          DropdownMenuItem(
                              value: 'urgent', child: Text('🚨 Urgent')),
                          DropdownMenuItem(
                              value: 'celebration', child: Text('🎉 Celebration')),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedType = val!),
                      ),
                      const SizedBox(height: 16),

                      // Priority
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGrey.withOpacity(0.5),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedPriority = val!),
                      ),
                      const SizedBox(height: 16),

                      // Toggles
                      SwitchListTile(
                        title: const Text('Pin to top'),
                        subtitle: const Text('Keep this notice at the top'),
                        value: _isPinned,
                        onChanged: (val) => setState(() => _isPinned = val),
                      ),
                      SwitchListTile(
                        title: const Text('Send push notification'),
                        subtitle: const Text('Notify all users immediately'),
                        value: _sendNotification,
                        onChanged: (val) =>
                            setState(() => _sendNotification = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createNotice,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isLoading ? 'Posting...' : 'Post Notice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(noticeServiceProvider).createNotice(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            type: _selectedType,
            priority: _selectedPriority,
            createdBy: widget.user.uid,
            createdByName: widget.user.name ?? 'Admin',
            isPinned: _isPinned,
            sendNotification: _sendNotification,
            expiresAt: _expiresAt,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notice posted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}