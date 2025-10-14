import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

// Provider for survey service
final surveyServiceProvider = Provider<SurveyService>((ref) {
  return SurveyService();
});

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String leadId, String imageType) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${imageType}.jpg';
      final ref = _storage.ref().child('survey/$leadId/$fileName');
      
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Delete image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Save survey as draft or submit
  Future<void> saveSurvey({
    required String leadId,
    required Survey survey,
    File? electricityBillFile,
    File? earthingImageFile,
    File? inverterImageFile,
    File? plantImageFile,
  }) async {
    try {
      // Upload new images if provided
      String? electricityBillUrl = survey.electricityBill;
      String? earthingImageUrl = survey.earthingImage;
      String? inverterImageUrl = survey.inverterImage;
      String? plantImageUrl = survey.plantImage;

      if (electricityBillFile != null) {
        electricityBillUrl = await uploadImage(
          electricityBillFile,
          leadId,
          'electricity_bill',
        );
      }

      if (earthingImageFile != null) {
        earthingImageUrl = await uploadImage(
          earthingImageFile,
          leadId,
          'earthing_image',
        );
      }

      if (inverterImageFile != null) {
        inverterImageUrl = await uploadImage(
          inverterImageFile,
          leadId,
          'inverter_image',
        );
      }

      if (plantImageFile != null) {
        plantImageUrl = await uploadImage(
          plantImageFile,
          leadId,
          'plant_image',
        );
      }

      // Create updated survey with image URLs
      final updatedSurvey = survey.copyWith(
        electricityBill: electricityBillUrl,
        earthingImage: earthingImageUrl,
        inverterImage: inverterImageUrl,
        plantImage: plantImageUrl,
      );

      // Update lead with survey data
      await _firestore.collection('leadPool').doc(leadId).update({
        'survey': updatedSurvey.toMap(),
        'surveyStatus': survey.status == 'submitted',
      });

      print('✅ Survey saved successfully');
    } catch (e) {
      print('❌ Error saving survey: $e');
      throw 'Failed to save survey: ${e.toString()}';
    }
  }

  /// Get survey for a lead
  Future<Survey?> getSurvey(String leadId) async {
    try {
      final doc = await _firestore.collection('leadPool').doc(leadId).get();
      
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null || data['survey'] == null) return null;
      
      return Survey.fromMap(data['survey'] as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error getting survey: $e');
      return null;
    }
  }

  /// Update survey status
  Future<void> updateSurveyStatus(String leadId, String status) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'survey.status': status,
        'surveyStatus': status == 'submitted',
      });
    } catch (e) {
      throw 'Failed to update survey status: ${e.toString()}';
    }
  }

  /// Assign survey to surveyor
  Future<void> assignSurvey({
    required String leadId,
    required String surveyorEmail,
    required String surveyorName,
  }) async {
    try {
      await _firestore.collection('leadPool').doc(leadId).update({
        'survey.assignTo': surveyorEmail,
        'assignedTo': surveyorEmail,
        'assignedToName': surveyorName,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // TODO: Send notification to surveyor
      print('✅ Survey assigned to $surveyorName');
    } catch (e) {
      throw 'Failed to assign survey: ${e.toString()}';
    }
  }

  /// Get all surveys assigned to a surveyor
  Stream<List<Survey>> getSurveysByAssignee(String surveyorEmail) {
    return _firestore
        .collection('leadPool')
        .where('survey.assignTo', isEqualTo: surveyorEmail)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['survey'] != null)
          .map((doc) {
            final surveyData = doc.data()['survey'] as Map<String, dynamic>;
            return Survey.fromMap(surveyData);
          })
          .toList();
    });
  }

  /// Get survey statistics
  Future<Map<String, int>> getSurveyStatistics() async {
    try {
      final snapshot = await _firestore
          .collection('leadPool')
          .where('survey', isNotEqualTo: null)
          .get();

      int total = 0;
      int draft = 0;
      int submitted = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['survey'] != null) {
          total++;
          final status = data['survey']['status']?.toString().toLowerCase() ?? '';
          if (status == 'draft') {
            draft++;
          } else if (status == 'submitted') {
            submitted++;
          }
        }
      }

      return {
        'total': total,
        'draft': draft,
        'submitted': submitted,
      };
    } catch (e) {
      print('❌ Error getting survey statistics: $e');
      return {'total': 0, 'draft': 0, 'submitted': 0};
    }
  }

  /// Delete survey and its images
  Future<void> deleteSurvey(String leadId) async {
    try {
      final survey = await getSurvey(leadId);
      
      if (survey != null) {
        // Delete all images
        if (survey.electricityBill != null) {
          await deleteImage(survey.electricityBill!);
        }
        if (survey.earthingImage != null) {
          await deleteImage(survey.earthingImage!);
        }
        if (survey.inverterImage != null) {
          await deleteImage(survey.inverterImage!);
        }
        if (survey.plantImage != null) {
          await deleteImage(survey.plantImage!);
        }
      }

      // Remove survey from lead
      await _firestore.collection('leadPool').doc(leadId).update({
        'survey': FieldValue.delete(),
        'surveyStatus': false,
      });

      print('✅ Survey deleted successfully');
    } catch (e) {
      throw 'Failed to delete survey: ${e.toString()}';
    }
  }
}

// Stream provider for watching a specific survey
final surveyStreamProvider = StreamProvider.family<Survey?, String>((ref, leadId) {
  return FirebaseFirestore.instance
      .collection('leadPool')
      .doc(leadId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['survey'] == null) return null;
    return Survey.fromMap(data['survey'] as Map<String, dynamic>);
  });
});

// Provider for surveys assigned to current user
final myAssignedSurveysProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('leadPool')
      .where('survey.assignTo', isEqualTo: user.email)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.data()['survey'] != null)
        .map((doc) {
          final data = doc.data();
          return {
            'leadId': doc.id,
            'leadName': data['name'] ?? '',
            'survey': Survey.fromMap(data['survey'] as Map<String, dynamic>),
          };
        })
        .toList();
  });
});

// Note: You'll need to import currentUserProvider from your auth provider