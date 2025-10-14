
// ============================================
// Model: CallRecord
// ============================================

import 'package:cloud_firestore/cloud_firestore.dart';

class CallRecord {
  final String id;
  final String leadId;
  final String leadName;
  final String phoneNumber;
  final String salesOfficerUid;
  final String salesOfficerName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration; // seconds
  final String status;
  final String? recordingUrl;
  final int? fileSizeBytes;
  final bool uploaded;

  CallRecord({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.phoneNumber,
    required this.salesOfficerUid,
    required this.salesOfficerName,
    this.startedAt,
    this.endedAt,
    this.duration,
    required this.status,
    this.recordingUrl,
    this.fileSizeBytes,
    required this.uploaded,
  });

  factory CallRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallRecord(
      id: doc.id,
      leadId: data['leadId'] ?? '',
      leadName: data['leadName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      salesOfficerUid: data['salesOfficerUid'] ?? '',
      salesOfficerName: data['salesOfficerName'] ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      duration: data['duration'] as int?,
      status: data['status'] ?? 'unknown',
      recordingUrl: data['recordingUrl'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      uploaded: data['uploaded'] ?? false,
    );
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final mins = duration! ~/ 60;
    final secs = duration! % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSizeBytes == null) return '--';
    final mb = fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
}
