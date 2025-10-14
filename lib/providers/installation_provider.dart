import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/installation_models.dart';

final installationServiceProvider = Provider<InstallationService>((ref) {
  return InstallationService();
});

class InstallationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<String?> uploadImage({
    required File file,
    required String leadId,
    required String fieldName,
  }) async {
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}_$fieldName.jpg';
      final ref = _storage.ref().child('installation/$leadId/$name');
      await ref.putFile(file);
      return ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveInstallation({
    required String leadId,
    required Installation installation,
    Map<String, File?> files = const {},
  }) async {
    // upload any provided images & replace corresponding fields
    var inst = installation;

    Future<void> setField(String key, File? f) async {
      if (f == null) return;
      final url = await uploadImage(file: f, leadId: leadId, fieldName: key);
      inst = inst.copyWith(
        // dynamic copyWith by field:
        // ignore: invalid_use_of_visible_for_testing_member
      );
      // manual set via map to avoid reflection
      final m = inst.toMap();
      m[key] = url;
      inst = Installation.fromMap(m);
    }

    for (final e in files.entries) {
      await setField(e.key, e.value);
    }

    await _db.collection('leadPool').doc(leadId).update({
      'installation': inst.toMap(),
      // mark lead-level flag to find installation leads quickly (optional)
      'installationStatus': inst.status == 'submitted',
    });
  }

  Future<void> assignInstaller({
    required String leadId,
    required String installerUid,
    required String installerName,
  }) async {
    await _db.collection('leadPool').doc(leadId).update({
      'installationAssignedTo': installerUid,
      'installationAssignedToName': installerName,
      'installationAssignedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Installation?> getInstallation(String leadId) async {
    final doc = await _db.collection('leadPool').doc(leadId).get();
    final data = doc.data();
    if (data == null || data['installation'] == null) return null;
    return Installation.fromMap(Map<String, dynamic>.from(data['installation']));
  }
}
