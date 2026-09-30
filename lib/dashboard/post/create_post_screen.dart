import 'dart:io';
import 'package:pharmacist_profile/dashboard/post/emogi.dart';
import 'package:pharmacist_profile/dashboard/post/image_reels.dart';
import 'package:pharmacist_profile/dashboard/post/live.dart';
import 'package:pharmacist_profile/dashboard/post/location_screen.dart';
import 'package:pharmacist_profile/dashboard/post/tagg.dart';
import 'package:pharmacist_profile/dashboard/post/video/video_upload_compress_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final ImagePickerHelper imageHelper = ImagePickerHelper();
  final VideoUploadService _videoUploadService = VideoUploadService();

  bool _isPosting = false;

  // User profile details from Supabase 'pcb' table
  String _displayName = "User";
  String? _avatarUrl;
  String? _profileId;
  String? _selectedLocation;

  // Features & Media handling
  String _audience = "Public";
  File? _selectedVideoFile;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _fetchUserprofile();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserprofile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

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
        });
      } else {
        // Profile row doesn't exist in the 'pcb' table yet
        if (mounted) {
          setState(() {
            _profileId = null; // Keep it null so we can catch it on submit
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<File?> compressImageToTargetSize(File file, {int targetKb = 50}) async {
    final targetBytes = targetKb * 1024;
    if (await file.length() <= targetBytes) return file;

    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

    int quality = 90;
    File? resultFile;

    while (quality > 10) {
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        resultFile = File(result.path);
        if (await resultFile.length() <= targetBytes) break;
      }
      quality -= 15;
    }

    return resultFile ?? file;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _submitPost() async {
    final textContent = _contentController.text.trim();
    if (textContent.isEmpty && _selectedImageFile == null && _selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add some text or media to post.")),
      );
      return;
    }

    // Graceful remarks instead of raw technical/Postgrest errors
    if (_profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete or create your profile before posting."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      String? uploadedVideoUrl;
      String? uploadedImageUrl;
      String mediaType = 'text';

      if (_selectedImageFile != null) {
        File? processedImage = await compressImageToTargetSize(_selectedImageFile!);
        uploadedImageUrl = await imageHelper.uploadMediaFile(
          file: processedImage ?? _selectedImageFile!,
          isVideo: false,
        );

        if (uploadedImageUrl == null || uploadedImageUrl.isEmpty) {
          throw "Image upload returned an invalid URL.";
        }
        mediaType = 'image';
      }

      if (_selectedVideoFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compressing and uploading video...')),
          );
        }

        uploadedVideoUrl = await _videoUploadService.compressAndUploadVideo(_selectedVideoFile!);

        if (uploadedVideoUrl == null || uploadedVideoUrl.isEmpty) {
          throw "Video upload returned an invalid URL.";
        }
        mediaType = 'video';
      }

      await _supabase.from('pcb_posts').insert({
        'user_id': _profileId,
        'content': textContent,
        'video_url': mediaType == 'video' ? uploadedVideoUrl : null,
        'image_url': mediaType == 'image' ? uploadedImageUrl : null,
        'media_url': mediaType == 'video' ? uploadedVideoUrl : uploadedImageUrl,
        'media_type': mediaType,
        'is_published': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error submitting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to complete your post. Please try again.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
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

                    if (_selectedVideoFile != null) ...[
                      const SizedBox(height: 15),
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.movie_creation, size: 50, color: Colors.orangeAccent),
                                  SizedBox(height: 8),
                                  Text(
                                    "Reel Selected",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
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
                                onPressed: () => setState(() => _selectedVideoFile = null),
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
                        icon: const Icon(Icons.perm_media, color: Colors.green),
                        tooltip: "Photo or Reel",
                        onPressed: () {
                          showImageSourceSelector(
                            context,
                            onImageSelected: (file) {
                              setState(() {
                                _selectedImageFile = file;
                                _selectedVideoFile = null;
                              });
                            },
                            onVideoSelected: (file) {
                              setState(() {
                                _selectedVideoFile = file;
                                _selectedImageFile = null;
                              });
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.blue),
                        tooltip: "Tag People",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TagUserScreen(
                                onUserTagged: (taggedUser) {
                                  final String taggedName = taggedUser['name'] ?? 'User';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Tagged: $taggedName"), backgroundColor: Colors.green),
                                  );
                                },
                              ),
                            ),
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
                      InkWell(
                        onTap: () async {
                          // Wait for LocationScreen to pop and return the selected string
                          final result = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationScreen(
                                onLocationSelected: (location) {
                                  debugPrint("Selected location: $location");
                                },
                              ),
                            ),
                          );

                          // If a location was picked, save it to state so the UI updates!
                          if (result != null) {
                            setState(() {
                              _selectedLocation = result;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.red, size: 18),
                              const SizedBox(width: 6),
                              // 3. Dynamically display the selected location or default text
                              Text(
                                _selectedLocation ?? "Location",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
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