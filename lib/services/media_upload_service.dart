import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class MediaUploadService {
  final ImagePicker _picker = ImagePicker();

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      return image;
    } catch (e) {
      print('❌ Error picking image from camera: $e');
      return null;
    }
  }

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      return image;
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      return null;
    }
  }

  // Pick video from camera
  Future<XFile?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      return video;
    } catch (e) {
      print('❌ Error picking video from camera: $e');
      return null;
    }
  }

  // Pick video from gallery
  Future<XFile?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      return video;
    } catch (e) {
      print('❌ Error picking video from gallery: $e');
      return null;
    }
  }

  // Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      print('❌ Error generating thumbnail: $e');
      return null;
    }
  }

  // Upload image to Firebase Storage
  Future<Map<String, dynamic>?> uploadImage({
    required String filePath,
    required String groupId,
    required String senderId,
    Function(double)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      final fileSize = await file.length();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(groupId)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'senderId': senderId,
            'groupId': groupId,
          },
        ),
      );

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded: $downloadUrl');

      return {
        'url': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
      };
    } catch (e) {
      print('❌ Failed to upload image: $e');
      return null;
    }
  }

  // Upload video to Firebase Storage
  Future<Map<String, dynamic>?> uploadVideo({
    required String filePath,
    required String groupId,
    required String senderId,
    Function(double)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      final fileSize = await file.length();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Generate thumbnail
      final thumbnailPath = await generateVideoThumbnail(filePath);
      String? thumbnailUrl;

      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        final thumbnailRef = FirebaseStorage.instance
            .ref()
            .child('chat_videos')
            .child(groupId)
            .child('thumbnails')
            .child('thumb_$fileName.jpg');

        final thumbSnapshot = await thumbnailRef.putFile(thumbnailFile);
        thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
        
        // Clean up local thumbnail
        await thumbnailFile.delete();
      }

      // Upload video
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_videos')
          .child(groupId)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'senderId': senderId,
            'groupId': groupId,
          },
        ),
      );

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Video uploaded: $downloadUrl');

      return {
        'url': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      print('❌ Failed to upload video: $e');
      return null;
    }
  }

  // Format file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}