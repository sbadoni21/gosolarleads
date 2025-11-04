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
final leadStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getLeadStatistics();
});
final roleStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, role) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics(role);
});
final salesStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics("sales");
});
final surveyStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics("survey");
});
final installationStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics("installation");
});
final operationsStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics("operations");
});
final accountsStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(leadServiceProvider).getRoleSpecificStatistics("accounts");
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
// Add this method to the LeadService class
Map<String, dynamic> calculateStatsForLeads(List<LeadPool> leads) {
  final stats = _initializeStats();
  
  for (var lead in leads) {
    _processLeadStats(lead, stats);
  }
  
  _calculatePercentages(stats);
  
  return stats;
}
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

// Enhanced Lead Statistics with Better Organization
// Add this to your repository/service file

Future<Map<String, dynamic>> getLeadStatistics() async {
  try {
    final snapshot = await _firestore.collection('lead').get();
    
    // Initialize counters
    final stats = _initializeStats();
    
    // Process all leads in one pass
    for (var doc in snapshot.docs) {
      final lead = LeadPool.fromFirestore(doc);
      _processLeadStats(lead, stats);
    }
    
    // Calculate derived metrics
    _calculatePercentages(stats);
    
    return stats;
  } catch (e) {
    throw 'Failed to get statistics: ${e.toString()}';
  }
}

Map<String, dynamic> _initializeStats() {
  return {
    // === CORE METRICS ===
    'total': 0,
    'submitted': 0,
    'pending': 0,
    'completed': 0,
    'rejected': 0,
    'assigned': 0,
    'unassigned': 0,
    
    // === WORKFLOW STAGES ===
    'withOffer': 0,
    'withSurvey': 0,
    'withInstallation': 0,
    'withOperations': 0,
    'withAccounts': 0,
    
    // === REGISTRATION SLA ===
    'registrationCompleted': 0,
    'registrationActive': 0,
    'registrationBreached': 0,
    'registrationPending': 0,
    
    // === INSTALLATION SLA ===
    'installationCompleted': 0,
    'installationActive': 0,
    'installationBreached': 0,
    'installationPending': 0,
    
    // === ACCOUNTS PAYMENTS (NEW STRUCTURE) ===
    'accountsFirstPaymentCompleted': 0,
    'accountsFirstPaymentActive': 0,
    'accountsFirstPaymentBreached': 0,
    'accountsTotalPaymentCompleted': 0,
    'accountsTotalPaymentActive': 0,
    'accountsTotalPaymentBreached': 0,
    
    // === DOCUMENTS & SUBMISSIONS ===
    'surveySubmitted': 0,
    'surveyDraft': 0,
    'installationSubmitted': 0,
    'installationDraft': 0,
    'operationsSubmitted': 0,
    'operationsDraft': 0,
    
    // === OPERATIONS SPECIFICS ===
    'withJansamarth': 0,           // Has Jansamarth document
    'withOperationsPdf1': 0,       // Has operations PDF 1
    'withOperationsPdf2': 0,       // Has operations PDF 2
    'fullPaymentMarked': 0,        // Full payment checkbox
    
    // === OPERATIONS CHECKBOXES ===
    'opsModelAgreement': 0,
    'opsPpa': 0,
    'opsJirPcrCheck': 0,
    'opsCompanyLetterHead': 0,
    'opsTodWarranty': 0,
    'opsGtp': 0,
    'opsPlantPhoto': 0,
    'opsMeterInstallation': 0,
    'opsStealingReport': 0,
    'opsJirPcrSigningUpcl': 0,
    'opsCentralSubsidyRedeem': 0,
    'opsStateSubsidyApplying': 0,
    
    // === TEAM ASSIGNMENTS ===
    'salesAssigned': 0,
    'surveyAssigned': 0,
    'installationAssigned': 0,
    'operationsAssigned': 0,
    'accountsAssigned': 0,
    
    // === FINANCIAL (Accounts) ===
    'totalAmountReceived': 0.0,
    'averageAmountPerLead': 0.0,
    
    // === HEALTH METRICS ===
    'criticalSlaBreaches': 0,      // Any SLA breached
    'atRiskLeads': 0,              // SLA ending in <3 days
    'healthyLeads': 0,             // All on track
  };
}

void _processLeadStats(LeadPool lead, Map<String, dynamic> stats) {
  stats['total']++;
  
  // === BASIC STATUS ===
  switch (lead.status.toLowerCase().trim()) {
    case 'submitted':
      stats['submitted']++;
      break;
    case 'pending':
      stats['pending']++;
      break;
    case 'completed':
      stats['completed']++;
      break;
    case 'rejected':
      stats['rejected']++;
      break;
  }
  
  // === ASSIGNMENT ===
  if (lead.isAssigned) {
    stats['assigned']++;
    stats['salesAssigned']++;
  } else {
    stats['unassigned']++;
  }
  
  // === WORKFLOW STAGES ===
  if (lead.hasOffer) stats['withOffer']++;
  if (lead.hasSurvey) stats['withSurvey']++;
  if (lead.installation != null) stats['withInstallation']++;
  if (lead.operations != null) stats['withOperations']++;
  if (lead.accounts != null) stats['withAccounts']++;
  
  // === REGISTRATION SLA ===
  if (lead.registrationCompletedAt != null) {
    stats['registrationCompleted']++;
  } else if (lead.isRegistrationSlaActive) {
    stats['registrationActive']++;
    if (lead.isRegistrationSlaBreached) {
      stats['registrationBreached']++;
    }
  } else {
    stats['registrationPending']++;
  }
  
  // === INSTALLATION SLA ===
  if (lead.installationCompletedAt != null) {
    stats['installationCompleted']++;
  } else if (lead.isInstallationSlaActive) {
    stats['installationActive']++;
    if (lead.isInstallationSlaBreached) {
      stats['installationBreached']++;
    }
  } else {
    stats['installationPending']++;
  }
  
  // === ACCOUNTS PAYMENTS ===
  // First Payment (7 days)
  if (lead.accountsFirstPaymentCompletedAt != null) {
    stats['accountsFirstPaymentCompleted']++;
  } else if (lead.isAccountsFirstPaymentSlaActive) {
    stats['accountsFirstPaymentActive']++;
    if (lead.isAccountsFirstPaymentSlaBreached) {
      stats['accountsFirstPaymentBreached']++;
    }
  }
  
  // Total Payment (30 days)
  if (lead.accountsTotalPaymentCompletedAt != null) {
    stats['accountsTotalPaymentCompleted']++;
  } else if (lead.isAccountsTotalPaymentSlaActive) {
    stats['accountsTotalPaymentActive']++;
    if (lead.isAccountsTotalPaymentSlaBreached) {
      stats['accountsTotalPaymentBreached']++;
    }
  }
  
  // === SURVEY ===
  if (lead.survey != null) {
    stats['surveyAssigned']++;
    if (lead.survey!.isSubmitted) {
      stats['surveySubmitted']++;
    } else {
      stats['surveyDraft']++;
    }
  }
  
  // === INSTALLATION ===
  if (lead.installationAssignedTo?.isNotEmpty ?? false) {
    stats['installationAssigned']++;
  }
  if (lead.installation != null) {
    if (lead.installation!.isSubmitted) {
      stats['installationSubmitted']++;
    } else {
      stats['installationDraft']++;
    }
  }
  
  // === OPERATIONS (ENHANCED) ===
  if (lead.operationsAssignedTo?.isNotEmpty ?? false) {
    stats['operationsAssigned']++;
  }
  
  if (lead.operations != null) {
    final ops = lead.operations!;
    
    // Submission status
    if (ops.isSubmitted) {
      stats['operationsSubmitted']++;
    } else {
      stats['operationsDraft']++;
    }
    
    // 🔥 DOCUMENTS (including Jansamarth)
    if (ops.jansamarthPdfUrl?.isNotEmpty ?? false) {
      stats['withJansamarth']++;
    }
    if (ops.operationPdf1Url?.isNotEmpty ?? false) {
      stats['withOperationsPdf1']++;
    }
    if (ops.operationPdf2Url?.isNotEmpty ?? false) {
      stats['withOperationsPdf2']++;
    }
    
    // 🔥 CHECKBOXES
    final checks = ops.checkboxes;
    if (checks.fullPayment) stats['fullPaymentMarked']++;
    if (checks.modelAgreement) stats['opsModelAgreement']++;
    if (checks.ppa) stats['opsPpa']++;
    if (checks.jirPcrCheck) stats['opsJirPcrCheck']++;
    if (checks.companyLetterHead) stats['opsCompanyLetterHead']++;
    if (checks.todWarranty) stats['opsTodWarranty']++;
    if (checks.gtp) stats['opsGtp']++;
    if (checks.plantPhoto) stats['opsPlantPhoto']++;
    if (checks.meterInstallation) stats['opsMeterInstallation']++;
    if (checks.stealingReport) stats['opsStealingReport']++;
    if (checks.jirPcrSigningUpcl) stats['opsJirPcrSigningUpcl']++;
    if (checks.centralSubsidyRedeem) stats['opsCentralSubsidyRedeem']++;
    if (checks.stateSubsidyApplying) stats['opsStateSubsidyApplying']++;
  }
  
  // === ACCOUNTS ===
  if (lead.accountsAssignedTo?.isNotEmpty ?? false) {
    stats['accountsAssigned']++;
  }
  
  if (lead.accounts != null) {
    stats['totalAmountReceived'] += lead.accounts!.totalPaid;
  }
  
  // === HEALTH METRICS ===
  bool hasBreach = lead.isRegistrationSlaBreached || 
                   lead.isInstallationSlaBreached ||
                   lead.isAccountsFirstPaymentSlaBreached ||
                   lead.isAccountsTotalPaymentSlaBreached;
  
  bool atRisk = (lead.registrationDaysRemaining > 0 && lead.registrationDaysRemaining <= 3) ||
                (lead.installationDaysRemaining > 0 && lead.installationDaysRemaining <= 3) ||
                (lead.accountsFirstPaymentDaysRemaining > 0 && lead.accountsFirstPaymentDaysRemaining <= 3) ||
                (lead.accountsTotalPaymentDaysRemaining > 0 && lead.accountsTotalPaymentDaysRemaining <= 3);
  
  if (hasBreach) {
    stats['criticalSlaBreaches']++;
  } else if (atRisk) {
    stats['atRiskLeads']++;
  } else {
    stats['healthyLeads']++;
  }
}

void _calculatePercentages(Map<String, dynamic> stats) {
  final total = stats['total'] as int;
  
  if (total == 0) return;
  
  // Helper function
  String pct(int value) => (value / total * 100).toStringAsFixed(1);
  
  stats['assignmentRate'] = pct(stats['assigned']);
  stats['completionRate'] = pct(stats['completed']);
  
  // Workflow completion rates
  stats['offerRate'] = pct(stats['withOffer']);
  stats['surveyRate'] = pct(stats['withSurvey']);
  stats['installationRate'] = pct(stats['withInstallation']);
  stats['operationsRate'] = pct(stats['withOperations']);
  stats['accountsRate'] = pct(stats['withAccounts']);
  
  // SLA rates
  stats['registrationCompletionRate'] = pct(stats['registrationCompleted']);
  stats['registrationBreachRate'] = pct(stats['registrationBreached']);
  stats['installationCompletionRate'] = pct(stats['installationCompleted']);
  stats['installationBreachRate'] = pct(stats['installationBreached']);
  
  // Accounts payment rates
  stats['firstPaymentCompletionRate'] = pct(stats['accountsFirstPaymentCompleted']);
  stats['firstPaymentBreachRate'] = pct(stats['accountsFirstPaymentBreached']);
  stats['totalPaymentCompletionRate'] = pct(stats['accountsTotalPaymentCompleted']);
  stats['totalPaymentBreachRate'] = pct(stats['accountsTotalPaymentBreached']);
  
  // Operations document rates
  stats['jansamarthRate'] = pct(stats['withJansamarth']);
  stats['operationsPdf1Rate'] = pct(stats['withOperationsPdf1']);
  stats['operationsPdf2Rate'] = pct(stats['withOperationsPdf2']);
  stats['fullPaymentRate'] = pct(stats['fullPaymentMarked']);
  
  // Survey submission rate
  final surveyAssigned = stats['surveyAssigned'] as int;
  if (surveyAssigned > 0) {
    stats['surveySubmissionRate'] = 
      (stats['surveySubmitted'] / surveyAssigned * 100).toStringAsFixed(1);
  }
  
  // Installation submission rate
  final installationAssigned = stats['installationAssigned'] as int;
  if (installationAssigned > 0) {
    stats['installationSubmissionRate'] = 
      (stats['installationSubmitted'] / installationAssigned * 100).toStringAsFixed(1);
  }
  
  // Operations submission rate
  final operationsAssigned = stats['operationsAssigned'] as int;
  if (operationsAssigned > 0) {
    stats['operationsSubmissionRate'] = 
      (stats['operationsSubmitted'] / operationsAssigned * 100).toStringAsFixed(1);
  }
  
  // Financial
  stats['averageAmountPerLead'] = 
    (stats['totalAmountReceived'] / total).toStringAsFixed(2);
  
  // Health metrics
  stats['criticalBreachRate'] = pct(stats['criticalSlaBreaches']);
  stats['atRiskRate'] = pct(stats['atRiskLeads']);
  stats['healthyRate'] = pct(stats['healthyLeads']);
}

// === ENHANCED ROLE-SPECIFIC STATISTICS ===

Future<Map<String, dynamic>> getRoleSpecificStatistics(String role) async {
  try {
    final snapshot = await _firestore.collection('lead').get();
    
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
  int total = snapshot.docs.length;
  int assigned = 0, unassigned = 0;
  int withOffer = 0, withSurvey = 0;
  int registrationCompleted = 0, registrationActive = 0, registrationBreached = 0;
  
  for (var doc in snapshot.docs) {
    final lead = LeadPool.fromFirestore(doc);
    
    if (lead.isAssigned) {
      assigned++;
    } else {
      unassigned++;
    }
    
    if (lead.hasOffer) withOffer++;
    if (lead.hasSurvey) withSurvey++;
    
    if (lead.registrationCompletedAt != null) {
      registrationCompleted++;
    } else if (lead.isRegistrationSlaActive) {
      registrationActive++;
      if (lead.isRegistrationSlaBreached) registrationBreached++;
    }
  }
  
  return {
    'totalLeads': total,
    'assigned': assigned,
    'unassigned': unassigned,
    'withOffer': withOffer,
    'withSurvey': withSurvey,
    'registrationCompleted': registrationCompleted,
    'registrationActive': registrationActive,
    'registrationBreached': registrationBreached,
    'assignmentRate': total > 0 ? (assigned / total * 100).toStringAsFixed(1) : '0',
    'offerRate': total > 0 ? (withOffer / total * 100).toStringAsFixed(1) : '0',
    'surveyRate': total > 0 ? (withSurvey / total * 100).toStringAsFixed(1) : '0',
    'registrationRate': total > 0 ? (registrationCompleted / total * 100).toStringAsFixed(1) : '0',
  };
}

Map<String, dynamic> _getSurveyStatistics(QuerySnapshot snapshot) {
  int assigned = 0, submitted = 0, draft = 0;
  
  for (var doc in snapshot.docs) {
    final lead = LeadPool.fromFirestore(doc);
    if (lead.survey != null) {
      assigned++;
      if (lead.survey!.isSubmitted) {
        submitted++;
      } else {
        draft++;
      }
    }
  }
  
  return {
    'totalAssigned': assigned,
    'submitted': submitted,
    'draft': draft,
    'submissionRate': assigned > 0 ? (submitted / assigned * 100).toStringAsFixed(1) : '0',
  };
}

Map<String, dynamic> _getInstallationStatistics(QuerySnapshot snapshot) {
  int assigned = 0, completed = 0;
  int slaActive = 0, slaBreached = 0;
  int submitted = 0, draft = 0;
  
  for (var doc in snapshot.docs) {
    final lead = LeadPool.fromFirestore(doc);
    
    if (lead.installationAssignedTo?.isNotEmpty ?? false) {
      assigned++;
      
      if (lead.installationCompletedAt != null) {
        completed++;
      } else if (lead.isInstallationSlaActive) {
        slaActive++;
        if (lead.isInstallationSlaBreached) slaBreached++;
      }
      
      if (lead.installation != null) {
        if (lead.installation!.isSubmitted) {
          submitted++;
        } else {
          draft++;
        }
      }
    }
  }
  
  return {
    'totalAssigned': assigned,
    'completed': completed,
    'submitted': submitted,
    'draft': draft,
    'slaActive': slaActive,
    'slaBreached': slaBreached,
    'completionRate': assigned > 0 ? (completed / assigned * 100).toStringAsFixed(1) : '0',
    'submissionRate': assigned > 0 ? (submitted / assigned * 100).toStringAsFixed(1) : '0',
    'breachRate': slaActive > 0 ? (slaBreached / slaActive * 100).toStringAsFixed(1) : '0',
  };
}

Map<String, dynamic> _getOperationsStatistics(QuerySnapshot snapshot) {
  int assigned = 0, submitted = 0, draft = 0;
  int withJansamarth = 0, withPdf1 = 0, withPdf2 = 0;
  int fullPayment = 0;
  Map<String, int> checkboxStats = {};
  
  for (var doc in snapshot.docs) {
    final lead = LeadPool.fromFirestore(doc);
    
    if (lead.operationsAssignedTo?.isNotEmpty ?? false) {
      assigned++;
      
      if (lead.operations != null) {
        final ops = lead.operations!;
        
        if (ops.isSubmitted) {
          submitted++;
        } else {
          draft++;
        }
        
        // Documents
        if (ops.jansamarthPdfUrl?.isNotEmpty ?? false) withJansamarth++;
        if (ops.operationPdf1Url?.isNotEmpty ?? false) withPdf1++;
        if (ops.operationPdf2Url?.isNotEmpty ?? false) withPdf2++;
        
        // Checkboxes
        final c = ops.checkboxes;
        if (c.fullPayment) fullPayment++;
        checkboxStats['modelAgreement'] = (checkboxStats['modelAgreement'] ?? 0) + (c.modelAgreement ? 1 : 0);
        checkboxStats['ppa'] = (checkboxStats['ppa'] ?? 0) + (c.ppa ? 1 : 0);
        checkboxStats['jirPcrCheck'] = (checkboxStats['jirPcrCheck'] ?? 0) + (c.jirPcrCheck ? 1 : 0);
        checkboxStats['centralSubsidy'] = (checkboxStats['centralSubsidy'] ?? 0) + (c.centralSubsidyRedeem ? 1 : 0);
        checkboxStats['stateSubsidy'] = (checkboxStats['stateSubsidy'] ?? 0) + (c.stateSubsidyApplying ? 1 : 0);
      }
    }
  }
  
  return {
    'totalAssigned': assigned,
    'submitted': submitted,
    'draft': draft,
    'withJansamarth': withJansamarth,
    'withPdf1': withPdf1,
    'withPdf2': withPdf2,
    'fullPaymentMarked': fullPayment,
    'submissionRate': assigned > 0 ? (submitted / assigned * 100).toStringAsFixed(1) : '0',
    'jansamarthRate': assigned > 0 ? (withJansamarth / assigned * 100).toStringAsFixed(1) : '0',
    'fullPaymentRate': assigned > 0 ? (fullPayment / assigned * 100).toStringAsFixed(1) : '0',
    ...checkboxStats,
  };
}

Map<String, dynamic> _getAccountsStatistics(QuerySnapshot snapshot) {
  int assigned = 0;
  int firstPaymentDone = 0, totalPaymentDone = 0;
  int firstPaymentActive = 0, firstPaymentBreached = 0;
  int totalPaymentActive = 0, totalPaymentBreached = 0;
  double totalAmount = 0.0;
  
  for (var doc in snapshot.docs) {
    final lead = LeadPool.fromFirestore(doc);
    
    if (lead.accountsAssignedTo?.isNotEmpty ?? false) {
      assigned++;
      
      // First payment
      if (lead.accountsFirstPaymentCompletedAt != null) {
        firstPaymentDone++;
      } else if (lead.isAccountsFirstPaymentSlaActive) {
        firstPaymentActive++;
        if (lead.isAccountsFirstPaymentSlaBreached) firstPaymentBreached++;
      }
      
      // Total payment
      if (lead.accountsTotalPaymentCompletedAt != null) {
        totalPaymentDone++;
      } else if (lead.isAccountsTotalPaymentSlaActive) {
        totalPaymentActive++;
        if (lead.isAccountsTotalPaymentSlaBreached) totalPaymentBreached++;
      }
      
      if (lead.accounts != null) {
        totalAmount += lead.accounts!.totalPaid;
      }
    }
  }
  
  return {
    'totalAssigned': assigned,
    'firstPaymentDone': firstPaymentDone,
    'firstPaymentActive': firstPaymentActive,
    'firstPaymentBreached': firstPaymentBreached,
    'totalPaymentDone': totalPaymentDone,
    'totalPaymentActive': totalPaymentActive,
    'totalPaymentBreached': totalPaymentBreached,
    'totalAmountReceived': totalAmount.toStringAsFixed(2),
    'averageAmount': assigned > 0 ? (totalAmount / assigned).toStringAsFixed(2) : '0',
    'firstPaymentRate': assigned > 0 ? (firstPaymentDone / assigned * 100).toStringAsFixed(1) : '0',
    'totalPaymentRate': assigned > 0 ? (totalPaymentDone / assigned * 100).toStringAsFixed(1) : '0',
    'firstPaymentBreachRate': assigned > 0 ? (firstPaymentBreached / assigned * 100).toStringAsFixed(1) : '0',
    'totalPaymentBreachRate': assigned > 0 ? (totalPaymentBreached / assigned * 100).toStringAsFixed(1) : '0',
  };
}

}
