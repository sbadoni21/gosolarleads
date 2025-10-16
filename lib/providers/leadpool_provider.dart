import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/lead_note_models.dart';
import 'package:gosolarleads/models/offer.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

final leadStreamProvider =
    StreamProvider.family<LeadPool?, String>((ref, leadId) {
  return ref.read(leadServiceProvider).watchLeadById(leadId);
});
// Add this near the top with other providers
final leadStatisticsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(leadServiceProvider).getLeadStatistics();
});
final leadCommentsProvider =
    StreamProvider.family<List<LeadComment>, String>((ref, leadId) {
  return ref.read(leadServiceProvider).watchComments(leadId);
});

final leadRemindersProvider =
    StreamProvider.family<List<LeadReminder>, String>((ref, leadId) {
  return ref.read(leadServiceProvider).watchReminders(leadId);
});
final myAssignedLeadsStreamProvider = StreamProvider<List<LeadPool>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('leadPool')
      .where('assignedTo', isEqualTo: user.uid)
      .orderBy('createdTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => LeadPool.fromFirestore(d)).toList());
});

// Stream of all leads
final allLeadsProvider = StreamProvider<List<LeadPool>>((ref) {
  return FirebaseFirestore.instance
      .collection('leadPool')
      .orderBy('createdTime', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => LeadPool.fromFirestore(doc)).toList();
  });
});

// Stream of leads created by current user
final myLeadsProvider = StreamProvider<List<LeadPool>>((ref) {
  final user = ref.watch(currentUserProvider).value;

  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('leadPool')
      .where('createdBy', isEqualTo: user.email)
      .orderBy('createdTime', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => LeadPool.fromFirestore(doc)).toList();
  });
});

// Stream of leads by status
final leadsByStatusProvider =
    StreamProvider.family<List<LeadPool>, String>((ref, status) {
  return FirebaseFirestore.instance
      .collection('leadPool')
      .where('status', isEqualTo: status)
      .orderBy('createdTime', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => LeadPool.fromFirestore(doc)).toList();
  });
});

// Lead service provider
final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService();
});

class LeadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addLead(LeadPool lead) async {
    try {
      final docRef = _firestore.collection('leadPool').doc(lead.uid);

      // Optional: prevent accidental overwrite if the uid already exists
      final exists = (await docRef.get()).exists;
      if (exists) {
        throw 'A lead with id ${lead.uid} already exists.';
      }

      await docRef.set(lead.toMap(), SetOptions(merge: false));
      return docRef.id; // == lead.uid
    } catch (e) {
      throw 'Failed to add lead: ${e.toString()}';
    }
  }

  // Update a lead
  Future<void> updateLead(String leadId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update(updates);
    } catch (e) {
      throw 'Failed to update lead: ${e.toString()}';
    }
  }

  // Delete a lead
  Future<void> deleteLead(String leadId) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).delete();
    } catch (e) {
      throw 'Failed to delete lead: ${e.toString()}';
    }
  }

  // Get a single lead by ID
  Future<LeadPool?> getLeadById(String leadId) async {
    try {
      final doc = await _firestore.collection('leadPool').doc(leadId).get();
      if (doc.exists) {
        return LeadPool.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get lead: ${e.toString()}';
    }
  }

  // Update lead status
  Future<void> updateLeadStatus(String leadId, String status) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'status': status,
      });
    } catch (e) {
      throw 'Failed to update status: ${e.toString()}';
    }
  }

  // Update survey status
  Future<void> updateSurveyStatus(String leadId, bool surveyStatus) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'surveyStatus': surveyStatus,
      });
    } catch (e) {
      throw 'Failed to update survey status: ${e.toString()}';
    }
  } // Add to LeadService class

  Future<void> saveSlaBreachReason({
    required String leadId,
    required String slaType, // 'registration' or 'installation'
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final fieldPrefix =
        slaType == 'registration' ? 'registration' : 'installation';

    await FirebaseFirestore.instance.collection('leadPool').doc(leadId).update({
      '${fieldPrefix}SlaBreachReason': reason,
      '${fieldPrefix}SlaBreachRecordedAt': FieldValue.serverTimestamp(),
      '${fieldPrefix}SlaBreachRecordedBy': recordedByName,
    });

    // Also add a comment for audit trail
    await addComment(
      leadId: leadId,
      authorUid: recordedByUid,
      authorName: recordedByName,
      text: '🚨 SLA Breach Reason (${slaType.toUpperCase()}): $reason',
    );
  }

  // Update account status
  Future<void> updateAccountStatus(String leadId, bool accountStatus) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'accountStatus': accountStatus,
      });
    } catch (e) {
      throw 'Failed to update account status: ${e.toString()}';
    }
  }

  // Update offer
  Future<void> updateOffer(String leadId, Offer offer) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'offer': offer.toMap(),
      });
    } catch (e) {
      throw 'Failed to update offer: ${e.toString()}';
    }
  }

  // Watch a lead by ID
  Stream<LeadPool?> watchLeadById(String id) {
    return _firestore.collection('leadPool').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LeadPool.fromFirestore(doc);
    });
  }

  Future<void> startRegistrationSla(String leadId) async {
    try {
      final now = DateTime.now();
      final registrationSlaEnd = now.add(const Duration(days: 3));

      await _firestore.collection('leadPool').doc(leadId).update({
        'registrationSlaStartDate': Timestamp.fromDate(now),
        'registrationSlaEndDate': Timestamp.fromDate(registrationSlaEnd),
        'registrationCompletedAt': null,
        'installationSlaStartDate': null,
        'installationSlaEndDate': null,
        'installationCompletedAt': null,
      });
    } catch (e) {
      throw 'Failed to start registration SLA: ${e.toString()}';
    }
  }
// IN: lib/providers/leadpool_provider.dart (append inside LeadService)

  Future<void> addComment({
    required String leadId,
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    final col =
        _firestore.collection('leadPool').doc(leadId).collection('comments');
    await col.add({
      'leadId': leadId,
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text.trim(),
      'createdAt': Timestamp.now(),
    });
  }

  /// Creates a reminder and also drops a notification record for your existing feed.
  Future<void> addReminder({
    required String leadId,
    required String ownerUid,
    required String ownerName,
    required String note,
    required DateTime scheduledAt,
  }) async {
    final batch = _firestore.batch();
    final rDoc = _firestore
        .collection('leadPool')
        .doc(leadId)
        .collection('reminders')
        .doc();
    batch.set(rDoc, {
      'leadId': leadId,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'note': note.trim(),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'done': false,
      'createdAt': Timestamp.now(),
    });

    // optional: user-facing notification doc your app already uses
    final notif = _firestore.collection('notifications').doc();
    batch.set(notif, {
      'userId': ownerUid,
      'title': 'Lead Reminder',
      'body': '$note • ${scheduledAt.toLocal()}',
      'leadId': leadId,
      'type': 'lead_reminder',
      'createdAt': Timestamp.now(),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'read': false,
    });

    await batch.commit();
  }

  Future<void> markReminderDone(String leadId, String reminderId, bool done) {
    return _firestore
        .collection('leadPool')
        .doc(leadId)
        .collection('reminders')
        .doc(reminderId)
        .update({'done': done});
  }

  /// Update status; if rejected, store reason/metadata.
  Future<void> updateStatusWithReason({
    required String leadId,
    required String status,
    String? reason,
    String? byUid,
    String? byName,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (status.trim().toLowerCase() == 'rejected') {
      data.addAll({
        'rejectionReason': (reason ?? '').trim(),
        'rejectedByUid': byUid,
        'rejectedByName': byName,
        'rejectedAt': Timestamp.now(),
      });
    } else {
      // clear old rejection fields to avoid confusion
      data.addAll({
        'rejectionReason': FieldValue.delete(),
        'rejectedByUid': FieldValue.delete(),
        'rejectedByName': FieldValue.delete(),
        'rejectedAt': FieldValue.delete(),
      });
    }
    await _firestore.collection('leadPool').doc(leadId).update(data);
  }

  /// Toggle boolean milestones and optionally attach proof URL(s).
  Future<void> updateMilestones({
    required String leadId,
    bool? registrationDone,
    bool? loanProcessDone,
    bool? installationStarted,
    String? proofUrl, // optional single proof; you can extend to a list
    String? proofLabel,
    String? byUid,
    String? byName,
  }) async {
    final updates = <String, dynamic>{};
    if (registrationDone != null)
      updates['registrationDone'] = registrationDone;
    if (loanProcessDone != null) updates['loanProcessDone'] = loanProcessDone;
    if (installationStarted != null)
      updates['installationStarted'] = installationStarted;

    // store proof as subcollection item for audit/history
    if (proofUrl != null && proofUrl.isNotEmpty) {
      final proofDoc = _firestore
          .collection('leadPool')
          .doc(leadId)
          .collection('proofs')
          .doc();
      await _firestore.runTransaction((tx) async {
        tx.update(_firestore.collection('leadPool').doc(leadId), updates);
        tx.set(proofDoc, {
          'url': proofUrl,
          'label': proofLabel ?? 'Proof',
          'uploadedByUid': byUid,
          'uploadedByName': byName,
          'createdAt': Timestamp.now(),
        });
      });
      return;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('leadPool').doc(leadId).update(updates);
    }
  }

  /// Streams
  Stream<List<LeadComment>> watchComments(String leadId) {
    return _firestore
        .collection('leadPool')
        .doc(leadId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => LeadComment.fromDoc(d)).toList());
  }

  Stream<List<LeadReminder>> watchReminders(String leadId) {
    return _firestore
        .collection('leadPool')
        .doc(leadId)
        .collection('reminders')
        .orderBy('scheduledAt')
        .snapshots()
        .map((s) => s.docs.map((d) => LeadReminder.fromDoc(d)).toList());
  }

  /// Assign a sales officer to a lead and start Registration SLA (30 days)
  Future<void> assignSalesOfficer({
    required String leadId,
    required String soUid,
    required String soName,
  }) async {
    final now = DateTime.now();
    final registrationSlaEnd = now.add(const Duration(days: 3));

    await _firestore.collection('leadPool').doc(leadId).update({
      'assignedTo': soUid,
      'assignedToName': soName,
      'assignedAt': Timestamp.fromDate(now),
      'status': 'assigned',
      // Start Registration SLA
      'registrationSlaStartDate': Timestamp.fromDate(now),
      'registrationSlaEndDate': Timestamp.fromDate(registrationSlaEnd),
      'registrationCompletedAt': null,
      // Clear installation SLA (will be set when registration completes)
      'installationSlaStartDate': null,
      'installationSlaEndDate': null,
      'installationCompletedAt': null,
    });
  }

  /// Unassign a sales officer from a lead and clear all SLAs
  Future<void> unassignSalesOfficer(String leadId) async {
    await _firestore.collection('leadPool').doc(leadId).update({
      'assignedTo': null,
      'assignedToName': null,
      'assignedAt': null,
      'status': 'unassigned',
      // Clear all SLAs
      'registrationSlaStartDate': null,
      'registrationSlaEndDate': null,
      'registrationCompletedAt': null,
      'installationSlaStartDate': null,
      'installationSlaEndDate': null,
      'installationCompletedAt': null,
    });
  }

  /// Mark registration as complete and start Installation SLA (30 days)
  Future<void> completeRegistration(String leadId) async {
    final now = DateTime.now();
    final installationSlaEnd = now.add(const Duration(days: 30));

    await _firestore.collection('leadPool').doc(leadId).update({
      'registrationCompletedAt': Timestamp.fromDate(now),
      // Start Installation SLA
      'installationSlaStartDate': Timestamp.fromDate(now),
      'installationSlaEndDate': Timestamp.fromDate(installationSlaEnd),
      'status': 'registration_complete',
    });
  }

// In LeadService class
  Future<void> completeInstallation(String leadId) async {
    final now = DateTime.now();

    await _firestore.collection('leadPool').doc(leadId).update({
      'installationCompletedAt': Timestamp.fromDate(now),
      'status':
          'completed', // Changed from 'installation_complete' to 'completed'
      'closedAt': Timestamp.fromDate(now), // Optional: add a closed timestamp
      'isClosed': true, // Optional: add a boolean flag for easier querying
    });
  }

  /// Get all leads with active breached SLAs
  Future<List<LeadPool>> getBreachedSlaLeads() async {
    final snapshot = await _firestore
        .collection('leadPool')
        .where('assignedTo', isNull: false)
        .get();

    final leads = snapshot.docs
        .map((doc) => LeadPool.fromFirestore(doc))
        .where((lead) =>
            lead.isRegistrationSlaBreached || lead.isInstallationSlaBreached)
        .toList();

    return leads;
  }

  /// Get all leads with active SLAs for a specific SO
  Future<List<LeadPool>> getActiveSlaLeadsForSO(String soUid) async {
    final snapshot = await _firestore
        .collection('leadPool')
        .where('assignedTo', isEqualTo: soUid)
        .get();

    final leads = snapshot.docs
        .map((doc) => LeadPool.fromFirestore(doc))
        .where((lead) =>
            lead.isRegistrationSlaActive || lead.isInstallationSlaActive)
        .toList();

    return leads;
  }

// in LeadService
  Future<void> assignInstallerAndStartSla({
    required String leadId,
    required String installerUid,
    required String installerName,
    int slaDays = 30,
  }) async {
    final now = DateTime.now();
    final end = now.add(Duration(days: slaDays));
    await FirebaseFirestore.instance.collection('leadPool').doc(leadId).update({
      'installationAssignedTo': installerUid,
      'installationAssignedToName': installerName,
      'installationAssignedAt': Timestamp.fromDate(now),
      'installationSlaStartDate': Timestamp.fromDate(now),
      'installationSlaEndDate': Timestamp.fromDate(end),
      'installationCompletedAt': null,
    });
  }

  // Get leads by location
  Stream<List<LeadPool>> getLeadsByLocation(String location) {
    return _firestore
        .collection('leadPool')
        .where('location', isEqualTo: location)
        .orderBy('createdTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LeadPool.fromFirestore(doc)).toList();
    });
  }

  // Get leads by state
  Stream<List<LeadPool>> getLeadsByState(String state) {
    return _firestore
        .collection('leadPool')
        .where('state', isEqualTo: state)
        .orderBy('createdTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LeadPool.fromFirestore(doc)).toList();
    });
  }

  // Search leads by name
  Stream<List<LeadPool>> searchLeadsByName(String query) {
    return _firestore
        .collection('leadPool')
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LeadPool.fromFirestore(doc))
              .toList();
        });
  }

  // Get statistics
  Future<Map<String, int>> getLeadStatistics() async {
    try {
      final snapshot = await _firestore.collection('leadPool').get();

      int total = snapshot.docs.length;
      int submitted = 0;
      int pending = 0;
      int completed = 0;
      int rejected = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status']?.toString().toLowerCase() ?? '';
        switch (status) {
          case 'submitted':
            submitted++;
            break;
          case 'pending':
            pending++;
            break;
          case 'completed':
            completed++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }

      return {
        'total': total,
        'submitted': submitted,
        'pending': pending,
        'completed': completed,
        'rejected': rejected,
      };
    } catch (e) {
      throw 'Failed to get statistics: ${e.toString()}';
    }
  }
}
