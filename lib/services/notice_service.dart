import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/notice.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

final noticeServiceProvider = Provider<NoticeService>((ref) {
  return NoticeService();
});

final noticesStreamProvider = StreamProvider<List<Notice>>((ref) {
  return FirebaseFirestore.instance
      .collection('notices')
      .orderBy('isPinned', descending: true)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Notice.fromFirestore(doc))
        .where((notice) => !notice.isExpired)
        .toList();
  });
});

final unreadNoticesCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('notices')
      .where('readBy', whereNotIn: [[user.uid]])
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Notice.fromFirestore(doc))
          .where((notice) => !notice.isExpired)
          .length);
});

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Create a new notice (Admin only)
  Future<String> createNotice({
    required String title,
    required String content,
    required String type,
    required String priority,
    required String createdBy,
    required String createdByName,
    DateTime? expiresAt,
    String? imageUrl,
    List<String> attachments = const [],
    bool isPinned = false,
    bool sendNotification = true,
  }) async {
    try {
      final notice = {
        'title': title,
        'content': content,
        'type': type,
        'priority': priority,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'readBy': [],
        'imageUrl': imageUrl,
        'attachments': attachments,
        'isPinned': isPinned,
      };

      final docRef = await _firestore.collection('notices').add(notice);

      // Send push notification to all users
      if (sendNotification) {
        await _sendNoticeNotification(
          noticeId: docRef.id,
          title: title,
          content: content,
          type: type,
          priority: priority,
        );
      }

      return docRef.id;
    } catch (e) {
      throw 'Failed to create notice: ${e.toString()}';
    }
  }

  // Send notification via Cloud Function
  Future<void> _sendNoticeNotification({
    required String noticeId,
    required String title,
    required String content,
    required String type,
    required String priority,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendNoticeToAll');
      await callable.call({
        'noticeId': noticeId,
        'title': title,
        'content': content,
        'type': type,
        'priority': priority,
      });
    } catch (e) {
      print('Failed to send notice notification: $e');
    }
  }

  // Mark notice as read
  Future<void> markAsRead(String noticeId, String userId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw 'Failed to mark as read: ${e.toString()}';
    }
  }

  // Update notice (Admin only)
  Future<void> updateNotice(String noticeId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('notices').doc(noticeId).update(updates);
    } catch (e) {
      throw 'Failed to update notice: ${e.toString()}';
    }
  }

  // Delete notice (Admin only)
  Future<void> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).delete();
    } catch (e) {
      throw 'Failed to delete notice: ${e.toString()}';
    }
  }

  // Toggle pin
  Future<void> togglePin(String noticeId, bool isPinned) async {
    try {
      await _firestore.collection('notices').doc(noticeId).update({
        'isPinned': !isPinned,
      });
    } catch (e) {
      throw 'Failed to toggle pin: ${e.toString()}';
    }
  }

  // Get single notice
  Future<Notice?> getNotice(String noticeId) async {
    try {
      final doc = await _firestore.collection('notices').doc(noticeId).get();
      if (doc.exists) {
        return Notice.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get notice: ${e.toString()}';
    }
  }
}