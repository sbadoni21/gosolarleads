import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/screens/chatscreens/chat_screen.dart';
import 'package:gosolarleads/screens/chatscreens/create_group_screen.dart';
import 'package:intl/intl.dart';

class ChatTab extends ConsumerWidget {
  const ChatTab({super.key});

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final d = now.difference(time);
    if (d.inDays == 0) return DateFormat('HH:mm').format(time);
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return DateFormat('EEEE').format(time);
    return DateFormat('dd/MM/yy').format(time);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Changed from allChatGroupsProvider to chatGroupsProvider
    final groupsAsync = ref.watch(chatGroupsProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Groups Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.isSuperAdmin == true
                        ? 'Create a group to start chatting'
                        : 'You haven\'t been added to any groups yet',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.mediumGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (user?.isSuperAdmin == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                      label: const Text('Create Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ✅ Changed to invalidate chatGroupsProvider
              ref.invalidate(chatGroupsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final avatarLetter =
                    (group.name.isNotEmpty ? group.name.characters.first : 'G')
                        .toUpperCase();

                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(group: group),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                      child: group.groupIcon != null
                          ? ClipOval(
                              child: Image.network(
                                group.groupIcon!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  avatarLetter,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              avatarLetter,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(group.lastMessageTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                group.locationDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (group.lastMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.lastMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkGrey.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people_outline,
                                size: 14, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Text(
                              '${group.memberCount} members',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppTheme.errorRed),
              const SizedBox(height: 16),
              const Text('Error loading groups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.mediumGrey)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(chatGroupsProvider),
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
      ),
      floatingActionButton: (user?.isSuperAdmin == true)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            )
          : null, // ✅ Changed from SizedBox() to null
    );
  }
}
