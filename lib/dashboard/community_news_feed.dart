import 'package:doctor_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:doctor_profile/dashboard/post/edit_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class CommunityNewsFeedSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> postsFuture;
  final VoidCallback onCreatePostPressed;
  final VoidCallback onPostsRefreshed;
  final ValueChanged<String?> onNavigateToAuthorProfile;
  final ValueChanged<String> onShowImagePreview;
  final ValueChanged<dynamic> onConfirmDeletePost;

  const CommunityNewsFeedSection({
    super.key,
    required this.postsFuture,
    required this.onCreatePostPressed,
    required this.onPostsRefreshed,
    required this.onNavigateToAuthorProfile,
    required this.onShowImagePreview,
    required this.onConfirmDeletePost,
  });

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
            TextButton.icon(
              onPressed: onCreatePostPressed,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text("Create Post"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: postsFuture,
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

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final profile = post['pcb'] ?? {};
                final userName = profile['name'] ?? 'Anonymous Professional';
                final userImage = profile['image_url'];
                final content = post['content'] ?? '';
                final postImageUrl = post['image_url'];
                final createdAt = post['created_at'];

                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final postUserId = post['user_id'];
                final isMyPost = currentUserId != null &&
                    (postUserId == currentUserId || profile['user_id'] == currentUserId);

                return GestureDetector(
                  onLongPress: () {
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
                                      onPostsRefreshed();
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                                  title: const Text("Delete Post"),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onConfirmDeletePost(post['id']);
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
                  },
                  child: Card(
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
                                onTap: () => onNavigateToAuthorProfile(postUserId),
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
                                      onTap: () => onNavigateToAuthorProfile(postUserId),
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (content.isNotEmpty) ...[
                            Text(
                              content,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87, height: 1.4),
                            ),
                          ],
                          if (postImageUrl != null && postImageUrl.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => onShowImagePreview(postImageUrl),
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
                          const SizedBox(height: 12),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 4),
                          StatefulBuilder(
                            builder: (context, setLocalState) {
                              final bool isLiked = post['is_liked'] ?? false;
                              final int likesCount = post['likes_count'] ?? 0;
                              final int commentsCount = post['comments_count'] ?? 0;
                              final int sharesCount = post['shares_count'] ?? 0;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final authUser = Supabase.instance.client.auth.currentUser;
                                      if (authUser == null) return;

                                      final currentUserId = authUser.id;
                                      final newLikedState = !isLiked;
                                      final newLikes = likesCount + (newLikedState ? 1 : -1);

                                      // 1. Get and parse existing liked_by string safely
                                      final String currentLikedBy = post['liked_by']?.toString() ?? '';
                                      List<String> userList = currentLikedBy
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .toList();

                                      // 2. Add or remove current user ID
                                      if (newLikedState) {
                                        if (!userList.contains(currentUserId)) {
                                          userList.add(currentUserId);
                                        }
                                      } else {
                                        userList.remove(currentUserId);
                                      }

                                      final String? finalLikedByString = userList.isEmpty ? null : userList.join(',');

                                      // 3. Update local state immediately
                                      setLocalState(() {
                                        post['is_liked'] = newLikedState;
                                        post['likes_count'] = newLikes < 0 ? 0 : newLikes;
                                        post['liked_by'] = finalLikedByString;
                                      });

                                      // 4. Sync both count and liked_by string to Supabase
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
                                    icon: Icon(
                                      isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                      size: 16,
                                      color: isLiked ? Colors.blueAccent : Colors.grey,
                                    ),
                                    label: Text(
                                      likesCount > 0 ? "$likesCount" : "Like",
                                      style: TextStyle(
                                        color: isLiked ? Colors.blueAccent : Colors.grey,
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
                                      commentsCount > 0 ? "$commentsCount" : "Comment",
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
                                      final String shareContent =
                                          "${post['content'] ?? 'Check out this post on PCB'}\n\nShared via PCB App";

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
                                                  "Share Post",
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.copy, color: Colors.blueAccent),
                                                title: const Text("Copy Post Link / Text"),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Clipboard.setData(ClipboardData(text: shareContent));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Post content copied to clipboard!")),
                                                  );
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.share, color: Colors.green),
                                                title: const Text("Share Externally"),
                                                onTap: () async {
                                                  Navigator.pop(context);

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

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Post shared successfully!")),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
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
                          ),
                        ],
                      ),
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