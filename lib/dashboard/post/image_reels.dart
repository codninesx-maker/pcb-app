import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharmacist_profile/image/cloudinary_service.dart';

class ImagePickerHelper {
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Pick an image from Gallery or Camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
    return null;
  }

  // Pick a video / reel from Gallery or Camera
  Future<File?> pickVideo(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 90), // Optimized for Reels/Short videos
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
    }
    return null;
  }

  // Upload file (Image or Reel) to Cloudinary via CloudinaryService
  Future<String?> uploadMediaFile({
    required File file,
    required bool isVideo,
  }) async {
    try {
      if (isVideo) {
        return await _cloudinaryService.uploadVideo(file);
      } else {
        return await _cloudinaryService.uploadImage(file);
      }
    } catch (e) {
      debugPrint("Error uploading file to Cloudinary: $e");
      return null;
    }
  }
}

// Reusable Bottom Sheet to choose between Photo or Reel upload
void showImageSourceSelector(
    BuildContext context, {
      required Function(File) onImageSelected,
      required Function(File) onVideoSelected,
    }) {
  final imageHelper = ImagePickerHelper();

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Media Type",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Photo Options Section
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
            title: const Text("Choose Photo from Gallery"),
            onTap: () async {
              Navigator.pop(context);
              final file = await imageHelper.pickImage(ImageSource.gallery);
              if (file != null) onImageSelected(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text("Take a Picture"),
            onTap: () async {
              Navigator.pop(context);
              final file = await imageHelper.pickImage(ImageSource.camera);
              if (file != null) onImageSelected(file);
            },
          ),
          const Divider(),

          // Reel / Video Options Section
          ListTile(
            leading: const Icon(Icons.video_library, color: Colors.orange),
            title: const Text("Choose Reel from Gallery"),
            onTap: () async {
              Navigator.pop(context);
              final file = await imageHelper.pickVideo(ImageSource.gallery);
              if (file != null) onVideoSelected(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.redAccent),
            title: const Text("Record a Reel"),
            onTap: () async {
              Navigator.pop(context);
              final file = await imageHelper.pickVideo(ImageSource.camera);
              if (file != null) onVideoSelected(file);
            },
          ),
        ],
      ),
    ),
  );
}