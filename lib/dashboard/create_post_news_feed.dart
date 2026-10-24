import 'dart:convert';
import 'dart:io';
import 'package:pharmacist_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:pharmacist_profile/dashboard/post/like_coments_share.dart';
import 'package:pharmacist_profile/media/Liveplaceholder.dart';
import 'package:pharmacist_profile/dashboard/post/edit_post.dart';
import 'package:pharmacist_profile/threedot/ReportPost.dart';
import 'package:pharmacist_profile/video/feed_video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommunityNewsFeedSection extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> postsFuture;
  final VoidCallback onCreatePostPressed;
  final VoidCallback onPostsRefreshed;
  final ValueChanged<String?> onNavigateToAuthorprofile;
  final ValueChanged<String> onShowImagePreview;
  final ValueChanged<dynamic> onConfirmDeletePost;

  const CommunityNewsFeedSection({
    super.key,
    required this.postsFuture,
    required this.onCreatePostPressed,
    required this.onPostsRefreshed,
    required this.onNavigateToAuthorprofile,
    required this.onShowImagePreview,
    required this.onConfirmDeletePost,
  });

  @override
  State<CommunityNewsFeedSection> createState() => _CommunityNewsFeedSectionState();
}

class _CommunityNewsFeedSectionState extends State<CommunityNewsFeedSection> {
  static const String _cachedPostsKey = 'cached_community_posts';
  late Future<List<Map<String, dynamic>>> _combinedFuture;

  final AudioPlayer _audioPlayer = AudioPlayer();
  OverlayEntry? _overlayEntry;

  // Track expanded state for each post ID
  final Map<dynamic, bool> _expandedPosts = {};

  @override
  void initState() {
    super.initState();
    _combinedFuture = _fetchWithOfflineFallback();
  }

  @override
  void didUpdateWidget(covariant CommunityNewsFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postsFuture != widget.postsFuture) {
      setState(() {
        _combinedFuture = _fetchWithOfflineFallback();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWithOfflineFallback() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final posts = await widget.postsFuture;
      if (posts.isNotEmpty) {
        await prefs.setString(_cachedPostsKey, jsonEncode(posts));
      }
      return posts;
    } catch (e) {
      final cachedString = prefs.getString(_cachedPostsKey);
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        return decoded.map((item) {
          final mapItem = Map<String, dynamic>.from(item);
          if (mapItem['pcb'] != null) {
            mapItem['pcb'] = Map<String, dynamic>.from(mapItem['pcb']);
          }
          return mapItem;
        }).toList();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _removeOverlay();
    super.dispose();
  }

  String _formatTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (_) {}
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "News Feed",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LiveScreenPlaceholder(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam, color: Colors.red, size: 22),
                  tooltip: 'Live',
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: widget.onCreatePostPressed,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Create Post"),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _combinedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  "No posts yet. Be the first to share something!",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            int adCount = posts.isEmpty ? 0 : posts.length ~/ 4;
            int totalItems = posts.length + adCount;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                final bool isAdSlot = (index + 1) % 5 == 0 && posts.length >= 4;

                if (isAdSlot) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 50,
                      child: pharmacistTestBanner(adSize: AdSize.banner),
                    ),
                  );
                }

                int adsBeforeThis = index ~/ 5;
                int postIndex = index - adsBeforeThis;

                if (postIndex < 0 || postIndex >= posts.length) {
                  return const SizedBox.shrink();
                }

                final post = posts[postIndex];
                final postId = post['id'];

                final profile = post['pcb'] ?? {};
                final userName = profile['name'] ?? 'Anonymous Professional';
                final userImage = profile['image_url'];
                final content = post['content'] ?? '';

                final postImageUrl = post['image_url'];
                final postVideoUrl = post['video_url'];
                final mediaType = post['media_type'];

                final createdAt = post['created_at'];

                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final postUserId = post['user_id'];
                final isMyPost = currentUserId != null &&
                    (postUserId == currentUserId || profile['user_id'] == currentUserId);

                final bool isExpanded = _expandedPosts[postId] ?? false;

                void showManagePostBottomSheet() {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (BuildContext context) {
                      return SafeArea(
                        child: Wrap(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                "Manage Post",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.copy, color: Colors.blueGrey),
                              title: const Text("Copy Text"),
                              onTap: () {
                                Navigator.pop(context);
                                if (content.isNotEmpty) {
                                  final String postId = post['id'].toString();
                                  // Using your Play Store link (or deep link if preferred)
                                  final String postLink = "https://play.google.com/store/apps/details?id=com.rxai.pcb";
                                  final String combinedText = "$content\n\nDownload PCB App: $postLink";

                                  Clipboard.setData(ClipboardData(text: combinedText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Post text and app link copied to clipboard!"),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (isMyPost) ...[
                              ListTile(
                                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                                title: const Text("Edit Post"),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditPostScreen(post: post),
                                    ),
                                  );
                                  if (result == true) {
                                    widget.onPostsRefreshed();
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete, color: Colors.redAccent),
                                title: const Text("Delete Post"),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onConfirmDeletePost(post['id']);
                                },
                              ),
                            ] else ...[
                              ListTile(
                                leading: const Icon(Icons.report, color: Colors.orange),
                                title: const Text("Report Post"),
                                onTap: () {
                                  Navigator.pop(context); // Close the bottom sheet
                                  ReportHelper.reportPostToWhatsApp(
                                    context,
                                    post['id'].toString(),
                                    content,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                }

                return Card(
                  key: ValueKey(postId),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // --- AVATAR: Tapping opens full-screen image preview ---
                            GestureDetector(
                              onTap: () {
                                if (userImage != null && userImage.toString().isNotEmpty) {
                                  _showFullImage(context, userImage.toString());
                                }
                              },
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                backgroundImage: (userImage != null && userImage.toString().isNotEmpty)
                                    ? CachedNetworkImageProvider(userImage.toString()) as ImageProvider
                                    : null,
                                child: (userImage == null || userImage.toString().isEmpty)
                                    ? const Icon(Icons.person, size: 20, color: Colors.blueAccent)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- NAME: Tapping still goes to author profile ---
                                  InkWell(
                                    onTap: () => widget.onNavigateToAuthorprofile(postUserId),
                                    child: Text(
                                      userName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimeAgo(createdAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onPressed: showManagePostBottomSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (content.isNotEmpty) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Estimate text length for truncation (~3 lines / ~150 chars)
                              final bool isLongText = content.length > 150 || content.split('\n').length > 3;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Linkify(
                                    onOpen: (link) async {
                                      String urlString = link.url;
                                      if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
                                        urlString = 'https://$urlString';
                                      }
                                      final Uri url = Uri.parse(urlString);
                                      try {
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        } else {
                                          debugPrint('Could not launch $urlString');
                                        }
                                      } catch (e) {
                                        debugPrint('Error launching link: $e');
                                      }
                                    },
                                    text: content,
                                    maxLines: isExpanded ? null : 3,
                                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                    linkStyle: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  if (isLongText) ...[
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _expandedPosts[postId] = !isExpanded;
                                        });
                                      },
                                      child: Text(
                                        isExpanded ? "See Less" : "See More...",
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],

                        if (postImageUrl != null && postImageUrl.toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => widget.onShowImagePreview(postImageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: postImageUrl.toString(),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                        if ((postVideoUrl != null && postVideoUrl.toString().isNotEmpty) || mediaType == 'video') ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.black,
                              child: FeedVideoPlayer(videoUrl: postVideoUrl ?? post['media_url'] ?? ''),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 4),

                        // --- Unified Action Component ---
                        Likecommentshare(
                          post: post,
                          onReactionChanged: (newLikesCount, isLiked) {
                            setState(() {
                              post['likes_count'] = newLikesCount;
                            });
                          },
                          onShareChanged: (newSharesCount) {
                            setState(() {
                              post['shares_count'] = newSharesCount;
                            });
                          },
                          onCommentChanged: (newCommentsCount) {
                            setState(() {
                              post['comments_count'] = newCommentsCount;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}