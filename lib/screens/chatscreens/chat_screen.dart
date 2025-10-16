import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/pagination/chat_pagination.dart';
import 'package:gosolarleads/screens/chatscreens/create_lead_in_group_screen.dart';
import 'package:gosolarleads/screens/chatscreens/group_info_screen.dart';
import 'package:gosolarleads/services/media_upload_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/services/fcm_service.dart';
import 'package:gosolarleads/models/chat_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/widgets/chat_input_bar.dart';
import 'package:gosolarleads/widgets/image_message_bubble.dart';
import 'package:gosolarleads/widgets/sla_indicator.dart';
import 'package:gosolarleads/widgets/video_message_bubble.dart';
import 'package:gosolarleads/widgets/voice_message_bubble.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatGroup group;

  const ChatScreen({super.key, required this.group});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showAttachmentMenu = false;
  late AnimationController _attachmentMenuController;
  late Animation<double> _attachmentMenuAnimation;
  bool _isInForeground = true;
  final MediaUploadService _mediaService = MediaUploadService();
  Timer? _markAsReadTimer;
  bool _isLoadingMore = false;
  String? _currentUid;
  ChatService? _chatSvc;

  @override
  void initState() {
    super.initState();
    // cache what you’ll need later
    final user = ref.read(currentUserProvider).value;
    _currentUid = user?.uid;
    _chatSvc = ref.read(chatServiceProvider);

    if (_currentUid != null) {
      _chatSvc!.updateUserPresence(
        userId: _currentUid!,
        activeGroupId: widget.group.id,
      );
    }

    // presence on enter
    if (_currentUid != null) {
      _chatSvc!.updateUserPresence(
          userId: _currentUid!, activeGroupId: widget.group.id);
    }
    WidgetsBinding.instance.addObserver(this);
    _initializePagination();
    _scrollController.addListener(_onScroll);

    _attachmentMenuController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _attachmentMenuAnimation = CurvedAnimation(
      parent: _attachmentMenuController,
      curve: Curves.easeInOut,
    );

    _markAsReadTimer = Timer(const Duration(seconds: 2), () {
      _markMessagesAsRead();
    });
    // Listen to text changes to update send/mic button
    _messageController.addListener(() {
      setState(() {}); // Rebuild when text changes
    });
    FCMService().setActiveChat(widget.group.id);

    // Subscribe to group notifications
    _subscribeToGroupNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _markAsReadTimer?.cancel();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _messageController.dispose();
    _attachmentMenuController.dispose();

    // stop using ref here!
    FCMService().setActiveChat(null);
    final uid = _currentUid;
    final chatSvc = _chatSvc;
    if (uid != null && chatSvc != null) {
      chatSvc.updateUserPresence(userId: uid, activeGroupId: null);
    }

    _unsubscribeFromGroupNotifications();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Update active chat status based on app state
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      FCMService().setActiveChat(widget.group.id);
      setState(() {
        _isInForeground = true;
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background
      FCMService().setActiveChat(null);
      setState(() {
        _isInForeground = false;
      });
    }
  }

  void _initializePagination() {
    // Initialize the pagination controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatPagingControllerProvider(widget.group.id).notifier)
          .loadInitial();
    });
  }

  void _onScroll() {
    // Load more when scrolling to the top (in reverse list, top = bottom)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    final state = ref.read(chatPagingControllerProvider(widget.group.id));

    if (!state.hasMore || state.isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    await ref
        .read(chatPagingControllerProvider(widget.group.id).notifier)
        .loadMore();

    setState(() => _isLoadingMore = false);
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      await ref.read(chatServiceProvider).markMessagesAsRead(
            groupId: widget.group.id,
            userId: currentUser.uid,
          );
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _subscribeToGroupNotifications() async {
    try {
      await FCMService().updateGroupSubscriptions(
        subscribe: [widget.group.id],
      );
      print('✅ Subscribed to group ${widget.group.id} notifications');
    } catch (e) {
      print('❌ Failed to subscribe to group notifications: $e');
    }
  }

  Future<void> _unsubscribeFromGroupNotifications() async {
    try {
      await FCMService().updateGroupSubscriptions(
        unsubscribe: [widget.group.id],
      );
      print('✅ Unsubscribed from group ${widget.group.id} notifications');
    } catch (e) {
      print('❌ Failed to unsubscribe from group notifications: $e');
    }
  }

  void _showAttachmentOptions() {
    setState(() {
      _showAttachmentMenu = !_showAttachmentMenu;
      if (_showAttachmentMenu) {
        _attachmentMenuController.forward();
      } else {
        _attachmentMenuController.reverse();
      }
    });
  }
// Add at the top

// Update _pickImage method
  void _pickImage() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    XFile? image;
    if (result == 'camera') {
      image = await _mediaService.pickImageFromCamera();
    } else {
      image = await _mediaService.pickImageFromGallery();
    }

    if (image == null) return;

    _sendImageMessage(image.path);
  }

// Add _pickVideo method
  void _pickVideo() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    XFile? video;
    if (result == 'camera') {
      video = await _mediaService.pickVideoFromCamera();
    } else {
      video = await _mediaService.pickVideoFromGallery();
    }

    if (video == null) return;

    _sendVideoMessage(video.path);
  }

// Add _sendImageMessage method
  Future<void> _sendImageMessage(String imagePath) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    // Show upload dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Uploading image...'),
          ],
        ),
      ),
    );

    try {
      final result = await _mediaService.uploadImage(
        filePath: imagePath,
        groupId: widget.group.id,
        senderId: currentUser.uid,
      );

      if (mounted) Navigator.pop(context);

      if (result != null) {
        await ref.read(chatServiceProvider).sendImageMessage(
              groupId: widget.group.id,
              imageUrl: result['url'],
              fileSizeBytes: result['fileSize'],
              senderId: currentUser.uid,
              senderName: currentUser.name,
              senderEmail: currentUser.email,
            );

        // Auto-scroll
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Add _sendVideoMessage method
  Future<void> _sendVideoMessage(String videoPath) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    // Show upload dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Uploading video...'),
          ],
        ),
      ),
    );

    try {
      final result = await _mediaService.uploadVideo(
        filePath: videoPath,
        groupId: widget.group.id,
        senderId: currentUser.uid,
      );

      if (mounted) Navigator.pop(context);

      if (result != null) {
        await ref.read(chatServiceProvider).sendVideoMessage(
              groupId: widget.group.id,
              videoUrl: result['url'],
              fileSizeBytes: result['fileSize'],
              thumbnailUrl: result['thumbnailUrl'],
              senderId: currentUser.uid,
              senderName: currentUser.name,
              senderEmail: currentUser.email,
            );

        // Auto-scroll
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pickPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildStyledSnackBar('PDF picker - Coming soon!', Icons.picture_as_pdf),
    );
  }

  void _createLeadInGroup() {
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Only admins can create leads in groups'),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateLeadInGroupScreen(group: widget.group),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  SnackBar _buildStyledSnackBar(String message, IconData icon) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    );
  }

  String _safeInitial(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  String _safeDisplayName(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'User';
  }

  Future<void> _showAssignSODialog(LeadPool lead) async {
    // --- quick helpers ---
    String _norm(String? s) => (s ?? '').trim().toLowerCase();
    bool _isSalesUser(Map<String, String?> u) {
      final role = _norm(u['role']);
      final team = _norm(u['team']);
      final dept = _norm(u['department']);
      final title = _norm(u['title']);
      final isSalesFlag = _norm(u['isSales']) == 'true';
      return isSalesFlag ||
          role == 'sales' ||
          team == 'sales' ||
          dept == 'sales' ||
          title.contains('sales');
    }

    final currentUser = ref.read(currentUserProvider).value;
    final chatService = ref.read(chatServiceProvider);
    final leadService = ref.read(leadServiceProvider);
    final rootContext = context;

    final canAssign =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;
    if (!canAssign) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can assign leads'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (lead.groupId != widget.group.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lead.groupId == null
                ? 'This lead is not associated with any group'
                : 'This lead belongs to a different group',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    try {
      final users = await chatService.getAllUsers();
      final groupMemberIds = widget.group.members.map((m) => m.uid).toSet();

      // SALES ONLY
      final salesMembers = users
          .where((u) => groupMemberIds.contains((u['uid'] ?? '').trim()))
          .where((u) => _isSalesUser(u as Map<String, String?>))
          .toList();

      if (salesMembers.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Sales members available in this group'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
        return;
      }

      if (!mounted) return;

      final screenH = MediaQuery.of(context).size.height;
      final listHeight =
          math.min(320.0, screenH * 0.5); // hard cap to avoid overflow

      showDialog(
        context: rootContext,
        builder: (dialogCtx) => AlertDialog(
          // keeps dialog compact and prevents intrinsic dimension issues
          scrollable: false,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.person_add, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lead.isUnassigned ? 'Assign Sales Officer' : 'Reassign SO',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),

          content: Column(
            mainAxisSize:
                MainAxisSize.min, // critical: no shrink-wrap ask to viewport
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lead summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person,
                          size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text(lead.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.group,
                          size: 14, color: AppTheme.mediumGrey),
                      const SizedBox(width: 8),
                      Text(widget.group.name,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.mediumGrey)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Sales Officer:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),

              // FIX: give the internal ListView a fixed height so it never asks for intrinsics
              SizedBox(
                height: listHeight,
                width: double.maxFinite,
                child: ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  itemCount: salesMembers.length,
                  itemBuilder: (context, index) {
                    final user = salesMembers[index] as Map<String, dynamic>;
                    final uid = (user['uid'] ?? '').toString().trim();
                    final isCurrent = lead.assignedTo == uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.primaryBlue.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? AppTheme.primaryBlue
                              : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        // avoid Hero in dialogs
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? AppTheme.primaryBlue
                              : AppTheme.primaryBlue.withOpacity(0.1),
                          child: Text(
                            _safeInitial(
                                user.map((k, v) => MapEntry(k, v?.toString()))),
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _safeDisplayName(
                              user.map((k, v) => MapEntry(k, v?.toString()))),
                          style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                        subtitle: Text((user['email'] ?? '').toString().trim()),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Current',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              )
                            : const Icon(Icons.arrow_forward_ios,
                                size: 16, color: AppTheme.mediumGrey),
                        onTap: () async {
                          Navigator.pop(dialogCtx);

                          // lightweight loader dialog (no intrinsic issues)
                          showDialog(
                            context: rootContext,
                            barrierDismissible: false,
                            builder: (_) => const Dialog(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );

                          try {
                            await leadService.assignSalesOfficer(
                              leadId: lead.uid,
                              soUid: uid,
                              soName: _safeDisplayName(user
                                  .map((k, v) => MapEntry(k, v?.toString()))),
                            );

                            if (mounted) {
                              Navigator.of(rootContext, rootNavigator: true)
                                  .pop();
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Assigned to ${_safeDisplayName(user.map((k, v) => MapEntry(k, v?.toString())))}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(rootContext, rootNavigator: true)
                                  .pop();
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          actions: [
            if (lead.isAssigned)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  showDialog(
                    context: rootContext,
                    barrierDismissible: false,
                    builder: (_) => const Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                  try {
                    await leadService.unassignSalesOfficer(lead.uid);
                    if (mounted) {
                      Navigator.of(rootContext, rootNavigator: true).pop();
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content: Text('SO unassigned'),
                          backgroundColor: AppTheme.warningAmber,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(rootContext, rootNavigator: true).pop();
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.errorRed),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.person_remove, size: 18),
                label: const Text('Unassign'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.group.id));
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;
    final unreadCount = ref.watch(unreadCountProvider).value ?? 0;
    final paginationState =
        ref.watch(chatPagingControllerProvider(widget.group.id));

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: AppTheme.lightBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInfoScreen(group: widget.group),
              ),
            );
          },
          child: Row(
            children: [
              Hero(
                tag: 'group_${widget.group.id}',
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: ClipOval(
                    child: widget.group.groupIcon != null &&
                            widget.group.groupIcon!.isNotEmpty
                        ? Image.network(
                            widget.group.groupIcon!,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                widget.group.name.isNotEmpty
                                    ? widget.group.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppTheme.lightBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              widget.group.name.isNotEmpty
                                  ? widget.group.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.lightBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.group.memberCount} members',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Notification Badge
          if (unreadCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
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
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),

          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Group info'),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Text('View notifications'),
              ),
            ],
            onSelected: (value) {
              if (value == 'info') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfoScreen(group: widget.group),
                  ),
                );
              } else if (value == 'notifications') {
                Navigator.pushNamed(context, '/notifications');
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Container(color: Colors.grey[300]),
            ),
          ),

          Column(
            children: [
              // Messages List

              Expanded(
                child: _buildMessagesList(paginationState, currentUser),
              ),

              // In your chat_screen.dart, replace the "Message Input" section with:

// Attachment Menu with Animation
              SizeTransition(
                sizeFactor: _attachmentMenuAnimation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (isAdmin) ...[
                          _buildAttachmentButton(
                            icon: Icons.add_circle,
                            label: 'Create Lead',
                            color: AppTheme.successGreen,
                            onTap: _createLeadInGroup,
                          ),
                          const SizedBox(width: 12),
                        ],
                        _buildAttachmentButton(
                          icon: Icons.photo_camera,
                          label: 'Camera',
                          color: const Color(0xFFE91E63),
                          onTap: _pickImage,
                        ),
                        const SizedBox(width: 12),
                        _buildAttachmentButton(
                          icon: Icons.image,
                          label: 'Gallery',
                          color: const Color(0xFF9C27B0),
                          onTap: _pickImage,
                        ),
                        const SizedBox(width: 12),
                        _buildAttachmentButton(
                          icon: Icons.videocam,
                          label: 'Video',
                          color: const Color(0xFFFF5722),
                          onTap: _pickVideo,
                        ),
                        const SizedBox(width: 12),
                        _buildAttachmentButton(
                          icon: Icons.picture_as_pdf,
                          label: 'Document',
                          color: const Color(0xFF2196F3),
                          onTap: _pickPdf,
                        ),
                        const SizedBox(width: 12),
                        _buildAttachmentButton(
                          icon: Icons.location_on,
                          label: 'Location',
                          color: const Color(0xFF4CAF50),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildStyledSnackBar(
                                  'Share location - Coming soon!',
                                  Icons.location_on),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

// Enhanced ChatInputBar with Attachment Button
              ChatInputBar(
                groupId: widget.group.id,
                showAttachmentMenu: _showAttachmentMenu,
                onToggleAttachments: _showAttachmentOptions,
                onSendText: (text) async {
                  final currentUser = ref.read(currentUserProvider).value;
                  if (currentUser == null) return;

                  final chatService = ref.read(chatServiceProvider);

                  try {
                    await chatService.sendTextMessage(
                      groupId: widget.group.id,
                      senderId: currentUser.uid,
                      senderName: currentUser.name,
                      senderEmail: currentUser.email,
                      content: text,
                    );

                    // Auto-scroll to bottom
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e.toString())),
                            ],
                          ),
                          backgroundColor: AppTheme.errorRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
                onSendVoice: (voiceUrl, duration, fileSize) async {
                  final currentUser = ref.read(currentUserProvider).value;
                  if (currentUser == null) return;

                  try {
                    await ref.read(chatServiceProvider).sendVoiceMessage(
                          groupId: widget.group.id,
                          voiceUrl: voiceUrl,
                          durationSeconds: duration,
                          fileSizeBytes: fileSize,
                          senderId: currentUser.uid,
                          senderName: currentUser.name,
                          senderEmail: currentUser.email,
                        );

                    // Auto-scroll to bottom
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.white),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text('Failed to send voice message')),
                            ],
                          ),
                          backgroundColor: AppTheme.errorRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'TODAY';
    } else if (messageDate == yesterday) {
      dateText = 'YESTERDAY';
    } else {
      dateText = DateFormat('MMMM dd, yyyy').format(date).toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCF8C6).withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        dateText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.lightBlue,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAnimatedMessage(ChatMessage message, bool isMe, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildMessageBubble(message, isMe),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF25D366).withOpacity(0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 2),
                        bottomRight: Radius.circular(isMe ? 2 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe && message.type == MessageType.text)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message.senderName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.lightBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _buildMessageContent(message, isMe),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? const Color(0xFF075E54).withOpacity(0.6)
                                    : AppTheme.mediumGrey,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.done_all,
                                size: 14,
                                color: Color(0xFF4FC3F7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    final textColor = isMe ? const Color(0xFF075E54) : const Color(0xFF303030);

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            color: textColor,
            height: 1.3,
          ),
        );
      case MessageType.voice:
        return VoiceMessageBubble(
          voiceUrl: message.fileUrl!,
          durationSeconds: message.voiceDurationSeconds ?? 0,
          isSentByMe: isMe,
        );

      case MessageType.image:
        return ImageMessageBubble(
          imageUrl: message.fileUrl!,
          caption: message.content != '📷 Photo' ? message.content : null,
          isSentByMe: isMe,
        );

      case MessageType.video:
        return VideoMessageBubble(
          videoUrl: message.fileUrl!,
          thumbnailUrl: message.thumbnailUrl,
          caption: message.content != '🎥 Video' ? message.content : null,
          isSentByMe: isMe,
        );

      case MessageType.lead:
        final leadId = message.leadId ?? '';
        if (leadId.isEmpty) {
          return Text(
            'Lead info unavailable',
            style: TextStyle(fontSize: 14, color: textColor),
          );
        }

        final leadAsync = ref.watch(leadStreamProvider(leadId));
        final currentUser = ref.read(currentUserProvider).value;
        final canAssign =
            currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

        return leadAsync.when(
          loading: () => Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading lead...',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ],
          ),
          error: (err, _) => Text(
            'Error loading lead',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.errorRed,
            ),
          ),
          data: (lead) {
            final leadName = lead?.name ?? message.leadName ?? 'Lead';
            final isUnassigned = lead?.isUnassigned ?? true;

            return GestureDetector(
              onTap: () {
                if (lead != null && canAssign) {
                  _showAssignSODialog(lead);
                } else if (!canAssign) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Only admins can assign leads'),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.errorRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUnassigned
                        ? [
                            AppTheme.warningAmber.withOpacity(0.2),
                            AppTheme.warningAmber.withOpacity(0.1),
                          ]
                        : [
                            AppTheme.successGreen.withOpacity(0.2),
                            AppTheme.successGreen.withOpacity(0.1),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnassigned
                        ? AppTheme.warningAmber.withOpacity(0.4)
                        : AppTheme.successGreen.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isUnassigned
                                ? AppTheme.warningAmber.withOpacity(0.2)
                                : AppTheme.successGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: isUnassigned
                                ? AppTheme.warningAmber
                                : AppTheme.successGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leadName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              if (lead != null && lead.number.isNotEmpty)
                                Text(
                                  lead.number,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isUnassigned
                            ? AppTheme.warningAmber
                            : AppTheme.successGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUnassigned
                            ? '⚠️ UNASSIGNED'
                            : '✓ ${lead?.assignedToName ?? "Assigned"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (lead != null && lead.isAssigned)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SlaIndicator(lead: lead),
                      ),
                    if (canAssign)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '👆 Tap to ${isUnassigned ? "assign" : "reassign"}',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );

      default:
        return Text(
          message.content,
          style: TextStyle(fontSize: 15, color: textColor),
        );
    }
  }

  Widget _buildMessagesList(ChatPaginationState paginationState, currentUser) {
    final messages = paginationState.messages;

    if (!paginationState.isHeadLiveAttached && messages.isEmpty) {
      // Still loading initial messages
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lightBlue),
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: AppTheme.lightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start the conversation!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Newest at bottom
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: messages.length + (paginationState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top (end of list in reverse)
        if (index == messages.length) {
          return _buildLoadMoreIndicator(paginationState);
        }

        final message = messages[index];
        final isMe = message.senderId == currentUser?.uid;

        // Date separator logic
        bool showDateSeparator = false;
        if (index == messages.length - 1) {
          showDateSeparator = true;
        } else {
          final nextMessage = messages[index + 1];
          final currentDate = DateTime(
            message.timestamp.year,
            message.timestamp.month,
            message.timestamp.day,
          );
          final nextDate = DateTime(
            nextMessage.timestamp.year,
            nextMessage.timestamp.month,
            nextMessage.timestamp.day,
          );
          showDateSeparator = currentDate != nextDate;
        }

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.timestamp),
            _buildAnimatedMessage(message, isMe, index),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator(ChatPaginationState state) {
    if (state.isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lightBlue),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading older messages...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8C6).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.lightBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Beginning of conversation',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
