import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:pharmacist_profile/dashboard/post/Liveplaceholder.dart';
import 'package:pharmacist_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:pharmacist_profile/dashboard/post/edit_post.dart';
import 'package:pharmacist_profile/dashboard/post/live.dart';
import 'package:pharmacist_profile/dashboard/post/video/feed_video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  OverlayEntry? _overlayEntry;

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

  (String, String, Color, IconData) _getReactionDisplay(String? reactionType) {
    switch (reactionType) {
      case 'love':
        return ('Love', '❤️', Colors.red, Icons.favorite);
      case 'haha':
        return ('Haha', '😂', Colors.amber, Icons.sentiment_very_satisfied);
      case 'wow':
        return ('Wow', '😮', Colors.amber, Icons.sentiment_satisfied);
      case 'sad':
        return ('Sad', '😢', Colors.amber, Icons.sentiment_dissatisfied);
      case 'angry':
        return ('Angry', '😡', Colors.deepOrange, Icons.local_fire_department);
      case 'like':
      default:
        return ('Like', '👍', Colors.blueAccent, Icons.thumb_up);
    }
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (_) {}
  }

  void _showReactionOverlay(BuildContext context, Map<String, dynamic> post, StateSetter setLocalState, GlobalKey buttonKey) {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx - 20,
            top: position.dy - 65,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  alignment: Alignment.bottomCenter,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionIcon('👍', 'like', Colors.blue, 'Like', post, setLocalState),
                    _buildReactionIcon('❤️', 'love', Colors.red, 'Love', post, setLocalState),
                    _buildReactionIcon('😂', 'haha', Colors.amber, 'Haha', post, setLocalState),
                    _buildReactionIcon('😮', 'wow', Colors.amber, 'Wow', post, setLocalState),
                    _buildReactionIcon('😢', 'sad', Colors.amber, 'Sad', post, setLocalState),
                    _buildReactionIcon('😡', 'angry', Colors.deepOrange, 'Angry', post, setLocalState),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildReactionIcon(String emoji, String reactionType, Color color, String label, Map<String, dynamic> post, StateSetter setLocalState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () async {
          _playSound();
          _removeOverlay();

          final authUser = Supabase.instance.client.auth.currentUser;
          if (authUser == null) return;

          final String currentLikedBy = post['liked_by']?.toString() ?? '';
          List<String> userList = currentLikedBy
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty && !e.startsWith('${authUser.id}:') && e != authUser.id)
              .toList();

          userList.add('${authUser.id}:$reactionType');
          int calculatedCount = userList.length;
          String finalString = userList.join(',');

          setLocalState(() {
            post['is_liked'] = true;
            post['likes_count'] = calculatedCount;
            post['liked_by'] = finalString;
          });

          try {
            await Supabase.instance.client
                .from('pcb_posts')
                .update({
              'likes_count': calculatedCount,
              'liked_by': finalString,
            })
                .eq('id', post['id']);
          } catch (e) {
            debugPrint("Error updating reaction: $e");
          }
        },
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
                // Live Icon-Only Button
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
                // Create Post Button
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
          future: widget.postsFuture,
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

                final GlobalKey uniqueButtonKey = GlobalKey();

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
                                  Clipboard.setData(ClipboardData(text: content));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Post text copied to clipboard!"),
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
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Post reported.")),
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
                  key: ValueKey(post['id']),
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
                            GestureDetector(
                              onTap: () => widget.onNavigateToAuthorprofile(postUserId),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                backgroundImage:
                                userImage != null ? NetworkImage(userImage) : null,
                                child: userImage == null
                                    ? const Icon(Icons.person, size: 20, color: Colors.blueAccent)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                        // --- FIXED LINKIFY WIDGET ---
                        if (content.isNotEmpty) ...[
                          Linkify(
                            onOpen: (link) async {
                              String urlString = link.url;
                              // Ensure URL has a valid scheme so it opens properly in external browsers
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
                        ],

                        if (postImageUrl != null && postImageUrl.toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => widget.onShowImagePreview(postImageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                postImageUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
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
                        StatefulBuilder(
                          builder: (context, setLocalState) {
                            final authUser = Supabase.instance.client.auth.currentUser;

                            // Parse liked_by string properly
                            final String likedByText = post['liked_by']?.toString() ?? '';
                            List<String> userList = likedByText
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            String? userEntry;
                            if (authUser != null) {
                              userEntry = userList.firstWhere(
                                    (e) => e == authUser.id || e.startsWith('${authUser.id}:'),
                                orElse: () => '',
                              );
                            }

                            final bool isLiked = userEntry != null && userEntry.isNotEmpty;
                            String? currentReaction;
                            if (isLiked) {
                              if (userEntry!.contains(':')) {
                                currentReaction = userEntry.split(':')[1];
                              } else {
                                currentReaction = 'like'; // Explicitly default plain user IDs to 'like'
                              }
                            }

                            final int likesCount = post['likes_count'] ?? 0;
                            final int commentsCount = post['comments_count'] ?? 0;
                            final int sharesCount = post['shares_count'] ?? 0;

                            // --- Get dynamic emoji, color, and icon data ---
                            final (labelName, emojiSymbol, color, iconData) = _getReactionDisplay(currentReaction);

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                KeyedSubtree(
                                  key: uniqueButtonKey,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async {
                                      if (authUser == null) return;
                                      _playSound();
                                      debugPrint("Play sound triggered for tap!");

                                      final currentUserId = authUser.id;

                                      // Filter out current user from the list
                                      List<String> updatedUserList = likedByText
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty && !e.startsWith('$currentUserId:') && e != currentUserId)
                                          .toList();

                                      // Facebook Behavior: If they already reacted with anything, tap removes it. If not, tap adds 'like'.
                                      bool willBeLiked = !isLiked;
                                      if (willBeLiked) {
                                        updatedUserList.add('$currentUserId:like');
                                      }

                                      int calculatedCount = updatedUserList.length;
                                      String? finalLikedByString = updatedUserList.isEmpty ? null : updatedUserList.join(',');

                                      setLocalState(() {
                                        post['likes_count'] = calculatedCount < 0 ? 0 : calculatedCount;
                                        post['liked_by'] = finalLikedByString;
                                      });

                                      try {
                                        await Supabase.instance.client
                                            .from('pcb_posts')
                                            .update({
                                          'likes_count': post['likes_count'],
                                          'liked_by': finalLikedByString,
                                        })
                                            .eq('id', post['id']);
                                      } catch (e) {
                                        debugPrint("Error updating likes: $e");
                                      }
                                    },
                                    onLongPress: () {
                                      _playSound();
                                      _showReactionOverlay(context, post, setLocalState, uniqueButtonKey);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isLiked ? iconData : Icons.thumb_up_outlined,
                                            size: 16,
                                            color: isLiked ? color : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isLiked
                                                ? labelName
                                                : (likesCount > 0 ? "$likesCount" : "Like"),
                                            style: TextStyle(
                                              color: isLiked ? color : Colors.grey,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                TextButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                      ),
                                      builder: (context) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(context).viewInsets.bottom,
                                        ),
                                        child: DraggableScrollableSheet(
                                          initialChildSize: 0.6,
                                          minChildSize: 0.3,
                                          maxChildSize: 0.9,
                                          expand: false,
                                          builder: (context, scrollController) => CommentsBottomSheet(
                                            postId: post['id'],
                                            scrollController: scrollController,
                                            postOwnerId: post['user_id'],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                                  label: Text(
                                    commentsCount > 0 ? "$commentsCount" : "Comment",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                TextButton.icon(
                                  onPressed: () async {
                                    final String postLink = "https://codninesx-maker.github.io/pcb-app/#/post/${post['id']}";
                                    final String postSnippet = post['content'] ?? 'Check out this post on PCB';
                                    final String shareContent = "Check this out on PCB App: \"$postSnippet\"\n\nClick to view instantly:\n$postLink";

                                    try {
                                      final newShares = sharesCount + 1;
                                      setLocalState(() {
                                        post['shares_count'] = newShares;
                                      });

                                      await Supabase.instance.client
                                          .from('pcb_posts')
                                          .update({'shares_count': newShares})
                                          .eq('id', post['id']);
                                    } catch (e) {
                                      debugPrint("Error updating shares: $e");
                                    }

                                    try {
                                      await Share.share(shareContent);
                                    } catch (e) {
                                      debugPrint("Error launching external share: $e");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Could not open share sheet")),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                                  label: Text(
                                    sharesCount > 0 ? "$sharesCount" : "Share",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
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