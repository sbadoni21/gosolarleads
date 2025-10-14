
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:gosolarleads/models/call_record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:phone_state/phone_state.dart';

class LocalCallRecordingService {
  static final LocalCallRecordingService _instance = LocalCallRecordingService._internal();
  factory LocalCallRecordingService() => _instance;
  LocalCallRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentRecordingPath;
  String? _currentCallId;
  DateTime? _callStartTime;
  bool _isRecording = false;
  StreamSubscription<PhoneState>? _phoneStateSubscription;

  bool get isRecording => _isRecording;

  /// Initialize and request permissions
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        print('❌ Microphone permission denied');
        return false;
      }

      // Request phone permission for call state detection
      final phoneStatus = await Permission.phone.request();
      if (!phoneStatus.isGranted) {
        print('⚠️ Phone permission denied - manual call end required');
      }

      print('✅ Permissions granted');
      return true;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Start recording when call begins
  Future<String?> startRecording({
    required String leadId,
    required String leadName,
    required String phoneNumber,
    required String salesOfficerUid,
    required String salesOfficerName,
  }) async {
    try {
      if (_isRecording) {
        print('⚠️ Already recording');
        return null;
      }

      // Get directory for saving
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/call_recording_$timestamp.m4a';

      // Create call record in Firestore
      final callDoc = await _firestore.collection('callRecords').add({
        'leadId': leadId,
        'leadName': leadName,
        'phoneNumber': phoneNumber,
        'salesOfficerUid': salesOfficerUid,
        'salesOfficerName': salesOfficerName,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'duration': null,
        'status': 'recording',
        'recordingUrl': null,
        'localPath': _currentRecordingPath,
        'uploaded': false,
      });

      _currentCallId = callDoc.id;
      _callStartTime = DateTime.now();

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // Good quality, small size
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1, // Mono for smaller file size
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      print('✅ Recording started: $_currentRecordingPath');

      // Listen for call end (if phone permission granted)
      _setupCallStateListener();

      return _currentCallId;
    } catch (e) {
      print('❌ Error starting recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Setup call state listener to auto-stop recording
  void _setupCallStateListener() {
    try {
      _phoneStateSubscription?.cancel();
      _phoneStateSubscription = PhoneState.stream.listen((event) {
        print('📱 Phone state: ${event.status}');
        
        if (event.status == PhoneStateStatus.CALL_ENDED && _isRecording) {
          print('📞 Call ended - stopping recording');
          stopRecordingAndUpload();
        }
      });
    } catch (e) {
      print('⚠️ Could not setup call state listener: $e');
    }
  }

  /// Stop recording and upload to Firebase
  Future<bool> stopRecordingAndUpload() async {
    try {
      if (!_isRecording) {
        print('⚠️ No active recording');
        return false;
      }

      // Stop recording
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null || _currentCallId == null) {
        print('❌ Recording path or call ID missing');
        return false;
      }

      final file = File(path);
      if (!await file.exists()) {
        print('❌ Recording file not found');
        return false;
      }

      // Calculate duration
      final duration = DateTime.now().difference(_callStartTime!);
      final fileSizeBytes = await file.length();
      final fileSizeMB = fileSizeBytes / (1024 * 1024);

      print('📊 Recording stats:');
      print('   Duration: ${duration.inSeconds}s');
      print('   Size: ${fileSizeMB.toStringAsFixed(2)} MB');

      // Upload to Firebase Storage
      print('📤 Uploading to Firebase...');
      
      final storageRef = _storage.ref().child(
        'call_recordings/${_currentCallId}/${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/mp4',
          customMetadata: {
            'callId': _currentCallId!,
            'duration': duration.inSeconds.toString(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      final uploadSnapshot = await uploadTask;
      final downloadUrl = await uploadSnapshot.ref.getDownloadURL();

      print('✅ Upload complete: $downloadUrl');

      // Update Firestore with recording details
      await _firestore.collection('callRecords').doc(_currentCallId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'duration': duration.inSeconds,
        'recordingUrl': downloadUrl,
        'fileSizeBytes': fileSizeBytes,
        'status': 'completed',
        'uploaded': true,
      });

      print('✅ Firestore updated');

      // Delete local file to save space
      await file.delete();
      print('🗑️ Local file deleted');

      // Cleanup
      _currentRecordingPath = null;
      _currentCallId = null;
      _callStartTime = null;
      _phoneStateSubscription?.cancel();

      return true;
    } catch (e) {
      print('❌ Error stopping and uploading: $e');
      _isRecording = false;

      // Update status as failed
      if (_currentCallId != null) {
        await _firestore.collection('callRecords').doc(_currentCallId).update({
          'status': 'failed',
          'error': e.toString(),
        });
      }

      return false;
    }
  }

  /// Cancel recording without uploading
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (_currentCallId != null) {
        await _firestore.collection('callRecords').doc(_currentCallId).update({
          'status': 'cancelled',
        });
      }

      _currentRecordingPath = null;
      _currentCallId = null;
      _callStartTime = null;
      _phoneStateSubscription?.cancel();

      print('❌ Recording cancelled');
    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
  }

  /// Get call records for a lead
  Stream<List<CallRecord>> getLeadCallRecords(String leadId) {
    return _firestore
        .collection('callRecords')
        .where('leadId', isEqualTo: leadId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CallRecord.fromFirestore(doc);
      }).toList();
    });
  }

  /// Dispose
  Future<void> dispose() async {
    await _phoneStateSubscription?.cancel();
    await _recorder.dispose();
  }
}
