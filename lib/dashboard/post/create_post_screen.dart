import 'dart:io';
import 'package:doctor_profile/dashboard/post/emogi.dart';
import 'package:doctor_profile/image/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'image.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isPosting = false;
  bool _isLoadingProfile = true;

  // User profile details from Supabase 'pcb' table
  String _displayName = "User";
  String? _avatarUrl;
  String? _profileId;


  // Simulated Facebook features & Media handling
  String _audience = "Public";
  File? _selectedImageFile; // <-- Defined here properly!

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

      // Query the 'pcb' table for the user's name and profile image URL
      final response = await _supabase
          .from('pcb')
          .select('id, name, image_url')
          .eq('user_id', authUser.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _profileId = response['id']?.toString();
          _displayName = response['name'] ?? authUser.email?.split('@')[0] ?? "User";
          _avatarUrl = response['image_url'];
          _isLoadingProfile = false;
        });
      } else {
        // Fallback to auth metadata if no profile row exists yet
        setState(() {
          _profileId = authUser.id;
          _displayName = authUser.userMetadata?['full_name'] ?? authUser.email?.split('@')[0] ?? "User";
          _avatarUrl = authUser.userMetadata?['avatar_url'];
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
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

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImageFile == null) return;

    setState(() => _isPosting = true);

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw "You must be logged in to create a post.";
      }

      // Ensure we have a valid profile ID. If _profileId is a UUID string
      // but your pcb table uses bigint IDs, we should double-check or fetch it.
      dynamic targetUserId = _profileId;

      if (targetUserId == null || targetUserId == authUser.id) {
        // Double check if we can grab the integer ID directly from pcb table
        final pcbCheck = await _supabase
            .from('pcb')
            .select('id')
            .eq('user_id', authUser.id)
            .maybeSingle();

        if (pcbCheck != null && pcbCheck['id'] != null) {
          targetUserId = pcbCheck['id'];
        }
      }

      String? imageUrl;

      if (_selectedImageFile != null) {
        // 1. Compress image to ~50kb
        File? compressedFile = await compressImageToTargetSize(_selectedImageFile!, targetKb: 50);

        // 2. Upload using your Cloudinary service
        final cloudinaryService = CloudinaryService();
        imageUrl = await cloudinaryService.uploadImage(compressedFile ?? _selectedImageFile!);
      }

      // Insert post into Supabase table 'pcb_posts'
      final insertResponse = await _supabase.from('pcb_posts').insert({
        'user_id': targetUserId,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      debugPrint("Post created successfully: $insertResponse");

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post published successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error creating post: $e");
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error creating post: $e"),
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
          "Create Post",
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
              onPressed: _isPosting ? null : _submitPost,
              child: _isPosting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    // --- REAL USER PROFILE IMAGE & NAME ---
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? Text(
                            _displayName.isNotEmpty ? _displayName[0].toUpperCase() : "U",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
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
                        hintText: "What's on your mind, $_displayName?",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),

                    // --- MEDIA PREVIEW BOX (UPDATED TO RENDER REAL FILE PREVIEW) ---
                    if (_selectedImageFile != null) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImageFile!,
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
                                onPressed: () => setState(() => _selectedImageFile = null),
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
                                _selectedImageFile = file;
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