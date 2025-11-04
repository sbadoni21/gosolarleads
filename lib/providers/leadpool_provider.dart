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
final leadStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
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
      .collection('lead')
      .where('assignedTo', isEqualTo: user.uid)
      .orderBy('createdTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => LeadPool.fromFirestore(d)).toList());
});

// Stream of all leads
final allLeadsProvider = StreamProvider<List<LeadPool>>((ref) {
  return FirebaseFirestore.instance
      .collection('lead')
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
      .collection('lead')
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
      .collection('lead')
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
      final docRef = _firestore.collection('lead').doc(lead.uid);

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
      await _firestore.collection('lead').doc(leadId).update(updates);
    } catch (e) {
      throw 'Failed to update lead: ${e.toString()}';
    }
  }

  // Delete a lead
  Future<void> deleteLead(String leadId) async {
    try {
      await _firestore.collection('lead').doc(leadId).delete();
    } catch (e) {
      throw 'Failed to delete lead: ${e.toString()}';
    }
  }

  // Get a single lead by ID
  Future<LeadPool?> getLeadById(String leadId) async {
    try {
      final doc = await _firestore.collection('lead').doc(leadId).get();
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
      await _firestore.collection('lead').doc(leadId).update({
        'status': status,
      });
    } catch (e) {
      throw 'Failed to update status: ${e.toString()}';
    }
  }

  // Update survey status
  Future<void> updateSurveyStatus(String leadId, bool surveyStatus) async {
    try {
      await _firestore.collection('lead').doc(leadId).update({
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

    await FirebaseFirestore.instance.collection('lead').doc(leadId).update({
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
      await _firestore.collection('lead').doc(leadId).update({
        'accountStatus': accountStatus,
      });
    } catch (e) {
      throw 'Failed to update account status: ${e.toString()}';
    }
  }

  // Update offer
  Future<void> updateOffer(String leadId, Offer offer) async {
    try {
      await _firestore.collection('lead').doc(leadId).update({
        'offer': offer.toMap(),
      });
    } catch (e) {
      throw 'Failed to update offer: ${e.toString()}';
    }
  }

  // Watch a lead by ID
  Stream<LeadPool?> watchLeadById(String id) {
    return _firestore.collection('lead').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LeadPool.fromFirestore(doc);
    });
  }

  Future<void> startRegistrationSla(String leadId) async {
    try {
      final now = DateTime.now();
      final registrationSlaEnd = now.add(const Duration(days: 3));

      await _firestore.collection('lead').doc(leadId).update({
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
        _firestore.collection('lead').doc(leadId).collection('comments');
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
    final rDoc =
        _firestore.collection('lead').doc(leadId).collection('reminders').doc();
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
        .collection('lead')
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
    await _firestore.collection('lead').doc(leadId).update(data);
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
      final proofDoc =
          _firestore.collection('lead').doc(leadId).collection('proofs').doc();
      await _firestore.runTransaction((tx) async {
        tx.update(_firestore.collection('lead').doc(leadId), updates);
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
      await _firestore.collection('lead').doc(leadId).update(updates);
    }
  }

  /// Streams
  Stream<List<LeadComment>> watchComments(String leadId) {
    return _firestore
        .collection('lead')
        .doc(leadId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => LeadComment.fromDoc(d)).toList());
  }

  Stream<List<LeadReminder>> watchReminders(String leadId) {
    return _firestore
        .collection('lead')
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

    await _firestore.collection('lead').doc(leadId).update({
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
    await _firestore.collection('lead').doc(leadId).update({
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

    await _firestore.collection('lead').doc(leadId).update({
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

    await _firestore.collection('lead').doc(leadId).update({
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
        .collection('lead')
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
        .collection('lead')
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
    await FirebaseFirestore.instance.collection('lead').doc(leadId).update({
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
        .collection('lead')
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
        .collection('lead')
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
        .collection('lead')
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

// Get comprehensive lead statistics
  Future<Map<String, dynamic>> getLeadStatistics() async {
    try {
      final snapshot = await _firestore.collection('leadPool').get();

      // Basic counts
      int total = snapshot.docs.length;
      int submitted = 0;
      int pending = 0;
      int completed = 0;
      int rejected = 0;
      int assigned = 0;
      int unassigned = 0;

      // Assignment tracking
      int hasOffer = 0;
      int hasSurvey = 0;
      int hasInstallation = 0;
      int hasOperations = 0;
      int hasAccounts = 0;

      // Registration SLA
      int registrationCompleted = 0;
      int registrationActive = 0;
      int registrationBreached = 0;

      // Installation SLA
      int installationCompleted = 0;
      int installationActive = 0;
      int installationBreached = 0;

      // Operations specific
      int hasJansamarth = 0;
      int hasFullPayment = 0;

      // Accounts SLA
      int accountsFirstPaymentCompleted = 0;
      int accountsTotalPaymentCompleted = 0;
      int accountsFirstPaymentBreached = 0;
      int accountsTotalPaymentBreached = 0;

      // Survey specific
      int surveySubmitted = 0;

      // Installation assignments
      int installationAssigned = 0;
      int operationsAssigned = 0;
      int accountsAssigned = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lead = LeadPool.fromFirestore(doc);

        // Basic status
        final status = (data['status']?.toString() ?? '').toLowerCase();
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

        // Assignment
        if (lead.isAssigned) {
          assigned++;
        } else {
          unassigned++;
        }

        // Data objects
        if (lead.hasOffer) hasOffer++;
        if (lead.hasSurvey) hasSurvey++;
        if (lead.installation != null) hasInstallation++;
        if (lead.operations != null) hasOperations++;
        if (lead.accounts != null) hasAccounts++;

        // Registration SLA
        if (lead.registrationCompletedAt != null) {
          registrationCompleted++;
        } else if (lead.isRegistrationSlaActive) {
          registrationActive++;
          if (lead.isRegistrationSlaBreached) {
            registrationBreached++;
          }
        }

        // Installation SLA
        if (lead.installationCompletedAt != null) {
          installationCompleted++;
        } else if (lead.isInstallationSlaActive) {
          installationActive++;
          if (lead.isInstallationSlaBreached) {
            installationBreached++;
          }
        }

        // Operations checks
        if (lead.operations != null) {
          final ops = lead.operations!;
          if (ops.jansamarthPdfUrl?.isNotEmpty ?? false) {
            hasJansamarth++;
          }
          if (ops.checkboxes.fullPayment) {
            hasFullPayment++;
          }
        }

        // Accounts payments
        if (lead.accountsFirstPaymentCompletedAt != null) {
          accountsFirstPaymentCompleted++;
        }
        if (lead.accountsTotalPaymentCompletedAt != null) {
          accountsTotalPaymentCompleted++;
        }
        if (lead.isAccountsFirstPaymentSlaBreached) {
          accountsFirstPaymentBreached++;
        }
        if (lead.isAccountsTotalPaymentSlaBreached) {
          accountsTotalPaymentBreached++;
        }

        // Survey status
        if (lead.survey?.isSubmitted ?? false) {
          surveySubmitted++;
        }

        // Team assignments
        if (lead.installationAssignedTo?.isNotEmpty ?? false) {
          installationAssigned++;
        }
        if (lead.operationsAssignedTo?.isNotEmpty ?? false) {
          operationsAssigned++;
        }
        if (lead.accountsAssignedTo?.isNotEmpty ?? false) {
          accountsAssigned++;
        }
      }

      return {
        // Basic Stats
        'total': total,
        'submitted': submitted,
        'pending': pending,
        'completed': completed,
        'rejected': rejected,
        'assigned': assigned,
        'unassigned': unassigned,

        // Data Objects
        'hasOffer': hasOffer,
        'hasSurvey': hasSurvey,
        'hasInstallation': hasInstallation,
        'hasOperations': hasOperations,
        'hasAccounts': hasAccounts,

        // Registration SLA
        'registrationCompleted': registrationCompleted,
        'registrationActive': registrationActive,
        'registrationBreached': registrationBreached,

        // Installation SLA
        'installationCompleted': installationCompleted,
        'installationActive': installationActive,
        'installationBreached': installationBreached,

        // Operations
        'hasJansamarth': hasJansamarth,
        'hasFullPayment': hasFullPayment,

        // Accounts Payments
        'accountsFirstPaymentCompleted': accountsFirstPaymentCompleted,
        'accountsTotalPaymentCompleted': accountsTotalPaymentCompleted,
        'accountsFirstPaymentBreached': accountsFirstPaymentBreached,
        'accountsTotalPaymentBreached': accountsTotalPaymentBreached,

        // Survey
        'surveySubmitted': surveySubmitted,

        // Team Assignments
        'installationAssigned': installationAssigned,
        'operationsAssigned': operationsAssigned,
        'accountsAssigned': accountsAssigned,

        // Calculated percentages (useful for dashboards)
        'assignmentRate':
            total > 0 ? (assigned / total * 100).toStringAsFixed(1) : '0',
        'registrationCompletionRate': total > 0
            ? (registrationCompleted / total * 100).toStringAsFixed(1)
            : '0',
        'installationCompletionRate': total > 0
            ? (installationCompleted / total * 100).toStringAsFixed(1)
            : '0',
        'jansamarthRate':
            total > 0 ? (hasJansamarth / total * 100).toStringAsFixed(1) : '0',
        'firstPaymentRate': total > 0
            ? (accountsFirstPaymentCompleted / total * 100).toStringAsFixed(1)
            : '0',
        'totalPaymentRate': total > 0
            ? (accountsTotalPaymentCompleted / total * 100).toStringAsFixed(1)
            : '0',
      };
    } catch (e) {
      throw 'Failed to get statistics: ${e.toString()}';
    }
  }

// Get statistics by role (for role-specific dashboards)
  Future<Map<String, dynamic>> getRoleSpecificStatistics(String role) async {
    try {
      final snapshot = await _firestore.collection('leadPool').get();

      switch (role.toLowerCase()) {
        case 'sales':
          return _getSalesStatistics(snapshot);
        case 'survey':
          return _getSurveyStatistics(snapshot);
        case 'installation':
          return _getInstallationStatistics(snapshot);
        case 'operations':
          return _getOperationsStatistics(snapshot);
        case 'accounts':
          return _getAccountsStatistics(snapshot);
        default:
          return getLeadStatistics();
      }
    } catch (e) {
      throw 'Failed to get role statistics: ${e.toString()}';
    }
  }

  Map<String, dynamic> _getSalesStatistics(QuerySnapshot snapshot) {
    int totalLeads = snapshot.docs.length;
    int withOffer = 0;
    int withSurvey = 0;
    int registered = 0;

    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      if (lead.hasOffer) withOffer++;
      if (lead.hasSurvey) withSurvey++;
      if (lead.registrationCompletedAt != null) registered++;
    }

    return {
      'totalLeads': totalLeads,
      'withOffer': withOffer,
      'withSurvey': withSurvey,
      'registered': registered,
      'offerRate': totalLeads > 0
          ? (withOffer / totalLeads * 100).toStringAsFixed(1)
          : '0',
      'surveyRate': totalLeads > 0
          ? (withSurvey / totalLeads * 100).toStringAsFixed(1)
          : '0',
      'registrationRate': totalLeads > 0
          ? (registered / totalLeads * 100).toStringAsFixed(1)
          : '0',
    };
  }

  Map<String, dynamic> _getSurveyStatistics(QuerySnapshot snapshot) {
    int totalAssigned = 0;
    int surveysSubmitted = 0;
    int surveysDraft = 0;

    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      if (lead.hasSurvey) {
        totalAssigned++;
        if (lead.survey!.isSubmitted) {
          surveysSubmitted++;
        } else {
          surveysDraft++;
        }
      }
    }

    return {
      'totalAssigned': totalAssigned,
      'surveysSubmitted': surveysSubmitted,
      'surveysDraft': surveysDraft,
      'completionRate': totalAssigned > 0
          ? (surveysSubmitted / totalAssigned * 100).toStringAsFixed(1)
          : '0',
    };
  }

  Map<String, dynamic> _getInstallationStatistics(QuerySnapshot snapshot) {
    int totalAssigned = 0;
    int installationComplete = 0;
    int slaActive = 0;
    int slaBreached = 0;

    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      if (lead.installationAssignedTo?.isNotEmpty ?? false) {
        totalAssigned++;
        if (lead.installationCompletedAt != null) {
          installationComplete++;
        } else if (lead.isInstallationSlaActive) {
          slaActive++;
          if (lead.isInstallationSlaBreached) {
            slaBreached++;
          }
        }
      }
    }

    return {
      'totalAssigned': totalAssigned,
      'installationComplete': installationComplete,
      'slaActive': slaActive,
      'slaBreached': slaBreached,
      'completionRate': totalAssigned > 0
          ? (installationComplete / totalAssigned * 100).toStringAsFixed(1)
          : '0',
      'breachRate': slaActive > 0
          ? (slaBreached / slaActive * 100).toStringAsFixed(1)
          : '0',
    };
  }

  Map<String, dynamic> _getOperationsStatistics(QuerySnapshot snapshot) {
    int totalAssigned = 0;
    int opsSubmitted = 0;
    int withJansamarth = 0;
    int fullPaymentMarked = 0;

    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      if (lead.operationsAssignedTo?.isNotEmpty ?? false) {
        totalAssigned++;
        if (lead.operations?.isSubmitted ?? false) {
          opsSubmitted++;
        }
        if (lead.operations?.jansamarthPdfUrl?.isNotEmpty ?? false) {
          withJansamarth++;
        }
        if (lead.operations?.checkboxes.fullPayment ?? false) {
          fullPaymentMarked++;
        }
      }
    }

    return {
      'totalAssigned': totalAssigned,
      'opsSubmitted': opsSubmitted,
      'withJansamarth': withJansamarth,
      'fullPaymentMarked': fullPaymentMarked,
      'submissionRate': totalAssigned > 0
          ? (opsSubmitted / totalAssigned * 100).toStringAsFixed(1)
          : '0',
      'jansamarthRate': totalAssigned > 0
          ? (withJansamarth / totalAssigned * 100).toStringAsFixed(1)
          : '0',
    };
  }

  Map<String, dynamic> _getAccountsStatistics(QuerySnapshot snapshot) {
    int totalAssigned = 0;
    int firstPaymentDone = 0;
    int totalPaymentDone = 0;
    int firstPaymentBreached = 0;
    int totalPaymentBreached = 0;
    double totalAmountReceived = 0.0;

    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      if (lead.accountsAssignedTo?.isNotEmpty ?? false) {
        totalAssigned++;

        if (lead.accountsFirstPaymentCompletedAt != null) {
          firstPaymentDone++;
        }
        if (lead.accountsTotalPaymentCompletedAt != null) {
          totalPaymentDone++;
        }
        if (lead.isAccountsFirstPaymentSlaBreached) {
          firstPaymentBreached++;
        }
        if (lead.isAccountsTotalPaymentSlaBreached) {
          totalPaymentBreached++;
        }

        // Calculate total amount received
        if (lead.accounts != null) {
          totalAmountReceived += lead.accounts!.totalPaid;
        }
      }
    }

    return {
      'totalAssigned': totalAssigned,
      'firstPaymentDone': firstPaymentDone,
      'totalPaymentDone': totalPaymentDone,
      'firstPaymentBreached': firstPaymentBreached,
      'totalPaymentBreached': totalPaymentBreached,
      'totalAmountReceived': totalAmountReceived.toStringAsFixed(2),
      'firstPaymentRate': totalAssigned > 0
          ? (firstPaymentDone / totalAssigned * 100).toStringAsFixed(1)
          : '0',
      'totalPaymentRate': totalAssigned > 0
          ? (totalPaymentDone / totalAssigned * 100).toStringAsFixed(1)
          : '0',
      'firstPaymentBreachRate': totalAssigned > 0
          ? (firstPaymentBreached / totalAssigned * 100).toStringAsFixed(1)
          : '0',
      'totalPaymentBreachRate': totalAssigned > 0
          ? (totalPaymentBreached / totalAssigned * 100).toStringAsFixed(1)
          : '0',
    };
  }
}
