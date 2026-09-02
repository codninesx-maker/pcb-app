import 'dart:io';
import 'package:doctor_profile/image/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'emogi.dart'; // Make sure this points to your emoji picker widget file
import 'image.dart'; // Make sure this points to your image picker file
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _contentController;
  final _supabase = Supabase.instance.client;
  bool _isUpdating = false;

  // Facebook features and media variables
  String _audience = "Public"; // Can also be loaded if your post table stores audience settings
  File? _selectedNewImageFile; // For a newly picked image
  String? _existingImageUrl;   // For an image that was already saved on the post
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    // Pre-fill fields with existing post data
    _contentController = TextEditingController(text: widget.post['content'] ?? '');
    _existingImageUrl = widget.post['image_url'];
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<File?> compressImageToTargetSize(File file, {int targetKb = 50}) async {
    final targetBytes = targetKb * 1024;

    // If the original file is already smaller than the target, return it directly
    if (await file.length() <= targetBytes) {
      return file;
    }

    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

    int quality = 90;
    File? resultFile;

    // Iteratively reduce quality until we reach around 50kb or quality drops too low
    while (quality > 10) {
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 800, // Optional: Resize bounds to lower file size further
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        resultFile = File(result.path);
        int size = await resultFile.length();
        if (size <= targetBytes) {
          break; // Reached target size
        }
      }
      quality -= 15; // Step down quality
    }

    return resultFile ?? file;
  }

  Future<void> _updatePost() async {
    final updatedContent = _contentController.text.trim();
    if (updatedContent.isEmpty && _selectedNewImageFile == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final postId = widget.post['id'];
      String? finalImageUrl = _existingImageUrl;
      final String? oldImageUrl = widget.post['image_url'];

      // 2. Handle Image Changes
      if (_selectedNewImageFile != null) {
        // Compress the image down to ~50kb before uploading
        File? compressedFile = await compressImageToTargetSize(_selectedNewImageFile!, targetKb: 50);

        // Upload the newly selected (and compressed) image to Cloudinary
        finalImageUrl = await _cloudinaryService.uploadImage(compressedFile ?? _selectedNewImageFile!);
        if (finalImageUrl == null) {
          throw Exception("Failed to upload new image to Cloudinary.");
        }

        // Optional: Delete the old image from Cloudinary if it existed
        if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
          await _cloudinaryService.deleteOldImage(oldImageUrl);
        }
      } else if (_existingImageUrl == null && oldImageUrl != null && oldImageUrl.isNotEmpty) {
        // User explicitly removed the image during edit
        await _cloudinaryService.deleteOldImage(oldImageUrl);
        finalImageUrl = null;
      }

      // 3. Update the post row in Supabase
      await _supabase
          .from('pcb_posts')
          .update({
        'content': updatedContent,
        'image_url': finalImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', postId);

      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger news feed refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating post: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAudienceSelector() {
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
              "Select Audience",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.blueAccent),
              title: const Text("Public"),
              subtitle: const Text("Anyone on or off the platform"),
              onTap: () {
                setState(() => _audience = "Public");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Colors.green),
              title: const Text("Professionals Only"),
              subtitle: const Text("Only verified members in PCB"),
              onTap: () {
                setState(() => _audience = "Professionals");
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['pcb'] ?? {};
    final displayName = profile['name'] ?? 'User';
    final userImage = profile['image_url'];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Post",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isUpdating ? null : _updatePost,
              child: _isUpdating
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- USER INFO & AUDIENCE DROPLET ---
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: (userImage != null && userImage.isNotEmpty)
                              ? NetworkImage(userImage)
                              : null,
                          child: (userImage == null || userImage.isEmpty)
                              ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: _showAudienceSelector,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _audience == "Public" ? Icons.public : Icons.group,
                                      size: 12,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _audience,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.arrow_drop_down, size: 14, color: Colors.black54),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- TEXT INPUT FIELD ---
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      minLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: "What's on your mind, $displayName?",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),

                    // --- MEDIA PREVIEW BOX (NEWLY PICKED OR EXISTING IMAGE) ---
                    if (_selectedNewImageFile != null) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedNewImageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () => setState(() => _selectedNewImageFile = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _existingImageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () => setState(() => _existingImageUrl = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // --- FACEBOOK-STYLE BOTTOM TOOLBAR ---
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: bottomInset > 0 ? 10 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add to your post", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.green),
                        tooltip: "Photo/Video",
                        onPressed: () {
                          showImageSourceSelector(
                            context,
                            onImageSelected: (file) {
                              setState(() {
                                _selectedNewImageFile = file;
                                _existingImageUrl = null; // Override existing image with new selection
                              });
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.blue),
                        tooltip: "Tag People",
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tagging feature coming soon!")),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.insert_emoticon, color: Colors.amber),
                        tooltip: "Insert Emoji",
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => EmojiPickerSheet(
                              onEmojiSelected: (emoji) {
                                setState(() {
                                  _contentController.text += emoji;
                                  _contentController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _contentController.text.length),
                                  );
                                });
                              },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.location_on, color: Colors.redAccent),
                        tooltip: "Check in",
                        onPressed: () {
                          setState(() {
                            _contentController.text += " 📍 [Location]";
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}