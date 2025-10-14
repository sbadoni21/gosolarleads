import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String type; // 'info', 'warning', 'urgent', 'celebration'
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<String> readBy;
  final String? imageUrl;
  final List<String> attachments;
  final bool isPinned;
  final Map<String, dynamic>? metadata;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.expiresAt,
    required this.readBy,
    this.imageUrl,
    required this.attachments,
    required this.isPinned,
    this.metadata,
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Notice(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'info',
      priority: data['priority'] ?? 'normal',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? 'Admin',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      imageUrl: data['imageUrl'],
      attachments: List<String>.from(data['attachments'] ?? []),
      isPinned: data['isPinned'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'priority': priority,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'attachments': attachments,
      'isPinned': isPinned,
      'metadata': metadata,
    };
  }

  bool isReadBy(String userId) => readBy.contains(userId);
  
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  
  bool get isUrgent => priority == 'urgent';

  String get icon {
    switch (type) {
      case 'info':
        return '📢';
      case 'warning':
        return '⚠️';
      case 'urgent':
        return '🚨';
      case 'celebration':
        return '🎉';
      default:
        return '📋';
    }
  }

  Notice copyWith({
    String? title,
    String? content,
    String? type,
    String? priority,
    DateTime? expiresAt,
    bool? isPinned,
    String? imageUrl,
    List<String>? attachments,
  }) {
    return Notice(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      readBy: readBy,
      imageUrl: imageUrl ?? this.imageUrl,
      attachments: attachments ?? this.attachments,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata,
    );
  }
}