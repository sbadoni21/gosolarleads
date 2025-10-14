// chat_pagination.dart (new file)
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/chat_models.dart';
import 'package:gosolarleads/providers/chat_provider.dart';

class ChatPaginationState {
  final List<ChatMessage> messages; // DESC (newest first)
  final List<DocumentSnapshot> pages; // raw docs to page further
  final bool isLoadingMore;
  final bool hasMore;
  final bool isHeadLiveAttached; // stream attached to the head page

  const ChatPaginationState({
    required this.messages,
    required this.pages,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isHeadLiveAttached,
  });

  ChatPaginationState copyWith({
    List<ChatMessage>? messages,
    List<DocumentSnapshot>? pages,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isHeadLiveAttached,
  }) {
    return ChatPaginationState(
      messages: messages ?? this.messages,
      pages: pages ?? this.pages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isHeadLiveAttached: isHeadLiveAttached ?? this.isHeadLiveAttached,
    );
  }

  static ChatPaginationState initial() => const ChatPaginationState(
        messages: [],
        pages: [],
        isLoadingMore: false,
        hasMore: true,
        isHeadLiveAttached: false,
      );
}

class ChatPaginationController extends StateNotifier<ChatPaginationState> {
  final Ref ref;
  final String groupId;
  final int pageSize;

  StreamSubscription<List<ChatMessage>>? _headSub;

  ChatPaginationController(this.ref, {required this.groupId, this.pageSize = 30})
      : super(ChatPaginationState.initial());

  @override
  void dispose() {
    _headSub?.cancel();
    super.dispose();
  }

  Future<void> loadInitial() async {
    // 1) attach live head stream
    _attachHeadStream();

    // 2) also fetch raw docs for pagination cursor bookkeeping
    final chatService = ref.read(chatServiceProvider);
    final page = await chatService.fetchMessagesPage(groupId: groupId, limit: pageSize);
    state = state.copyWith(
      pages: page.rawDocs,
      hasMore: page.rawDocs.length == pageSize,
    );
  }

void _attachHeadStream() {
  if (state.isHeadLiveAttached) return;
  final chatService = ref.read(chatServiceProvider);

  _headSub = chatService
      .watchLatestMessages(groupId: groupId, limit: pageSize)
      .listen((liveItems) {
    // Merge strategy: prioritize live items, then append older loaded items
    final liveIds = <String>{for (final m in liveItems) m.id};
    final merged = <ChatMessage>[];

    // Add all live items first (newest messages)
    merged.addAll(liveItems);

    // Add older messages that aren't in the live stream
    for (final m in state.messages) {
      if (!liveIds.contains(m.id)) {
        merged.add(m);
      }
    }

    state = state.copyWith(
      messages: merged,
      isHeadLiveAttached: true,
    );
  });
}
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      // The cursor for the next page is the last raw doc we've ever fetched
      // (from initial or from previous older pages). Because list is DESC,
      // startAfterDocument(lastDoc) fetches OLDER items.
      final lastDoc = state.pages.isEmpty ? null : state.pages.last;

      final chatService = ref.read(chatServiceProvider);
      final page = await chatService.fetchMessagesPage(
        groupId: groupId,
        startAfter: lastDoc,
        limit: pageSize,
      );

      if (page.rawDocs.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      // Append older page at the end (since DESC = newest first).
      final existingIds = {for (final m in state.messages) m.id};
      final newOnes = page.items.where((m) => !existingIds.contains(m.id)).toList();

      final newList = <ChatMessage>[];
      newList.addAll(state.messages);
      newList.addAll(newOnes);

      final newPages = <DocumentSnapshot>[];
      newPages.addAll(state.pages);
      newPages.addAll(page.rawDocs);

      state = state.copyWith(
        messages: newList,
        pages: newPages,
        isLoadingMore: false,
        hasMore: page.rawDocs.length == pageSize,
      );
    } catch (_) {
      // fail-soft: stop spinner but keep hasMore true so user can retry
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

// Provider for a controller instance per group
final chatPagingControllerProvider = StateNotifierProvider.family<ChatPaginationController, ChatPaginationState, String>(
  (ref, groupId) => ChatPaginationController(ref, groupId: groupId),
);
