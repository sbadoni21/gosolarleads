import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/chat_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

// ALL groups (no membership filter)
final allChatGroupsProvider = StreamProvider<List<ChatGroup>>((ref) {
  return FirebaseFirestore.instance
      .collection('chatGroups')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => ChatGroup.fromFirestore(doc)).toList());
});

final specificGroupProvider =
    StreamProvider.family<ChatGroup?, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('chatGroups')
      .doc(groupId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return ChatGroup.fromFirestore(doc);
  });
});

// FIXED: Now uses memberIds for efficient querying
final chatGroupsProvider = StreamProvider<List<ChatGroup>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);

  print('📡 Watching groups for user: ${user.uid}');

  return FirebaseFirestore.instance
      .collection('chatGroups')
      .where('memberIds', arrayContains: user.uid) // Now uses memberIds!
      .snapshots()
      .map((snap) {
    print('📊 Found ${snap.docs.length} groups for user');
    final groups = snap.docs.map((d) => ChatGroup.fromFirestore(d)).toList();
    groups.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return groups;
  });
});

// Stream of messages for a specific group
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('chatGroups')
      .doc(groupId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  });
});

// Chat service provider
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markMessagesAsRead({
    required String groupId,
    required String userId,
  }) async {
    try {
      final col = _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages');

      // Fetch a recent slice; filter in Dart to avoid illegal filter combos.
      // Tune the limit based on your chat volume.
      final snapshot =
          await col.orderBy('timestamp', descending: true).limit(200).get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      int updates = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final senderId = (data['senderId'] as String?) ?? '';
        final readByRaw = data['readBy'];
        final readBy = (readByRaw is List)
            ? readByRaw.cast<dynamic>().map((e) => e?.toString() ?? '').toList()
            : const <String>[];

        // Skip own messages
        if (senderId == userId) continue;

        // Skip if already read
        if (readBy.contains(userId)) continue;

        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
          'isRead': true, // optional if you keep this flag
        });

        updates++;

        // Firestore batch limit safety (max 500)
        if (updates == 490) {
          await batch.commit();
          updates = 0;
        }
      }

      if (updates > 0) {
        await batch.commit();
      }

      print('✅ Marked $updates messages as read');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

// lib/providers/chat_provider.dart (or your chat service file)
// only the create method signature & write shown
  Future<void> createGroup({
    required String name,
    required String description,
    required String state,
    required String createdBy,
    required List<String> memberIds,
    required List<ChatMember> members,
    List<String> districts = const [], // NEW
    String? groupIcon,
  }) async {
    final doc = FirebaseFirestore.instance.collection('chatGroups').doc();
    final now = DateTime.now();

    // keep 'workLocation' as first district for compatibility
    final workLocation = districts.isNotEmpty ? districts.first : '';

    await doc.set({
      'name': name,
      'description': description,
      'state': state,
      'districts': districts,
      'workLocation': workLocation, // legacy
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'members': members.map((m) => m.toMap()).toList(),
      'lastMessage': null,
      'lastMessageTime': null,
      'groupIcon': groupIcon,
      'memberIds': memberIds, // NEW FIELD
    });
  }

  // Send a text message
  Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderEmail,
    required String content,
  }) async {
    try {
      final messageData = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.text,
        content: content,
        timestamp: DateTime.now(),
      ).toMap();

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      // Update group's last message
      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send message: ${e.toString()}';
    }
  }

// lib/services/chat_service.dart

Future<void> updateUserPresence({
  required String userId,
  String? activeGroupId,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('user_presence')
        .doc(userId)
        .set({
      'activeGroupId': activeGroupId,
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': activeGroupId != null,
    }, SetOptions(merge: true));
    
    print('✅ Presence updated: activeGroupId=$activeGroupId');
  } catch (e) {
    print('❌ Failed to update presence: $e');
  }
}
  // Send a PDF message
  Future<void> sendPdfMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderEmail,
    required String fileUrl,
    required String fileName,
    required int fileSizeBytes,
  }) async {
    try {
      final messageData = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.pdf,
        content: fileName,
        timestamp: DateTime.now(),
        fileUrl: fileUrl,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      ).toMap();

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': '📄 Document',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send PDF: ${e.toString()}';
    }
  }

  Future<({List<ChatMessage> items, List<DocumentSnapshot> rawDocs})>
      fetchMessagesPage({
    required String groupId,
    DocumentSnapshot? startAfter,
    int limit = 30,
  }) async {
    Query query = _firestore
        .collection('chatGroups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final items = snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList();
    return (items: items, rawDocs: snap.docs);
  }

  Stream<List<ChatMessage>> watchLatestMessages({
    required String groupId,
    int limit = 30,
  }) {
    return _firestore
        .collection('chatGroups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  // Send image message
  Future<void> sendImageMessage({
    required String groupId,
    required String imageUrl,
    required int fileSizeBytes,
    required String senderId,
    required String senderName,
    required String senderEmail,
    String? caption,
  }) async {
    try {
      final message = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.image,
        content: caption ?? '📷 Photo',
        timestamp: DateTime.now(),
        fileUrl: imageUrl,
        fileName: imageUrl.split('/').last,
        fileSizeBytes: fileSizeBytes,
      );

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(message.toMap());

      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': caption ?? '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Image message sent successfully');
    } catch (e) {
      print('❌ Error sending image message: $e');
      rethrow;
    }
  }

  // Send video message
  Future<void> sendVideoMessage({
    required String groupId,
    required String videoUrl,
    required int fileSizeBytes,
    required String senderId,
    required String senderName,
    required String senderEmail,
    String? thumbnailUrl,
    int? durationSeconds,
    String? caption,
  }) async {
    try {
      final message = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.video,
        content: caption ?? '🎥 Video',
        timestamp: DateTime.now(),
        fileUrl: videoUrl,
        fileName: videoUrl.split('/').last,
        fileSizeBytes: fileSizeBytes,
        thumbnailUrl: thumbnailUrl,
        videoDurationSeconds: durationSeconds,
      );

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(message.toMap());

      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': caption ?? '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Video message sent successfully');
    } catch (e) {
      print('❌ Error sending video message: $e');
      rethrow;
    }
  }

  Future<void> sendVoiceMessage({
    required String groupId,
    required String voiceUrl,
    required int durationSeconds,
    required int fileSizeBytes,
    required String senderId,
    required String senderName,
    required String senderEmail,
  }) async {
    try {
      final message = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.voice,
        content: 'Voice message',
        timestamp: DateTime.now(),
        fileUrl: voiceUrl,
        fileName: voiceUrl.split('/').last,
        fileSizeBytes: fileSizeBytes,
        voiceDurationSeconds: durationSeconds,
      );

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(message.toMap());

      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': 'Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Voice message sent successfully');
    } catch (e) {
      print('❌ Error sending voice message: $e');
      rethrow;
    }
  }

  // Send a lead message
  Future<void> sendLeadMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderEmail,
    required String leadId,
    required String leadName,
    String? message,
  }) async {
    try {
      final messageData = ChatMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        type: MessageType.lead,
        content: message ?? 'Shared a lead',
        timestamp: DateTime.now(),
        leadId: leadId,
        leadName: leadName,
      ).toMap();

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chatGroups').doc(groupId).update({
        'lastMessage': '👤 Lead: $leadName',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send lead: ${e.toString()}';
    }
  }

  // UPDATED: Add member to group (updates both members and memberIds)
  Future<void> addMemberToGroup({
    required String groupId,
    required ChatMember member,
  }) async {
    print('➕ Adding member to group: ${member.name} (${member.uid})');

    try {
      await _firestore.collection('chatGroups').doc(groupId).update({
        'members':
            FieldValue.arrayUnion([member.toMap()]), // Full member object
        'memberIds':
            FieldValue.arrayUnion([member.uid]), // 🔥 Also add UID to memberIds
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Member added successfully');
    } catch (e) {
      print('❌ Failed to add member: $e');
      throw 'Failed to add member: ${e.toString()}';
    }
  }

  // UPDATED: Remove member from group (updates both members and memberIds)
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberUid,
  }) async {
    print('➖ Removing member from group: $memberUid');

    try {
      // Get the current group data
      final groupDoc =
          await _firestore.collection('chatGroups').doc(groupId).get();

      if (!groupDoc.exists) {
        throw 'Group not found';
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;

      // Get current members array
      final members = (groupData['members'] as List?)
              ?.map((m) => ChatMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [];

      // Remove the member
      members.removeWhere((m) => m.uid == memberUid);

      print('👥 Remaining members: ${members.length}');

      // Update both members and memberIds
      await _firestore.collection('chatGroups').doc(groupId).update({
        'members':
            members.map((m) => m.toMap()).toList(), // Updated members array
        'memberIds':
            FieldValue.arrayRemove([memberUid]), // 🔥 Remove UID from memberIds
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Member removed successfully');
    } catch (e) {
      print('❌ Failed to remove member: $e');
      throw 'Failed to remove member: ${e.toString()}';
    }
  }

  // Post system event
  Future<void> postSystemEvent({
    required String groupId,
    required ChatSystemEvent event,
    required MessageType messageType,
    Map<String, dynamic>? meta,
  }) async {
    final now = DateTime.now();
    final content = switch (event) {
      ChatSystemEvent.leadAssigned =>
        "Lead '${meta?['leadName'] ?? ''}' assigned to ${meta?['assignedToName'] ?? 'SO'}",
      ChatSystemEvent.leadUnassigned =>
        "Lead '${meta?['leadName'] ?? ''}' unassigned",
      ChatSystemEvent.registrationCompleted =>
        "Registration completed for '${meta?['leadName'] ?? ''}'",
      ChatSystemEvent.installationCompleted =>
        "Installation completed for '${meta?['leadName'] ?? ''}'",
    };

    final msg = ChatMessage(
      id: '',
      groupId: groupId,
      senderId: 'system',
      senderName: 'System',
      senderEmail: '',
      type: messageType,
      content: content,
      timestamp: now,
    ).toMap();

    await _firestore
        .collection('chatGroups')
        .doc(groupId)
        .collection('messages')
        .add(msg);

    await _firestore.collection('chatGroups').doc(groupId).update({
      'lastMessage': content,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update group details
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? workLocation,
    String? state,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (workLocation != null) updates['workLocation'] = workLocation;
      if (state != null) updates['state'] = state;

      await _firestore.collection('chatGroups').doc(groupId).update(updates);
    } catch (e) {
      throw 'Failed to update group: ${e.toString()}';
    }
  }

  // Delete group
  Future<void> deleteGroup(String groupId) async {
    print('🗑️ Deleting group: $groupId');

    try {
      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .get();

      print('🗑️ Deleting ${messagesSnapshot.docs.length} messages...');

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the group (this will also remove memberIds)
      await _firestore.collection('chatGroups').doc(groupId).delete();

      print('✅ Group deleted successfully');
    } catch (e) {
      print('❌ Failed to delete group: $e');
      throw 'Failed to delete group: ${e.toString()}';
    }
  }

  // Get all users (for adding to group)
  Future<List<Map<String, String>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, String>{
          'uid': (data['uid'] ?? '') as String,
          'name': (data['name'] ?? '') as String,
          'email': (data['email'] ?? '') as String,
          'role': (data['role'] ?? '') as String,
        };
      }).toList();
    } catch (e) {
      throw 'Failed to get users: ${e.toString()}';
    }
  }
}
// Add this to your chat_provider.dart or create a separate migration file

/// Run this ONCE to migrate existing groups to have memberIds field
Future<void> migrateGroupsToMemberIds() async {
  print('🔄 ========== STARTING GROUP MIGRATION ==========');

  try {
    final firestore = FirebaseFirestore.instance;

    // Get all chat groups
    final groupsSnapshot = await firestore.collection('chatGroups').get();

    print('📊 Found ${groupsSnapshot.docs.length} groups to migrate');

    final batch = firestore.batch();
    int migratedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var doc in groupsSnapshot.docs) {
      try {
        final data = doc.data();
        final groupId = doc.id;
        final groupName = data['name'] ?? 'Unnamed';

        // Check if memberIds already exists
        if (data.containsKey('memberIds')) {
          print('⏭️ Skipping ${groupName} - already has memberIds');
          skippedCount++;
          continue;
        }

        // Extract members array
        final members = data['members'];

        if (members == null || members is! List || members.isEmpty) {
          print('⚠️ Skipping ${groupName} - no members found');
          skippedCount++;
          continue;
        }

        // Extract UIDs from members
        final memberIds = <String>[];
        for (var member in members) {
          if (member is Map<String, dynamic>) {
            final uid = member['uid'];
            if (uid != null && uid is String && uid.isNotEmpty) {
              memberIds.add(uid);
            }
          }
        }

        if (memberIds.isEmpty) {
          print('⚠️ Skipping ${groupName} - no valid UIDs found');
          errorCount++;
          continue;
        }

        // Add memberIds field
        batch.update(doc.reference, {
          'memberIds': memberIds,
        });

        print('✓ Migrated: $groupName (${memberIds.length} members)');
        print('  Member IDs: $memberIds');
        migratedCount++;
      } catch (e) {
        print('❌ Error migrating group ${doc.id}: $e');
        errorCount++;
      }
    }

    // Commit all updates
    if (migratedCount > 0) {
      print('\n💾 Committing changes...');
      await batch.commit();
      print('✅ Batch committed successfully');
    }

    print('\n🎉 ========== MIGRATION COMPLETE ==========');
    print('✅ Migrated: $migratedCount groups');
    print('⏭️ Skipped: $skippedCount groups');
    print('❌ Errors: $errorCount groups');
    print('📊 Total: ${groupsSnapshot.docs.length} groups');
  } catch (e, stackTrace) {
    print('❌ Migration failed: $e');
    print('📍 Stack trace: $stackTrace');
    rethrow;
  }
}
