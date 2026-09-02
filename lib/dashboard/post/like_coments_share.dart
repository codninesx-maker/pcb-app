import 'package:doctor_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class Likecommentshare extends StatefulWidget {
  final Map<String, dynamic> post;

  const Likecommentshare({
    super.key,
    required this.post,
  });

  @override
  State<Likecommentshare> createState() => _LikecommentshareState();
}

class _LikecommentshareState extends State<Likecommentshare> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Stops Flutter from recycling state/jumping when scrolling

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

    setState(() {
      _isLiked = currentUserId.isNotEmpty && userList.contains(currentUserId);
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
        _commentsCount = widget.post['comments_count'] ?? _commentsCount;
        _sharesCount = widget.post['shares_count'] ?? _sharesCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final post = widget.post;

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
                  child: post['user_avatar'] == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post['user_name'] ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- 2. POST CONTENT ---
            Text(
              post['content'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 4),

            // --- 3. LIKE, COMMENT, SHARE ACTION BAR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // --- Like Button ---
                TextButton.icon(
                  onPressed: () async {
                    final authUser = Supabase.instance.client.auth.currentUser;
                    if (authUser == null) return;

                    final currentUserId = authUser.id;
                    final newLikedState = !_isLiked;
                    final newLikes = _likesCount + (newLikedState ? 1 : -1);

                    String currentLikedBy = post['liked_by']?.toString() ?? '';
                    List<String> userList = currentLikedBy
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    if (newLikedState) {
                      if (!userList.contains(currentUserId)) {
                        userList.add(currentUserId);
                      }
                    } else {
                      userList.remove(currentUserId);
                    }

                    final String? finalLikedByString = userList.isEmpty ? null : userList.join(',');

                    setState(() {
                      _isLiked = newLikedState;
                      _likesCount = newLikes < 0 ? 0 : newLikes;
                      post['is_liked'] = newLikedState;
                      post['likes_count'] = _likesCount;
                      post['liked_by'] = finalLikedByString;
                    });

                    try {
                      await Supabase.instance.client
                          .from('pcb_posts')
                          .update({
                        'likes_count': _likesCount,
                        'liked_by': finalLikedByString,
                      })
                          .eq('id', post['id']);
                    } catch (e) {
                      debugPrint("Error updating likes: $e");
                    }
                  },
                  icon: Icon(
                    _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 16,
                    color: _isLiked ? Colors.blueAccent : Colors.grey,
                  ),
                  label: Text(
                    _likesCount > 0 ? "$_likesCount" : "Like",
                    style: TextStyle(
                      color: _isLiked ? Colors.blueAccent : Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // --- Comment Button ---
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
                  onPressed: () {
                    // Generate a unique link representation for the post (Facebook style)
                    final String postLink = "https://yourdomain.com/posts/${post['id']}";

                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => SafeArea(
                        child: Wrap(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                "Share Options",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const Divider(height: 1),

                            // --- 1. Open Post Directly ---
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Icon(Icons.open_in_new, color: Colors.white, size: 20),
                              ),
                              title: const Text("Open Post"),
                              subtitle: const Text("View this post immediately"),
                              onTap: () {
                                Navigator.pop(context);
                              },
                            ),

                            // --- 2. Copy Link ---
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.link, color: Colors.white, size: 20),
                              ),
                              title: const Text("Copy Link & Open"),
                              subtitle: const Text("Copy link and view instantly"),
                              onTap: () async {
                                Navigator.pop(context);

                                // 1. Define the exact link
                                final String postLink = "https://codninesx-maker.github.io/ad/1ae60096-726e-450f-9791-b7e647d90358";

                                // 2. Copy to clipboard with your custom format message
                                final String shareContent = "Check this out on Lokko Market. Click to view the post instantly:\n$postLink";
                                Clipboard.setData(ClipboardData(text: shareContent));

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Link copied & opening...")),
                                );

                                // 3. Instantly open the link in the browser
                                final Uri uri = Uri.parse(postLink);
                                try {
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else {
                                    debugPrint("Could not launch $postLink");
                                  }
                                } catch (e) {
                                  debugPrint("Error launching URL: $e");
                                }
                              },
                            ),

                            // --- 3. Share Externally (Facebook style) ---
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.share, color: Colors.white, size: 20),
                              ),
                              title: const Text("Share Externally"),
                              subtitle: const Text("Share via other installed apps"),
                              onTap: () async {
                                Navigator.pop(context);

                                // Increment counts locally & update database
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
                                  debugPrint("Error sharing: $e");
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
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