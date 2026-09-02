import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImagePickerHelper {
  final ImagePicker _picker = ImagePicker();

  // Pick an image from Gallery or Camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Compress slightly for faster uploads
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
    return null;
  }

  // Optional: Upload the image to Supabase Storage and return the public URL
  Future<String?> uploadImageToSupabase({
    required File imageFile,
    required String bucketName,
    required String folderPath,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$folderPath/$fileName';

      // Upload file to Supabase bucket
      await supabase.storage.from(bucketName).upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Get public URL of the uploaded image
      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint("Error uploading image to Supabase: $e");
      return null;
    }
  }
}

// Reusable Bottom Sheet to choose between Gallery or Camera
void showImageSourceSelector(
    BuildContext context, {
      required Function(File) onImageSelected,
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
            "Add Photo",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
            title: const Text("Choose from Gallery"),
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
        ],
      ),
    ),
  );
}