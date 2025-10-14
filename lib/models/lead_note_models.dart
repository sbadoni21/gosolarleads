// lib/models/lead_note_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LeadComment {
  final String id;
  final String leadId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  LeadComment({
    required this.id,
    required this.leadId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'leadId': leadId,
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory LeadComment.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>)..putIfAbsent('createdAt', () => Timestamp.now());
    return LeadComment(
      id: d.id,
      leadId: m['leadId'] ?? '',
      authorUid: m['authorUid'] ?? '',
      authorName: m['authorName'] ?? '',
      text: m['text'] ?? '',
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }
}

class LeadReminder {
  final String id;
  final String leadId;
  final String ownerUid;       // SO
  final String ownerName;
  final String note;           // e.g. “Call the lead”
  final DateTime scheduledAt;  // when to remind
  final bool done;

  LeadReminder({
    required this.id,
    required this.leadId,
    required this.ownerUid,
    required this.ownerName,
    required this.note,
    required this.scheduledAt,
    required this.done,
  });

  Map<String, dynamic> toMap() => {
    'leadId': leadId,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'note': note,
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'done': done,
  };

  factory LeadReminder.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>);
    return LeadReminder(
      id: d.id,
      leadId: m['leadId'] ?? '',
      ownerUid: m['ownerUid'] ?? '',
      ownerName: m['ownerName'] ?? '',
      note: m['note'] ?? '',
      scheduledAt: (m['scheduledAt'] as Timestamp).toDate(),
      done: m['done'] ?? false,
    );
  }
}
