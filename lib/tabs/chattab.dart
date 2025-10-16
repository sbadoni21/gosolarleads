import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/screens/chatscreens/chat_screen.dart';
import 'package:gosolarleads/screens/chatscreens/create_group_screen.dart';
import 'package:intl/intl.dart';

class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final d = now.difference(time);
    if (d.inDays == 0) return DateFormat('HH:mm').format(time);
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('dd/MM/yy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isSuperAdmin = (user.isSuperAdmin == true) ||
        (user.role?.toLowerCase() == 'superadmin');

    final groupsAsync = ref.watch(allChatGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withOpacity(.08),
                    Colors.white,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.forum_outlined,
                            color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (isSuperAdmin)
                        Tooltip(
                          message: 'Create Group',
                          child: IconButton.filledTonal(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateGroupScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryBlue.withOpacity(0.12),
                              foregroundColor: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search groups…',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // LIST
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  error: e.toString(),
                  onRetry: () => ref.invalidate(allChatGroupsProvider),
                ),
                data: (allGroups) {
                  // filter by membership
                  final visibleGroups = (isSuperAdmin
                          ? allGroups
                          : allGroups.where((g) {
                              final ids = (g.members ?? const <String>[]);
                              return ids.contains(user.uid);
                            }))
                      .toList();

                  // search filter
                  final q = _query.toLowerCase();
                  final groups = q.isEmpty
                      ? visibleGroups
                      : visibleGroups.where((g) {
                          final hay = [
                            g.name,
                            g.locationDisplay,
                            g.lastMessage ?? ''
                          ].join(' ').toLowerCase();
                          return hay.contains(q);
                        }).toList();

                  if (groups.isEmpty) {
                    return _EmptyState(
                      isSuperAdmin: isSuperAdmin,
                      onCreate: isSuperAdmin
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateGroupScreen(),
                                ),
                              );
                            }
                          : null,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(allChatGroupsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return _GroupTile(
                          name: g.name,
                          avatarUrl: g.groupIcon,
                          location: g.locationDisplay,
                          lastMessage: g.lastMessage,
                          lastMessageTime: g.lastMessageTime,
                          memberCount: g.memberCount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(group: g),
                              ),
                            );
                          },
                          timeLabel: _formatTime(g.lastMessageTime),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null, // FAB moved to header action for cleaner UI
    );
  }
}

/// Group tile with modern card, safe overflows, and subtle accents
class _GroupTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String location;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int memberCount;
  final VoidCallback onTap;
  final String timeLabel;

  const _GroupTile({
    required this.name,
    required this.avatarUrl,
    required this.location,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.memberCount,
    required this.onTap,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final initials =
        (name.isNotEmpty ? name.characters.first.toUpperCase() : 'G');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(.12),
                      Colors.white
                    ],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _AvatarFallback(initials),
                        loadingBuilder: (ctx, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                      )
                    : _AvatarFallback(initials),
              ),
              const SizedBox(width: 12),

              // Text area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: name + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Location
                    if (location.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (location.isNotEmpty) const SizedBox(height: 4),
                    // Last message
                    if ((lastMessage ?? '').isNotEmpty)
                      Text(
                        lastMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Chips row
                    Row(
                      children: [
                        _metaChip(
                          icon: Icons.people_outline,
                          label: '$memberCount',
                        ),
                        const SizedBox(width: 8),
                        _metaChip(
                          icon: Icons.chat_bubble_outline,
                          label: (lastMessage ?? '').isEmpty ? 'New' : 'Active',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback(this.initials);
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryBlue.withOpacity(.08),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSuperAdmin;
  final VoidCallback? onCreate;
  const _EmptyState({required this.isSuperAdmin, this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined,
                  size: 70, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 18),
            Text(
              isSuperAdmin ? 'No Groups Yet' : 'No Groups Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSuperAdmin
                  ? 'Create a group to start chatting.'
                  : 'Ask an admin to add you to a group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            if (isSuperAdmin && onCreate != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            const Text(
              'Error loading groups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
