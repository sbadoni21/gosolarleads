import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/models/leadpool.dart';

final operationsServiceProvider = Provider<OperationsService>((ref) {
  return OperationsService();
});

final operationsLeadsProvider =
    StreamProvider.family<List<LeadPool>, String>((ref, opsUid) {
  return ref
      .read(operationsServiceProvider)
      .watchLeadsAssignedToOperations(opsUid);
});

class OperationsService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // upload a PDF; you can also pass onProgress similarly to your installation service
  Future<String> uploadPdf({
    required File file,
    required String leadId,
    required String fieldKey,
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_$fieldKey.pdf';
    final ref = _storage.ref().child('operations/$leadId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Save operations (upload any provided PDFs & merge)
  /// files map keys: 'operationPdf1', 'operationPdf2', 'jansamarthPdf'
  Future<void> saveOperations({
    required String leadId,
    required Operations operations,
    Map<String, File?> files = const {},
  }) async {
    var ops = operations;

    Future<void> _setUrl(String key, File? file) async {
      if (file == null) return;
      final url = await uploadPdf(file: file, leadId: leadId, fieldKey: key);
      final m = ops.toMap();
      // map keys in DB are ...Url
      if (key == 'operationPdf1') m['operationPdf1Url'] = url;
      if (key == 'operationPdf2') m['operationPdf2Url'] = url;
      if (key == 'jansamarthPdf') m['jansamarthPdfUrl'] = url;
      ops = Operations.fromMap(Map<String, dynamic>.from(m));
    }

    for (final e in files.entries) {
      await _setUrl(e.key, e.value);
    }

    await _db.collection('leadPool').doc(leadId).update({
      'operations': ops.toMap(),
      // optional boolean flag for quick filtering
      'operationsStatus': ops.isSubmitted,
    });
  }

  Future<Operations?> getOperations(String leadId) async {
    final doc = await _db.collection('leadPool').doc(leadId).get();
    final data = doc.data();
    if (data == null || data['operations'] == null) return null;
    return Operations.fromMap(Map<String, dynamic>.from(data['operations']));
  }

  Future<void> assignOperations({
    required String leadId,
    required String opsUid,
    required String opsName,
  }) async {
await FirebaseFirestore.instance
    .collection('leadPool')
    .doc(leadId)
    .update({
  'operationsAssignedTo': null,
  'operationsAssignedToName': null,
  'operationsAssignedAt': null,

  'operations.assignTo': null,
  'operations.assignToName': null,
  'operations.updatedAt': FieldValue.serverTimestamp(),
});

  }
// in your Service class
Stream<Map<String, dynamic>?> watchOperationsMap(String leadId) {
  return FirebaseFirestore.instance
      .collection('leadPool')
      .doc(leadId)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        final ops = data?['operations'];
        return (ops is Map<String, dynamic>) ? Map<String, dynamic>.from(ops) : null;
      });
}

  Stream<List<LeadPool>> watchLeadsAssignedToOperations(String opsUid) {
    return _db
        .collection('leadPool')
        .where('operationsAssignedTo', isEqualTo: opsUid)
        .orderBy('createdTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => LeadPool.fromFirestore(d)).toList());
  }
}

class OpsUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

  OpsUser(
      {required this.uid,
      required this.name,
      required this.email,
      this.photoUrl});

  factory OpsUser.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>? ?? {});
    return OpsUser(
      uid: d.id,
      name: (m['name'] ?? m['displayName'] ?? m['email'] ?? 'Operation')
          .toString(),
      email: (m['email'] ?? '').toString(),
      photoUrl: m['photoURL'] as String?,
    );
  }
}

// Streams all users whose role == 'operations'
final operationsUsersProvider = StreamProvider<List<OpsUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'operation')
      .orderBy(
          'name') // you may switch to 'displayName' if that's what you store
      .snapshots()
      .map((s) => s.docs.map((d) => OpsUser.fromDoc(d)).toList());
});
