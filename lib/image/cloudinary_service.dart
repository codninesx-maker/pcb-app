import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudinaryService {
  // Replace with your actual Cloud Name and Upload Preset
  final cloudinary = CloudinaryPublic('dow7ik5rv', 'doctor_preset', cache: false);

  Future<String?> uploadImage(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      debugPrint("DEBUG: Upload Success! URL: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      debugPrint("DEBUG: EXCEPTION in uploadImage: $e");
      return null;
    }
  }


  Future<void> deleteOldImage(String oldUrl) async {
    // Extract public_id: takes the part after the last slash and before the .jpg
    final uri = Uri.parse(oldUrl);
    final publicId = uri.pathSegments.last.split('.').first;

    final response = await Supabase.instance.client.functions.invoke(
      'delete-image',
      body: {'public_id': publicId},
    );

    if (response.status == 200) {
      print("Old image deleted from Cloudinary!");
    } else {
      print("Failed to delete: ${response.data}");
    }
  }
}