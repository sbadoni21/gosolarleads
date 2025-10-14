import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String audience; // 'user', 'group', 'all', 'admin'
  final String? userId;
  final String? groupId;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic> data;
  final String priority; // 'normal', 'high'
  final DateTime createdAt;
  final List<String> readBy;
  final String? actionUrl;
  final String category;
  final String? sound;
  final DateTime? expiresAt;
  final String? dedupeKey;

  AppNotification({
    required this.id,
    required this.type,
    required this.audience,
    this.userId,
    this.groupId,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.data,
    required this.priority,
    required this.createdAt,
    required this.readBy,
    this.actionUrl,
    required this.category,
    this.sound,
    this.expiresAt,
    this.dedupeKey,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? '',
      audience: data['audience'] ?? 'user',
      userId: data['userId'],
      groupId: data['groupId'],
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      data: _parseData(data['data']),
      priority: data['priority'] ?? 'normal',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
      actionUrl: data['actionUrl'],
      category: data['category'] ?? data['type'] ?? 'default',
      sound: data['sound'],
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      dedupeKey: data['dedupeKey'],
    );
  }

  static Map<String, dynamic> _parseData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  bool isReadBy(String userId) => readBy.contains(userId);
  
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  
  bool get isHighPriority => priority == 'high';
  
  // Get icon based on notification type
  String get icon {
    switch (type) {
      case 'lead_created':
      case 'lead_created_location':
        return '📍';
      case 'lead_assigned':
        return '👤';
      case 'lead_unassigned':
        return '⚠️';
      case 'sla_warning':
        return '⏰';
      case 'sla_breach':
        return '🚨';
      case 'registration_completed':
        return '🎉';
      case 'installation_completed':
        return '🎊';
      case 'installation_submitted': return '🛠️';
      case 'group_message':
        return '💬';
      case 'daily_digest':
        return '📊';
      default:
        return '🔔';
    }
  }
}

// Notification type constants
class NotificationType {
  static const String leadCreated = 'lead_created';
  static const String leadCreatedLocation = 'lead_created_location';
  static const String leadAssigned = 'lead_assigned';
  static const String leadUnassigned = 'lead_unassigned';
  static const String slaWarning = 'sla_warning';
    static const String surveySubmitted = 'survey_submitted';

  static const String slaBreach = 'sla_breach';
  static const String registrationCompleted = 'registration_completed';
  static const String installationCompleted = 'installation_completed';
  static const String groupMessage = 'group_message';
  static const String dailyDigest = 'daily_digest';
    static const String installationSubmitted = 'installation_submitted';

}

// Notification category constants
class NotificationCategory {
  static const String locationLeads = 'location_leads';
  static const String leadUpdates = 'lead_updates';
  static const String leadAssignments = 'lead_assignments';
  static const String leadMilestones = 'lead_milestones';
  static const String slaWarnings = 'sla_warnings';
  static const String slaBreach = 'sla_breach';
  static const String chatMessages = 'chat_messages';
  static const String adminAlerts = 'admin_alerts';
  static const String adminCritical = 'admin_critical';
  static const String dailyDigest = 'daily_digest';
}