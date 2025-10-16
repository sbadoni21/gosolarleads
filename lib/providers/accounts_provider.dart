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

  Future<String> uploadProof({
    required File file,
    required String leadId,
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_proof.jpg';
    final ref = _storage.ref().child('accounts/$leadId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<Accounts?> getAccounts(String leadId) async {
    final doc = await _db.collection('leadPool').doc(leadId).get();
    final data = doc.data();
    if (data == null || data['accounts'] == null) return null;
    return Accounts.fromMap(Map<String, dynamic>.from(data['accounts']));
  }

  Future<void> assignAccounts({
    required String leadId,
    required String accountsUid,
    required String accountsName,
  }) async {
    await _db.collection('leadPool').doc(leadId).update({
      'accountsAssignedTo': accountsUid,
      'accountsAssignedToName': accountsName,
      'accountsAssignedAt': FieldValue.serverTimestamp(),
      // convenience inside accounts map too
      'accounts.assignTo': accountsUid,
      'accounts.assignToName': accountsName,
    });
  }

  /// Add a payment entry & recompute status
  /// totalAmount comes from lead (e.g., pitchedAmount or survey.plantCost)
  Future<void> addPayment({
    required String leadId,
    required AccountPayment payment,
    File? proofFile,
  }) async {
    // fetch current accounts
    final current = await getAccounts(leadId) ?? const Accounts();

    String? proofUrl = payment.proofUrl;
    if (proofFile != null) {
      proofUrl = await uploadProof(file: proofFile, leadId: leadId);
    }

    final newEntry = AccountPayment(
      amount: payment.amount,
      method: payment.method,
      date: payment.date,
      proofUrl: proofUrl,
      chequeNo: payment.chequeNo,
      transactionId: payment.transactionId,
      installment: payment.installment,
    );

    final entries = [...current.entries, newEntry];

    // read total expected amount from lead
    final leadDoc = await _db.collection('leadPool').doc(leadId).get();
    final leadData = leadDoc.data() ?? {};
    final double totalAmount = (leadData['pitchedAmount'] is int)
        ? (leadData['pitchedAmount'] as int).toDouble()
        : (leadData['pitchedAmount'] ?? 0.0) as double;

    final paid = entries.fold<double>(0.0, (s, e) => s + e.amount);
    final bool fullyPaid = paid >= totalAmount && totalAmount > 0;

    final updated = current.copyWith(
      entries: entries,
      status: fullyPaid ? 'submitted' : 'draft',
      updatedAt: DateTime.now(),
    );

    await _db.collection('leadPool').doc(leadId).update({
      'accounts': updated.toMap(),
      // optional quick filter boolean
      'accountsStatus': fullyPaid,
    });
  }

  /// Watch leads assigned to a specific accounts user (dashboard)
  Stream<List<LeadPool>> watchLeadsAssignedToAccounts(String accountsUid) {
    // If you get index errors, remove orderBy or create a composite index.
    return _db
        .collection('leadPool')
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
      name: (m['name'] ?? m['displayName'] ?? m['email'] ?? 'Accounts').toString(),
      email: (m['email'] ?? '').toString(),
      photoUrl: m['photoURL'] as String?,
    );
  }
}

/// Stream all users with role == 'accounts' (include a few variants)
final accountsUsersProvider = StreamProvider<List<AccountsUser>>((ref) {
  final col = FirebaseFirestore.instance.collection('users');
  // If your DB strictly uses 'accounts', change to .isEqualTo('accounts').
  final q = col.where('role', whereIn: ['accounts', 'account', 'finance', 'billing']);
  return q.snapshots().map((s) {
    final list = s.docs.map(AccountsUser.fromDoc).toList();
    list.sort((a, b) => (a.name.isNotEmpty ? a.name : a.email)
        .toLowerCase()
        .compareTo((b.name.isNotEmpty ? b.name : b.email).toLowerCase()));
    return list;
  });
});
