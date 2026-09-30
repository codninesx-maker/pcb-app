import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pharmacist_profile/image/cloudinary_service.dart';
import 'package:video_compress/video_compress.dart';

class VideoUploadService {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<String?> compressAndUploadVideo(File videoFile) async {
    File fileToUpload = videoFile;

    try {
      // 1. Safety check
      if (VideoCompress.isCompressing) {
        await VideoCompress.cancelCompression();
      }

      // 2. Attempt to compress the video safely
      final MediaInfo? compressedInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedInfo?.file != null) {
        fileToUpload = compressedInfo!.file!;
      }
    } catch (e) {
      debugPrint("Video compression skipped/failed, falling back to original file: $e");
      try {
        await VideoCompress.cancelCompression();
      } catch (_) {}
    }

    try {
      // 3. Upload to Cloudinary (either compressed or original fallback)
      final String? secureUrl = await _cloudinaryService.uploadVideo(fileToUpload);

      // 4. Clean up local compression cache safely
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}

      return secureUrl; // Returns the valid Cloudinary URL to insert into Supabase!

    } catch (e) {
      debugPrint("Cloudinary video upload error: $e");
      return null;
    }
  }
}