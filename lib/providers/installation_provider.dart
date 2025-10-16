// lib/services/installation_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/leadpool.dart';

/// Riverpod provider
final installationServiceProvider = Provider<InstallationService>((ref) {
  return InstallationService();
});

/// Streams leads assigned to an installer (helper you already use)
final installerLeadsProvider =
    StreamProvider.family<List<LeadPool>, String>((ref, installerUid) {
  return ref
      .read(installationServiceProvider)
      .watchLeadsAssignedToInstaller(installerUid);
});

class InstallationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ───────────────────────── Storage helpers ─────────────────────────

  /// Upload using a real File path (camera paths usually).
  Future<String> _uploadImageFile({
    required File file,
    required String leadId,
    required String fieldName,
    void Function(double p)? onProgress,
    String contentType = 'image/jpeg',
  }) async {
    final fname = '${DateTime.now().millisecondsSinceEpoch}_$fieldName.jpg';
    final ref = _storage.ref().child('installation/$leadId/$fname');

    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putFile(file, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress(s.bytesTransferred / s.totalBytes);
        }
      });
    }

    await task.whenComplete(() {});
    return ref.getDownloadURL();
  }

  /// Upload using raw bytes (works with content:// URIs / scoped storage).
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String leadId,
    required String fieldName,
    void Function(double p)? onProgress,
    String contentType = 'image/jpeg',
  }) async {
    final fname = '${DateTime.now().millisecondsSinceEpoch}_$fieldName.jpg';
    final ref = _storage.ref().child('installation/$leadId/$fname');

    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putData(bytes, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress(s.bytesTransferred / s.totalBytes);
        }
      });
    }

    await task.whenComplete(() {});
    return ref.getDownloadURL();
  }

  /// Smart uploader:
  /// 1) If the File exists on disk, stream with putFile (efficient).
  /// 2) Otherwise read bytes from File() and upload with putData (reliable).
  Future<String> uploadImageSmart({
    required File file,
    required String leadId,
    required String fieldName,
    void Function(double p)? onProgress,
    String contentType = 'image/jpeg',
  }) async {
    try {
      if (file.absolute.existsSync()) {
        return _uploadImageFile(
          file: file,
          leadId: leadId,
          fieldName: fieldName,
          onProgress: onProgress,
          contentType: contentType,
        );
      }
    } catch (_) {
      // fall through to bytes path
    }

    // If the File doesn’t exist (content://), try reading bytes anyway.
    final bytes = await file.readAsBytes();
    return uploadImageBytes(
      bytes: bytes,
      leadId: leadId,
      fieldName: fieldName,
      onProgress: onProgress,
      contentType: contentType,
    );
  }

  // ─────────────────────── Firestore write helpers ───────────────────────

  /// Immediately persist a single image field under:
  /// leadPool/{leadId}/installation.<fieldName> = <url>
  Future<void> updateImageField({
    required String leadId,
    required String fieldName, // e.g. "structureImage"
    required String url,
  }) async {
    await _db.collection('leadPool').doc(leadId).set({
      'installation': {
        fieldName: url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    if (kDebugMode) {
      debugPrint('✔ [$leadId] installation.$fieldName set');
    }
  }

  /// Final save for non-image fields + status.
  /// IMPORTANT: removes nulls so they don’t overwrite earlier image URLs.
  Future<void> saveInstallationData({
    required String leadId,
    required Installation installation,
  }) async {
    final docRef = _db.collection('leadPool').doc(leadId);

    final installationMap = Map<String, dynamic>.from(installation.toMap());
    installationMap.removeWhere((k, v) => v == null);

    await docRef.set({
      'installation': {
        ...installationMap,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'installationStatus': (installation.status == 'submitted'),
      if (installation.status == 'submitted') 'status': 'installation_in_progress',
    }, SetOptions(merge: true));

    if (kDebugMode) {
      debugPrint('✔ Saved installation data for $leadId');
      debugPrint('Installation keys: ${installationMap.keys.toList()}');
    }
  }

  /// One-shot robust save (if you ever want to use it):
  Future<void> saveInstallation({
    required String leadId,
    required Installation installation,
    Map<String, File?> files = const {},
    void Function(String key, double progress)? onProgress,
    void Function(String key, String url)? onFileUploaded,
  }) async {
    final docRef = _db.collection('leadPool').doc(leadId);

    await docRef.set({
      'installation': {
        ...installation.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'installationStatus': (installation.status == 'submitted'),
      if (installation.status == 'submitted') 'status': 'installation_in_progress',
    }, SetOptions(merge: true));

    for (final entry in files.entries) {
      final key = entry.key;
      final file = entry.value;
      if (file == null) continue;

      try {
        final url = await uploadImageSmart(
          file: file,
          leadId: leadId,
          fieldName: key,
          onProgress: (p) => onProgress?.call(key, p),
        );

        await updateImageField(leadId: leadId, fieldName: key, url: url);
        onFileUploaded?.call(key, url);

        if (kDebugMode) {
          debugPrint('✔ [$leadId] uploaded & saved installation.$key');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('✖ [$leadId] upload failed for $key: $e');
        }
      }
    }

    final installationMap = Map<String, dynamic>.from(installation.toMap());
    installationMap.removeWhere((k, v) => v == null);

    await docRef.set({
      'installation': {
        ...installationMap,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'installationStatus': (installation.status == 'submitted'),
    }, SetOptions(merge: true));
  }

  // ───────────────────────── Live stream / Read / Streams ─────────────────────────

  /// Live stream of installation map for this lead
  Stream<Map<String, dynamic>?> watchInstallationMap(String leadId) {
    return _db.collection('leadPool').doc(leadId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final inst = data['installation'];
      return inst == null ? null : Map<String, dynamic>.from(inst);
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
    if (data == null) return null;
    final map = data['installation'];
    if (map == null) return null;
    return Installation.fromMap(Map<String, dynamic>.from(map));
  }

  Stream<List<LeadPool>> watchLeadsAssignedToInstaller(String installerUid) {
    return _db
        .collection('leadPool')
        .where('installationAssignedTo', isEqualTo: installerUid)
        .orderBy('createdTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LeadPool.fromFirestore).toList());
  }

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
