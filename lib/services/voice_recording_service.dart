import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VoiceRecordingService {
  final _audioRecorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;

  // Check and request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        print('❌ Microphone permission denied');
        return false;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      print('✅ Recording started: $_recordingPath');
      return true;
    } catch (e) {
      print('❌ Failed to start recording: $e');
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      print('✅ Recording stopped: $path');
      return path;
    } catch (e) {
      print('❌ Failed to stop recording: $e');
      return null;
    }
  }

  // Cancel recording (stop and delete file)
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('✅ Recording deleted: $_recordingPath');
        }
        _recordingPath = null;
      }
    } catch (e) {
      print('❌ Failed to cancel recording: $e');
    }
  }

  // Upload voice recording to Firebase Storage
  Future<Map<String, dynamic>?> uploadVoiceMessage({
    required String filePath,
    required String groupId,
    required String senderId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      // Get file size and duration
      final fileSize = await file.length();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(groupId)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/m4a',
          customMetadata: {
            'senderId': senderId,
            'groupId': groupId,
          },
        ),
      );

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Voice message uploaded: $downloadUrl');

      // Delete local file after upload
      await file.delete();

      return {
        'url': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'duration': 0, // TODO: Calculate actual duration
      };
    } catch (e) {
      print('❌ Failed to upload voice message: $e');
      return null;
    }
  }

  // Get file size in human-readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Format duration (seconds to mm:ss)
  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Dispose
  void dispose() {
    _audioRecorder.dispose();
  }
}