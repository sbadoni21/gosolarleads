// lib/providers/accounts_provider.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/accounts_models.dart';
import 'package:gosolarleads/models/leadpool.dart';

final accountsServiceProvider = Provider<AccountsService>((ref) {
  return AccountsService();
});

/// Leads assigned to a specific accounts user (by uid)
final accountsLeadsProvider =
    StreamProvider.family<List<LeadPool>, String>((ref, accountsUid) {
  return ref
      .read(accountsServiceProvider)
      .watchLeadsAssignedToAccounts(accountsUid);
});

class AccountsService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // -------------- Storage --------------

  Future<String> uploadProof({
    required File file,
    required String leadId,
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_proof.jpg';
    final ref = _storage.ref().child('accounts/$leadId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  // -------------- Reads --------------

  Future<Accounts?> getAccounts(String leadId) async {
    final doc = await _db.collection('lead').doc(leadId).get();
    final data = doc.data();
    if (data == null || data['accounts'] == null) return null;
    return Accounts.fromMap(Map<String, dynamic>.from(data['accounts']));
  }

  Future<LeadPool?> getLead(String leadId) async {
    final doc = await _db.collection('lead').doc(leadId).get();
    if (!doc.exists) return null;
    return LeadPool.fromFirestore(doc);
  }

  // -------------- Assignment + SLA start --------------

  /// Assigns Accounts user. If [startSlaNow] true, starts the SLA clocks.
  Future<void> assignAccounts({
    required String leadId,
    required String accountsUid,
    required String accountsName,
    bool startSlaNow = false,
  }) async {
    final updates = <String, dynamic>{
      'accountsAssignedTo': accountsUid,
      'accountsAssignedToName': accountsName,
      'accountsAssignedAt': FieldValue.serverTimestamp(),
      'accounts.assignTo': accountsUid,
      'accounts.assignToName': accountsName,
    };

    if (startSlaNow) {
      final now = DateTime.now();
      updates.addAll({
        'accountsSlaStartDate': Timestamp.fromDate(now),
        'accountsFirstPaymentSlaEndDate':
            Timestamp.fromDate(now.add(const Duration(days: 7))),
        'accountsTotalPaymentSlaEndDate':
            Timestamp.fromDate(now.add(const Duration(days: 30))),
      });
    }

    await _db.collection('lead').doc(leadId).update(updates);
  }

  /// Explicitly starts the Accounts SLAs (7d first payment, 30d total).
  Future<void> startFirstSLA({
    required String leadId,
  }) async {
    final now = DateTime.now();
    await _db.collection('lead').doc(leadId).update({
      'accountsSlaStartDate': Timestamp.fromDate(now),
      'accountsFirstPaymentSlaEndDate':
          Timestamp.fromDate(now.add(const Duration(days: 7))),
      'accountsTotalPaymentSlaEndDate':
          Timestamp.fromDate(now.add(const Duration(days: 30))),
    });
  }

  // -------------- Mark SLA completion (optional helpers) --------------

  Future<void> markFirstPaymentCompleted(String leadId) async {
    await _db.collection('lead').doc(leadId).update({
      'accountsFirstPaymentCompletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markTotalPaymentCompleted(String leadId) async {
    await _db.collection('lead').doc(leadId).update({
      'accountsTotalPaymentCompletedAt': FieldValue.serverTimestamp(),
      'accountStatus': true, // fully paid
    });
  }

  // -------------- Payments --------------

  /// Adds a payment. Auto-updates Accounts SLAs:
  /// - If this is the first payment (or installment == 1), marks first-payment SLA completed.
  /// - If paid >= pitchedAmount, marks total-payment SLA completed and sets accountStatus = true.
  /// Also auto-starts SLA clocks if first payment arrives before `startFirstSLA()` was called.
  Future<void> addPayment({
    required String leadId,
    required AccountPayment payment,
    File? proofFile,
  }) async {
    // fetch current accounts
    final current = await getAccounts(leadId) ?? const Accounts();

    // upload proof if provided
    String? proofUrl = payment.proofUrl;
    if (proofFile != null) {
      proofUrl = await uploadProof(file: proofFile, leadId: leadId);
    }

    // create normalized entry
    final newEntry = AccountPayment(
      amount: payment.amount,
      method: payment.method,
      date: payment.date,
      proofUrl: proofUrl,
      chequeNo: payment.chequeNo,
      transactionId: payment.transactionId,
      installment: payment.installment,
    );

    // combine entries
    final entries = [...current.entries, newEntry];

    // get pitched amount robustly
    final leadDoc = await _db.collection('lead').doc(leadId).get();
    final leadData = leadDoc.data() ?? {};
    final pitchedRaw = leadData['pitchedAmount'];
    final double totalAmount = pitchedRaw is int
        ? pitchedRaw.toDouble()
        : (pitchedRaw is double ? pitchedRaw : 0.0);

    // compute totals
    final paid = entries.fold<double>(0.0, (s, e) => s + (e.amount));
    final bool fullyPaid = totalAmount > 0 && paid >= totalAmount;

    // write accounts object
    final updated = current.copyWith(
      entries: entries,
      status: fullyPaid ? 'submitted' : 'draft',
      updatedAt: DateTime.now(),
    );

    final updates = <String, dynamic>{
      'accounts': updated.toMap(),
      // Keep your model field name (LeadPool.accountStatus)
      'accountStatus': fullyPaid,
    };

    // If SLAs were never started (first payment can be the trigger)
    final accountsSlaStartDate = leadData['accountsSlaStartDate'];
    if (accountsSlaStartDate == null) {
      final now = DateTime.now();
      updates.addAll({
        'accountsSlaStartDate': Timestamp.fromDate(now),
        'accountsFirstPaymentSlaEndDate':
            Timestamp.fromDate(now.add(const Duration(days: 7))),
        'accountsTotalPaymentSlaEndDate':
            Timestamp.fromDate(now.add(const Duration(days: 30))),
      });
    }

    // If this is the very first payment OR explicitly installment == 1 -> complete first-payment SLA
    final isFirstPayment = (current.entries.isEmpty) ||
        (payment.installment != null && payment.installment == 1);
    if (isFirstPayment) {
      updates['accountsFirstPaymentCompletedAt'] = FieldValue.serverTimestamp();
    }

    // If fully paid -> complete total-payment SLA
    if (fullyPaid) {
      updates['accountsTotalPaymentCompletedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('lead').doc(leadId).update(updates);
  }

  // -------------- Streams --------------

  /// Watch leads assigned to a specific accounts user (dashboard)
  Stream<List<LeadPool>> watchLeadsAssignedToAccounts(String accountsUid) {
    // If you get index errors, remove orderBy or create a composite index:
    // accountsAssignedTo ASC, createdTime DESC
    return _db
        .collection('lead')
        .where('accountsAssignedTo', isEqualTo: accountsUid)
        .orderBy('createdTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LeadPool.fromFirestore).toList());
  }
}

/// Minimal user model for list/select
class AccountsUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  AccountsUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory AccountsUser.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>? ?? {});
    return AccountsUser(
      uid: d.id,
      name: (m['name'] ?? m['displayName'] ?? m['email'] ?? 'Accounts')
          .toString(),
      email: (m['email'] ?? '').toString(),
      photoUrl: m['photoURL'] as String?,
    );
  }
}

/// Stream all users with role == 'accounts' (include a few variants)
final accountsUsersProvider = StreamProvider<List<AccountsUser>>((ref) {
  final col = FirebaseFirestore.instance.collection('users');
  // If your DB strictly uses 'accounts', change to .isEqualTo('accounts').
  final q =
      col.where('role', whereIn: ['accounts', 'account', 'finance', 'billing']);
  return q.snapshots().map((s) {
    final list = s.docs.map(AccountsUser.fromDoc).toList();
    list.sort((a, b) => (a.name.isNotEmpty ? a.name : a.email)
        .toLowerCase()
        .compareTo((b.name.isNotEmpty ? b.name : b.email).toLowerCase()));
    return list;
  });
});
