import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:pharmacist_profile/dashboard/post/Like_reaction_button_likefb.dart';
import 'package:pharmacist_profile/dashboard/post/comments_bottom_sheet.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Likecommentshare extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(int newCount, bool isLiked)? onReactionChanged;
  final Function(int newSharesCount)? onShareChanged;
  final Function(int newCommentsCount)? onCommentChanged;

  const Likecommentshare({
    super.key,
    required this.post,
    this.onReactionChanged,
    this.onShareChanged,
    this.onCommentChanged,
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

  // --- GENERIC NOTIFICATION HELPER ---
  Future<void> _sendNotification({
    required String type,      // 'like', 'comment', or 'share'
    required String bodyText,  // e.g. 'liked your post.'
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint("❌ Notification Error: No logged-in user found.");
      return;
    }

    // Resolves post owner ID with fallbacks
    final postOwnerUserId = widget.post['user_id']?.toString() ??
        widget.post['pcb_id']?.toString() ??
        widget.post['author_id']?.toString();

    if (postOwnerUserId == null || postOwnerUserId.isEmpty) {
      debugPrint("❌ Notification Error: Post owner user_id is missing or empty.");
      return;
    }

    debugPrint("🔍 Notification check: Actor ($currentUserId) -> Post Owner ($postOwnerUserId)");

    // Do not notify if user interacts with their own post
    if (postOwnerUserId != currentUserId) {
      try {
        String actorName = 'Someone';
        String? actorAvatar;

        // Fetch current user's profile details safely
        try {
          final userProfile = await Supabase.instance.client
              .from('pcb')
              .select('name, image_url')
              .eq('user_id', currentUserId)
              .maybeSingle();

          if (userProfile != null) {
            actorName = userProfile['name'] ?? 'Someone';
            actorAvatar = userProfile['image_url'];
          }
        } catch (profileErr) {
          debugPrint("⚠️ Warning: Could not fetch actor profile: $profileErr");
        }

        final payload = {
          'user_id': postOwnerUserId,   // Recipient post owner
          'actor_id': currentUserId,    // Current actor
          'actor_avatar': actorAvatar,
          'title': actorName,
          'body': bodyText,
          'type': type,
          'is_read': false,
        };

        debugPrint("📤 Inserting notification payload: $payload");

        final response = await Supabase.instance.client
            .from('pcb_notifications')
            .insert(payload)
            .select();

        debugPrint("✅ Notification inserted successfully! Response: $response");
      } catch (e) {
        debugPrint("❌ CRITICAL Error inserting $type notification: $e");
      }
    } else {
      debugPrint("ℹ️ Skipping notification: User interacted with their own post.");
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 4),

        // --- LIKE, COMMENT, SHARE ACTION BAR ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // --- Like Reaction Button ---
            FacebookReactionButton(
              post: post,
              onReactionChanged: (newLikeCount, isLiked) {
                setState(() {
                  _likesCount = newLikeCount;
                  _isLiked = isLiked;
                  post['likes_count'] = newLikeCount;
                });

                if (widget.onReactionChanged != null) {
                  widget.onReactionChanged!(newLikeCount, isLiked);
                }

                debugPrint("❤️ Like button toggled! isLiked: $isLiked");

                if (isLiked) {
                  _sendNotification(
                    type: 'like',
                    bodyText: 'liked your post.',
                  );
                }
              },
            ),

            // --- Comment Button ---
            TextButton.icon(
              onPressed: () {
                _sendNotification(
                  type: 'comment',
                  bodyText: 'commented on your post.',
                );

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
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),

            // --- Share Button ---
            TextButton.icon(
              onPressed: () async {
                final supabase = Supabase.instance.client;
                final String postId = post['id'].toString();
                final String postLink = "https://codninesx-maker.github.io/pcb-app/#/post/$postId";
                final String shareContent = "Check this out on Pcb App. Click to view the post instantly:\n$postLink";

                // 1. Optimistic UI update
                setState(() {
                  _sharesCount++;
                  post['shares_count'] = _sharesCount;
                });

                if (widget.onShareChanged != null) {
                  widget.onShareChanged!(_sharesCount);
                }

                // 2. Trigger Share Notification to post owner
                await _sendNotification(
                  type: 'share',
                  bodyText: 'shared your post.',
                );

                // 3. Persist updated share count in Supabase DB
                try {
                  await supabase
                      .from('pcb_posts')
                      .update({'shares_count': _sharesCount})
                      .eq('id', postId);
                  debugPrint("✅ Share count persisted in database: $_sharesCount");
                } catch (e) {
                  debugPrint("❌ Error updating share count in DB: $e");
                }

                // 4. Open native platform share sheet
                try {
                  await Share.share(shareContent);
                } catch (e) {
                  debugPrint("❌ Error opening share sheet: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not open share sheet")),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
              label: Text(
                _sharesCount > 0 ? "$_sharesCount" : "Share",
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}