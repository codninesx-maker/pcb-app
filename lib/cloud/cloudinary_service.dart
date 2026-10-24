import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart' as dio_pkg;

class CloudinaryService {
  // General Cloudinary instance for images
  final cloudinaryImage = CloudinaryPublic('dow7ik5rv', 'doctor_preset', cache: false);

  // Dedicated high-speed Dio client for video uploads with extended timeouts
  final dio_pkg.Dio _dioVideoClient = dio_pkg.Dio(
    dio_pkg.BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  // 🛑 BANDWIDTH PROTECTION RESTRICTIONS (Fixed multiplication syntax)
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB Max for Images
  static const int maxVideoSizeBytes = 20 * 1024 * 1024; // 20 MB Max for Videos (~60s Reels)

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      if (fileSize > maxImageSizeBytes) {
        debugPrint("DEBUG ERROR: Image size exceeds the 5MB limit.");
        return null;
      }

      CloudinaryResponse response = await cloudinaryImage.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'cloud',
        ),
      );
      debugPrint("DEBUG: Image Upload Success! URL: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      debugPrint("DEBUG: EXCEPTION in uploadImage: $e");
      return null;
    }
  }

  Future<String?> uploadVideo(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      if (fileSize > maxVideoSizeBytes) {
        debugPrint("DEBUG ERROR: Video size exceeds the 20MB limit.");
        return null;
      }

      const String cloudName = 'dow7ik5rv';
      const String uploadPreset = 'video_preset';
      final String url = "https://api.cloudinary.com/v1_1/$cloudName/video/upload";

      dio_pkg.FormData formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(videoFile.path),
        'upload_preset': uploadPreset,
        'folder': 'video',
      });

      dio_pkg.Response response = await _dioVideoClient.post(
        url,
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total != -1) {
            final progress = (sent / total * 100).toStringAsFixed(0);
            debugPrint("Fast Video Upload Progress: $progress%");
          }
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data.containsKey('secure_url')) {
          final secureUrl = data['secure_url']?.toString();
          if (secureUrl != null && secureUrl.isNotEmpty) {
            return secureUrl;
          }
        }
        return null;
      } else {
        return null;
      }
    } on dio_pkg.DioException catch (e) {
      debugPrint("DEBUG: DIO EXCEPTION in uploadVideo: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("DEBUG: UNEXPECTED EXCEPTION in uploadVideo: $e");
      return null;
    }
  }

  Future<void> deleteMedia(String oldUrl) async {
    try {
      if (oldUrl.isEmpty) return;

      final uri = Uri.parse(oldUrl);
      final pathSegments = uri.pathSegments;
      final uploadIndex = pathSegments.indexOf('upload');

      if (uploadIndex == -1) {
        debugPrint("DEBUG ERROR: 'upload' not found in URL: $oldUrl");
        return;
      }

      // Determine correct resource type ('image' or 'video')
      String resourceType = 'image';
      if (pathSegments.contains('video') || oldUrl.contains('/video/')) {
        resourceType = 'video';
      }

      int startIndex = uploadIndex + 1;

      // Check version segment
      if (startIndex < pathSegments.length) {
        final segment = pathSegments[startIndex];
        if (segment.startsWith('v') && int.tryParse(segment.substring(1)) != null) {
          startIndex++;
        }
      }

      if (startIndex >= pathSegments.length) {
        debugPrint("DEBUG ERROR: Could not extract public ID from URL");
        return;
      }

      String publicId = pathSegments.sublist(startIndex).join('/');

      if (publicId.contains('.')) {
        publicId = publicId.substring(0, publicId.lastIndexOf('.'));
      }

      if (publicId.isEmpty) {
        debugPrint("DEBUG ERROR: Extracted Public ID is empty");
        return;
      }

      debugPrint("DEBUG: Attempting to invoke Edge Function for: $publicId ($resourceType)");

      // Invoke the deployed 'delete-image' Supabase Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'delete-image',
        body: {
          'public_id': publicId,
          'resource_type': resourceType,
        },
      );

      debugPrint("DEBUG: Edge Function Success! Response: ${response.data}");

    } catch (invokeError) {
      debugPrint("FATAL INVOCATION ERROR: $invokeError");
      rethrow;
    }
  }
}