import 'package:doctor_profile/profile/view_profile_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsBottomSheet extends StatefulWidget {
  final dynamic postId;
  final String? postOwnerId;
  final ScrollController scrollController;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.scrollController,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  String? _currentUserAvatar;
  String? _currentUserName;

  // Tracking if a comment is currently being edited
  String? _editingCommentId;
  late final RealtimeChannel _commentsChannel;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
    _fetchComments();
    _setupCommentsRealtime();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_commentsChannel);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .from('pcb')
            .select('name, image_url')
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            _currentUserName = profile['name'];
            _currentUserAvatar = profile['image_url'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching current user profile: $e");
    }
  }

  Future<void> _fetchComments() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('pcb_post_comments')
          .select('*')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> fetchedComments = List<Map<String, dynamic>>.from(response);

      for (var comment in fetchedComments) {
        String likedByText = comment['liked_by']?.toString() ?? '';

        // Clean up brackets or formatting artifacts if any exist
        likedByText = likedByText.replaceAll('[', '').replaceAll(']', '').trim();
        comment['liked_by'] = likedByText;

        // Standard split and trim check for exact user ID match
        final userList = likedByText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        comment['is_liked'] = currentUserId != null && userList.contains(currentUserId);

        final userId = comment['user_id'];
        if (userId != null) {
          final profileRes = await _supabase
              .from('pcb')
              .select('name, image_url')
              .eq('user_id', userId)
              .maybeSingle();

          if (profileRes != null) {
            comment['pcb'] = profileRes;
          }
        }
      }

      if (mounted) {
        setState(() {
          _comments = fetchedComments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments manually: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCommentLike(String commentId, int currentLikes, bool isCurrentlyLiked) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final bool willBeLiked = !isCurrentlyLiked;
    final int newLikesCount = willBeLiked
        ? currentLikes + 1
        : (currentLikes > 0 ? currentLikes - 1 : 0);

    final commentIndex = _comments.indexWhere((c) => c['id'].toString() == commentId);
    if (commentIndex == -1) return;

    String currentLikedBy = _comments[commentIndex]['liked_by']?.toString() ?? '';
    List<String> userList = currentLikedBy
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (willBeLiked) {
      if (!userList.contains(user.id)) {
        userList.add(user.id);
      }
    } else {
      userList.remove(user.id);
    }

    final String newLikedBy = userList.join(',');

    // Optimistic UI Update
    setState(() {
      final updatedComment = Map<String, dynamic>.from(_comments[commentIndex]);
      updatedComment['likes_count'] = newLikesCount;
      updatedComment['is_liked'] = willBeLiked;
      updatedComment['liked_by'] = newLikedBy;
      _comments[commentIndex] = updatedComment;
    });

    try {
      await _supabase
          .from('pcb_post_comments')
          .update({
        'likes_count': newLikesCount,
        'liked_by': newLikedBy,
      })
          .eq('id', commentId);

      debugPrint("Comment like synced successfully: $newLikedBy");
    } catch (e) {
      debugPrint("Error updating comment like: $e");
      await _fetchComments(); // Revert on error
    }
  }

  Future<void> _postOrUpdateComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingCommentId != null) {
        await _supabase
            .from('pcb_post_comments')
            .update({'content': text})
            .eq('id', _editingCommentId!);

        setState(() {
          _editingCommentId = null;
        });
      } else {
        await _supabase.from('pcb_post_comments').insert({
          'post_id': widget.postId,
          'user_id': user.id,
          'content': text,
          'likes_count': 0,
          'liked_by': [],
          'created_at': DateTime.now().toIso8601String(),
        });

        try {
          final postRes = await _supabase
              .from('pcb_posts')
              .select('comments_count')
              .eq('id', widget.postId)
              .single();

          final currentCount = int.tryParse(postRes['comments_count'].toString()) ?? 0;
          await _supabase
              .from('pcb_posts')
              .update({'comments_count': currentCount + 1})
              .eq('id', widget.postId);
        } catch (e) {
          debugPrint("Error updating comment count metric: $e");
        }
      }

      _commentController.clear();
      FocusScope.of(context).unfocus();
      await _fetchComments();
    } catch (e) {
      debugPrint("Error saving comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _supabase.from('pcb_post_comments').delete().eq('id', commentId);

      try {
        final postRes = await _supabase
            .from('pcb_posts')
            .select('comments_count')
            .eq('id', widget.postId)
            .single();

        final currentCount = int.tryParse(postRes['comments_count'].toString()) ?? 0;
        if (currentCount > 0) {
          await _supabase
              .from('pcb_posts')
              .update({'comments_count': currentCount - 1})
              .eq('id', widget.postId);
        }
      } catch (e) {
        debugPrint("Error decrementing comment count: $e");
      }

      await _fetchComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Comment deleted")),
        );
      }
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete comment: $e")),
      );
    }
  }

  void _startEditing(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['id'].toString();
      _commentController.text = comment['content'] ?? '';
    });
  }

  void _copyComment(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Comment copied to clipboard"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _navigateToProfile(String? userId) async {
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final fullProfile = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (context.mounted) {
        Navigator.pop(context);

        if (fullProfile != null) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileDetailScreen(doctor: fullProfile),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This user hasn't created a professional profile yet.")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading profile: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCommentOptions(BuildContext context, Map<String, dynamic> comment, String commentId, String content, bool isMyComment, bool canDelete) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  _copyComment(content);
                },
              ),
              if (isMyComment)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditing(comment);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteComment(commentId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _setupCommentsRealtime() {
    _commentsChannel = _supabase
        .channel('public:pcb_post_comments:${widget.postId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pcb_post_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: widget.postId,
      ),
      callback: (payload) {
        _fetchComments();
      },
    )
        .subscribe();
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Comments",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 4),
              Text(
                "(${_comments.length})",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _comments.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  "No comments yet",
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Be the first to share your thoughts!",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              final profile = comment['pcb'] ?? {};
              final name = profile['name'] ?? 'Facebook User';
              final avatar = profile['image_url'];
              final content = comment['content'] ?? '';
              final timeAgo = _formatTimeAgo(comment['created_at']);

              final commentId = comment['id'].toString();
              final commentUserId = comment['user_id']?.toString();
              final isMyComment = commentUserId == currentUserId;
              final canDelete = (commentUserId == currentUserId) || (widget.postOwnerId == currentUserId);

              final likesCount = int.tryParse(comment['likes_count']?.toString() ?? '0') ?? 0;
              final isLiked = comment['is_liked'] ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(commentUserId),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? const Icon(Icons.person, size: 18, color: Colors.blueAccent)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onLongPress: () => _showCommentOptions(
                                    context,
                                    comment,
                                    commentId,
                                    content,
                                    isMyComment,
                                    canDelete,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () => _navigateToProfile(commentUserId),
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          content,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0, top: 4),
                            child: Row(
                              children: [
                                Text(
                                  timeAgo,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _toggleCommentLike(commentId, likesCount, isLiked),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Text(
                                      isLiked ? "Liked" : "Like",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isLiked ? Colors.blueAccent : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                if (likesCount > 0) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.thumb_up, size: 11, color: Colors.blueAccent),
                                  const SizedBox(width: 3),
                                  Text(
                                    "$likesCount",
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_editingCommentId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Editing comment...", style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _editingCommentId = null;
                      _commentController.clear();
                    });
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: _currentUserAvatar != null ? NetworkImage(_currentUserAvatar!) : null,
                  child: _currentUserAvatar == null
                      ? const Icon(Icons.person, size: 16, color: Colors.blueAccent)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _editingCommentId != null ? "Edit your comment..." : "Write a comment...",
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  width: 40,
                  child: FloatingActionButton(
                    elevation: 0,
                    backgroundColor: Colors.blueAccent,
                    onPressed: _isSubmitting ? null : _postOrUpdateComment,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(_editingCommentId != null ? Icons.check : Icons.arrow_upward, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}