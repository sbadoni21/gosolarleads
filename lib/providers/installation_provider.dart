import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/leadpool.dart';

final installerLeadsProvider =
    StreamProvider.family<List<LeadPool>, String>((ref, installerUid) {
  return ref
      .read(installationServiceProvider)
      .watchLeadsAssignedToInstaller(installerUid);
});

final installationServiceProvider = Provider<InstallationService>((ref) {
  return InstallationService();
});

class InstallationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ————— Upload —————
  Future<String> uploadImage({
    required File file,
    required String leadId,
    required String fieldName,
    void Function(double progress)? onProgress,
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_$fieldName.jpg';
    final ref = _storage.ref().child('installation/$leadId/$name');
    final task = ref.putFile(file);

    task.snapshotEvents.listen((s) {
      if (onProgress != null && s.totalBytes > 0) {
        onProgress(s.bytesTransferred / s.totalBytes);
      }
    });

    await task;
    return ref.getDownloadURL();
  }

  // ————— Save installation (with per-file updates) —————
  Future<void> saveInstallation({
    required String leadId,
    required Installation installation,
    Map<String, File?> files = const {},
    void Function(String key, double progress)? onProgress, // optional
    void Function(String key, String downloadUrl)? onFileUploaded, // optional
  }) async {
    // Start with what you already have (including any existing URLs)
    var inst = installation;

    // Helper: set a URL into the Installation using its map constructor
    Future<void> _setUrl(String key, File? file) async {
      if (file == null) return;
      // Live per-tile progress while uploading
      final url = await uploadImage(
        file: file,
        leadId: leadId,
        fieldName: key,
        onProgress: (p) => onProgress?.call(key, p),
      );

      // Use toMap -> modify -> fromMap to avoid switch/reflection
      final m = inst.toMap();
      m[key] = url;
      inst = Installation.fromMap(Map<String, dynamic>.from(m));
      onFileUploaded?.call(key, url);
    }

    // Upload each provided file & merge URL into the model
    for (final e in files.entries) {
      await _setUrl(e.key, e.value);
    }

    // Persist to Firestore
    await _db.collection('leadPool').doc(leadId).update({
      'installation': inst.toMap(),
      'status': "installation_complete",
      'installationStatus':
          inst.isSubmitted, // handy boolean for simple queries
    });
  }

  // ————— Assign installer —————
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

  // ————— Get single installation —————
  Future<Installation?> getInstallation(String leadId) async {
    final doc = await _db.collection('leadPool').doc(leadId).get();
    final data = doc.data();
    if (data == null || data['installation'] == null) return null;
    return Installation.fromMap(
        Map<String, dynamic>.from(data['installation']));
  }

  // ————— Watch leads for a specific installer (dashboard list) —————
  Stream<List<LeadPool>> watchLeadsAssignedToInstaller(String installerUid) {
    return _db
        .collection('leadPool')
        .where('installationAssignedTo', isEqualTo: installerUid)
        .orderBy('createdTime', descending: true) // requires a composite index
        .snapshots()
        .map((s) => s.docs.map(LeadPool.fromFirestore).toList());
  }

  // (Optional) One-shot fetch if you need a future:
  Future<List<LeadPool>> fetchLeadsAssignedToInstaller(
      String installerUid) async {
    final q = await _db
        .collection('leadPool')
        .where('installationAssignedTo', isEqualTo: installerUid)
        .orderBy('createdTime', descending: true)
        .get();
    return q.docs.map(LeadPool.fromFirestore).toList();
  }
}
