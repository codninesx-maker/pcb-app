import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudinaryService {
  // General Cloudinary instance for images
  final cloudinaryImage = CloudinaryPublic('dow7ik5rv', 'doctor_preset', cache: false);

  // Dedicated Cloudinary instance for videos
  final cloudinaryVideo = CloudinaryPublic('dow7ik5rv', 'video_preset', cache: false);

  Future<String?> uploadImage(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinaryImage.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'image',
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
      CloudinaryResponse response = await cloudinaryVideo.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'video',
        ),
      );
      debugPrint("DEBUG: Video Upload Success! URL: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      debugPrint("DEBUG: EXCEPTION in uploadVideo: $e");
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

      // Determine resource type
      String resourceType = 'image';
      if (pathSegments.contains('video') || oldUrl.contains('/video/')) {
        resourceType = 'video';
      }

      // Start right after 'upload'
      int startIndex = uploadIndex + 1;

      // Check if the next segment is a version tag (e.g., v1700000000)
      if (startIndex < pathSegments.length) {
        final segment = pathSegments[startIndex];
        if (segment.startsWith('v') && int.tryParse(segment.substring(1)) != null) {
          startIndex++; // Skip the version segment
        }
      }

      // Everything remaining from startIndex is the public ID (including folder + filename)
      if (startIndex >= pathSegments.length) {
        debugPrint("DEBUG ERROR: Could not extract public ID from URL");
        return;
      }

      String publicId = pathSegments.sublist(startIndex).join('/');

      // Remove the file extension (e.g., .mp4, .jpg)
      if (publicId.contains('.')) {
        publicId = publicId.substring(0, publicId.lastIndexOf('.'));
      }

      if (publicId.isEmpty) {
        debugPrint("DEBUG ERROR: Extracted Public ID is empty");
        return;
      }

      debugPrint("DEBUG: Attempting to invoke Edge Function for: $publicId ($resourceType)");

      // Invoke Supabase Edge Function
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