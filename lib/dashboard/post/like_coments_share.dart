import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharmacist_profile/dashboard/post/Like_reaction_button_likefb.dart';
import 'package:pharmacist_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

class Likecommentshare extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(int newCount, bool isLiked)? onReactionChanged;

  const Likecommentshare({
    super.key,
    required this.post,
    this.onReactionChanged,
  });

  @override
  State<Likecommentshare> createState() => _LikecommentshareState();
}

class _LikecommentshareState extends State<Likecommentshare> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive =>
      true; // Stops Flutter from recycling state/jumping when scrolling

  late bool _isLiked = false;
  late int _likesCount = 0;
  late int _commentsCount = 0;
  late int _sharesCount = 0;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    final authUser = Supabase.instance.client.auth.currentUser;
    final String currentUserId = authUser?.id ?? '';
    final String likedByText = widget.post['liked_by']?.toString() ?? '';

    final userList = likedByText
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Fix: check if any entry matches the user ID or starts with userId:
    final bool hasLiked = currentUserId.isNotEmpty &&
        userList.any((e) =>
        e == currentUserId || e.startsWith('$currentUserId:'));

    setState(() {
      _isLiked = hasLiked;
      _likesCount = widget.post['likes_count'] ?? 0;
      _commentsCount = widget.post['comments_count'] ?? 0;
      _sharesCount = widget.post['shares_count'] ?? 0;
    });
  }

  @override
  void didUpdateWidget(covariant Likecommentshare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post['id'] != oldWidget.post['id']) {
      _initValues();
    } else {
      setState(() {
        _likesCount = widget.post['likes_count'] ?? _likesCount;
        _commentsCount = widget.post['comments_count'] ?? _commentsCount;
        _sharesCount = widget.post['shares_count'] ?? _sharesCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final post = widget.post;

    // --- MEDIA PARSING LOGIC ---
    final String? mediaUrl = post['media_url'] ?? post['video_url'] ??
        post['image_url'];
    final String? mediaType = post['media_type'];

    bool isVideo = mediaType == 'video' ||
        (mediaUrl != null &&
            (mediaUrl.endsWith('.mp4') || mediaUrl.contains('/video/')));

    bool isImage = mediaType == 'image' ||
        (mediaUrl != null && !isVideo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 1. POST HEADER ---
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post['user_avatar'] != null
                      ? NetworkImage(post['user_avatar'])
                      : null,
                  child: post['user_avatar'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post['user_name'] ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- 2. POST CONTENT ---
            if (post['content'] != null && post['content']
                .toString()
                .isNotEmpty) ...[
              Text(
                post['content'],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
            ],

            // --- 3. MEDIA RENDERING (IMAGE OR VIDEO) ---
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  width: double.infinity,
                  color: Colors.black12,
                  child: isVideo
                      ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    color: Colors.black,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.white,
                            size: 50),
                        SizedBox(height: 8),
                        Text("Video Content", style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  )
                      : Image.network(
                    mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Could not load media", style: TextStyle(
                          color: Colors.grey)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 4),

            // --- 4. LIKE, COMMENT, SHARE ACTION BAR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // --- Like Button ---
                FacebookReactionButton(
                  post: post,
                  onReactionChanged: (newLikeCount, isLiked) {
                    setState(() {
                      _likesCount = newLikeCount;
                      _isLiked = isLiked;
                      post['likes_count'] = newLikeCount;
                    });
                  },
                ),

                // --- Comment Button ---
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      builder: (context) =>
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery
                                  .of(context)
                                  .viewInsets
                                  .bottom,
                            ),
                            child: DraggableScrollableSheet(
                              initialChildSize: 0.6,
                              minChildSize: 0.3,
                              maxChildSize: 0.9,
                              expand: false,
                              builder: (context, scrollController) =>
                                  CommentsBottomSheet(
                                    postId: post['id'],
                                    scrollController: scrollController,
                                    postOwnerId: post['user_id'],
                                  ),
                            ),
                          ),
                    );
                  },
                  icon: const Icon(
                      Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                  label: Text(
                    _commentsCount > 0 ? "$_commentsCount" : "Comment",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // --- Share Button ---
                TextButton.icon(
                  onPressed: () async {
                    final String postLink = "https://codninesx-maker.github.io/pcb-app/#/post/${post['id']}";
                    final String shareContent = "Check this out on PCB App. Click to view the post instantly:\n$postLink";

                    setState(() {
                      _sharesCount++;
                      post['shares_count'] = _sharesCount;
                    });

                    try {
                      await Supabase.instance.client
                          .from('pcb_posts')
                          .update({'shares_count': _sharesCount})
                          .eq('id', post['id']);
                    } catch (e) {
                      debugPrint("Error updating shares: $e");
                    }

                    try {
                      await Share.share(shareContent);
                    } catch (e) {
                      debugPrint("Error launching external share: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Could not open share sheet")),
                      );
                    }
                  },
                  icon: const Icon(
                      Icons.share_outlined, size: 16, color: Colors.grey),
                  label: Text(
                    _sharesCount > 0 ? "$_sharesCount" : "Share",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}