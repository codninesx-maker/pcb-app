import 'dart:io';
import 'package:pharmacist_profile/image/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'emogi.dart'; // Make sure this points to your emoji picker widget file
import 'image_reels.dart'; // Ensure this points to your image/video source picker utility
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

  // Media and Audience variables
  String _audience = "Public";
  File? _selectedNewImageFile;
  File? _selectedNewVideoFile;
  String? _existingImageUrl;
  bool _isVideo = false;

  // Author Profile Data
  Map<String, dynamic>? _authorProfile;
  bool _isLoadingProfile = true;

  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post['content'] ?? '');

    // Check existing media configuration
    _existingImageUrl = widget.post['media_url'] ?? widget.post['image_url'] ?? widget.post['video_url'];
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      final ext = _existingImageUrl!.split('?').first.toLowerCase();
      _isVideo = ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || ext.endsWith('.mkv');
    }

    _fetchAuthorProfile();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchAuthorProfile() async {
    try {
      final userId = widget.post['user_id'];
      if (userId == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      // Fetch profile from 'pcb' table by id or user_id
      final response = await _supabase
          .from('pcb')
          .select()
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _authorProfile = response;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching author profile: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<File?> compressImageToTargetSize(File file, {int targetKb = 50}) async {
    try {
      final targetBytes = targetKb * 1024;
      if (await file.length() <= targetBytes) return file;

      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

      int quality = 90;
      XFile? result;

      while (quality > 10) {
        result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          minWidth: 1024,
          minHeight: 1024,
          format: CompressFormat.jpeg,
        );

        if (result != null) {
          final compressedFile = File(result.path);
          if (await compressedFile.length() <= targetBytes) {
            return compressedFile;
          }
        }
        quality -= 15;
      }

      return result != null ? File(result.path) : file;
    } catch (e) {
      debugPrint("Compression error: $e");
      return file;
    }
  }

  Future<void> _updatePost() async {
    final updatedContent = _contentController.text.trim();
    if (updatedContent.isEmpty &&
        _selectedNewImageFile == null &&
        _selectedNewVideoFile == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post content or media cannot be entirely empty.")),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final postId = widget.post['id'];
      String? finalMediaUrl = _existingImageUrl;

      // Look up old media URL across all possible fields
      final String? oldMediaUrl = widget.post['media_url'] ?? widget.post['image_url'] ?? widget.post['video_url'];

      // Helper function to safely trigger deletion handling video/image resource types
      Future<void> deleteOldMedia(String url) async {
        try {
          // If your CloudinaryService handles videos/images internally via URL:
          await _cloudinaryService.deleteMedia(url);
        } catch (e) {
          debugPrint("Error deleting old media from Cloudinary: $e");
        }
      }

      // Handle New Image Upload
      if (_selectedNewImageFile != null) {
        File? compressedFile = await compressImageToTargetSize(_selectedNewImageFile!, targetKb: 100);
        finalMediaUrl = await _cloudinaryService.uploadImage(compressedFile ?? _selectedNewImageFile!);

        if (finalMediaUrl == null) throw Exception("Failed to upload new image.");

        if (oldMediaUrl != null && oldMediaUrl.isNotEmpty) {
          await deleteOldMedia(oldMediaUrl);
        }
      }
      // Handle New Video Upload
      else if (_selectedNewVideoFile != null) {
        // NOTE: Make sure your CloudinaryService supports video uploads (e.g., uploadVideo or generic upload)
        finalMediaUrl = await _cloudinaryService.uploadImage(_selectedNewVideoFile!);
        if (finalMediaUrl == null) throw Exception("Failed to upload new video.");

        if (oldMediaUrl != null && oldMediaUrl.isNotEmpty) {
          await deleteOldMedia(oldMediaUrl);
        }
      }
      // If user explicitly removed media (clicked the 'X' button on the preview)
      else if (_existingImageUrl == null && oldMediaUrl != null && oldMediaUrl.isNotEmpty) {
        await deleteOldMedia(oldMediaUrl);
        finalMediaUrl = null;
      }

      // Update Database Row
      await _supabase
          .from('pcb_posts')
          .update({
        'content': updatedContent,
        'image_url': finalMediaUrl,
        'media_url': finalMediaUrl,
        'video_url': _isVideo ? finalMediaUrl : null, // Ensure video_url column syncs if applicable
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', postId);

      if (mounted) {
        Navigator.pop(context, true);
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
            const Text("Select Audience", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    // Fallback profile details if fetched data or widget map has properties
    final profile = _authorProfile ?? widget.post['pcb'] ?? {};
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            Row(
                              children: [
                                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (_isLoadingProfile) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ],
                              ],
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
                                    Icon(_audience == "Public" ? Icons.public : Icons.group, size: 12, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(_audience, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
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

                    // --- MEDIA PREVIEW BOX ---
                    if (_selectedNewImageFile != null) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_selectedNewImageFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
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
                    ] else if (_selectedNewVideoFile != null) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Icon(Icons.videocam, size: 50, color: Colors.white)),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () => setState(() => _selectedNewVideoFile = null),
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
                            child: _isVideo
                                ? Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.black,
                              child: const Center(child: Icon(Icons.play_circle_fill, size: 60, color: Colors.white)),
                            )
                                : Image.network(_existingImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
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

            // --- TOOLBAR ---
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset > 0 ? 10 : 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), offset: const Offset(0, -2), blurRadius: 4)],
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
                                _selectedNewVideoFile = null;
                                _existingImageUrl = null;
                                _isVideo = false;
                              });
                            },
                            onVideoSelected: (file) {
                              setState(() {
                                _selectedNewVideoFile = file;
                                _selectedNewImageFile = null;
                                _existingImageUrl = null;
                                _isVideo = true;
                              });
                            },
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