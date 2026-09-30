import 'package:flutter/material.dart';
import 'package:pharmacist_profile/dashboard/post/audiopop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';


class FacebookReactionButton extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(Map<String, dynamic> updatedPost)? onChanged;
  final Function(int newCount, bool isLiked)? onReactionChanged;

  const FacebookReactionButton({
    super.key,
    required this.post,
    this.onChanged,
    this.onReactionChanged,
  });

  @override
  State<FacebookReactionButton> createState() => _FacebookReactionButtonState();
}

class _FacebookReactionButtonState extends State<FacebookReactionButton> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  late bool _isLiked;
  late int _likesCount;
  String? _currentReaction;

  @override
  void initState() {
    super.initState();
    _parseInitialState();
  }

  @override
  void didUpdateWidget(covariant FacebookReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post['id'] != widget.post['id'] ||
        oldWidget.post['likes_count'] != widget.post['likes_count'] ||
        oldWidget.post['liked_by'] != widget.post['liked_by']) {
      _parseInitialState();
    }
  }

  void _parseInitialState() {
    _likesCount = widget.post['likes_count'] ?? 0;
    final authUser = Supabase.instance.client.auth.currentUser;

    if (authUser != null) {
      String currentLikedBy = widget.post['liked_by']?.toString() ?? '';
      List<String> userList = currentLikedBy
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String? userEntry = userList.firstWhere(
            (e) => e == authUser.id || e.startsWith('${authUser.id}:'),
        orElse: () => '',
      );

      if (userEntry.isNotEmpty) {
        _isLiked = true;
        if (userEntry.contains(':')) {
          _currentReaction = userEntry.split(':')[1];
        } else {
          _currentReaction = 'like';
        }
      } else {
        _isLiked = false;
        _currentReaction = null;
      }
    } else {
      _isLiked = false;
      _currentReaction = null;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _playSound() async {
    await AudioPop.play();
  }

  void _showReactionOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = _buttonKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: position.dx - 10,
            top: position.dy - 65,
            child: Material(
              color: Colors.transparent,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
                      _buildReactionIcon('👍', 'like', Colors.blue, 'Like'),
                      _buildReactionIcon('❤️', 'love', Colors.red, 'Love'),
                      _buildReactionIcon('😂', 'haha', Colors.amber, 'Haha'),
                      _buildReactionIcon('😮', 'wow', Colors.amber, 'Wow'),
                      _buildReactionIcon('😢', 'sad', Colors.amber, 'Sad'),
                      _buildReactionIcon('😡', 'angry', Colors.deepOrange, 'Angry'),
                    ],
                  ),
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

  Widget _buildReactionIcon(String emoji, String reactionType, Color color,
      String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () async {
          _playSound();
          _removeOverlay();
          await _handleReactionChange(reactionType);
        },
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  Future<void> _handleReactionChange(String newReaction) async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    String currentLikedBy = widget.post['liked_by']?.toString() ?? '';
    List<String> userList = currentLikedBy
        .split(',')
        .map((e) => e.trim())
        .where((e) =>
    e.isNotEmpty && !e.startsWith('${authUser.id}:') && e != authUser.id)
        .toList();

    userList.add('${authUser.id}:$newReaction');

    int calculatedCount = userList.length;
    String finalString = userList.join(',');

    setState(() {
      _isLiked = true;
      _currentReaction = newReaction;
      _likesCount = calculatedCount;
    });

    if (widget.onReactionChanged != null) {
      widget.onReactionChanged!(calculatedCount, true);
    }

    await _syncDatabase(finalString, calculatedCount);
  }

  Future<void> _handleTapAction() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    _playSound();

    String currentLikedBy = widget.post['liked_by']?.toString() ?? '';
    List<String> userList = currentLikedBy
        .split(',')
        .map((e) => e.trim())
        .where((e) =>
    e.isNotEmpty && !e.startsWith('${authUser.id}:') && e != authUser.id)
        .toList();

    bool willBeLiked = !_isLiked;

    if (willBeLiked) {
      userList.add('${authUser.id}:like');
    }

    int calculatedCount = userList.length;
    String finalString = userList.isEmpty ? '' : userList.join(',');

    setState(() {
      _isLiked = willBeLiked;
      _currentReaction = willBeLiked ? 'like' : null;
      _likesCount = calculatedCount;
    });

    if (widget.onReactionChanged != null) {
      widget.onReactionChanged!(calculatedCount, willBeLiked);
    }

    await _syncDatabase(finalString, calculatedCount);
  }

  Future<void> _syncDatabase(String finalLikedByString,
      int calculatedCount) async {
    try {
      final updatedData = Map<String, dynamic>.from(widget.post);
      updatedData['likes_count'] = calculatedCount;
      updatedData['liked_by'] =
      finalLikedByString.isEmpty ? null : finalLikedByString;

      await Supabase.instance.client
          .from('pcb_posts')
          .update({
        'likes_count': calculatedCount,
        'liked_by': finalLikedByString.isEmpty ? null : finalLikedByString,
      })
          .eq('id', widget.post['id']);

      if (widget.onChanged != null) {
        widget.onChanged!(updatedData);
      }
    } catch (e) {
      debugPrint("Error syncing reactions: $e");
      if (mounted) {
        setState(() {
          _parseInitialState();
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final (labelName, emoji, color, iconData) = _getReactionDisplay(
        _currentReaction);

    return KeyedSubtree(
      key: _buttonKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTapAction,
        onLongPress: () {
          _playSound();
          _showReactionOverlay();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLiked ? iconData : Icons.thumb_up_outlined,
                size: 16,
                color: _isLiked ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _isLiked
                    ? labelName
                    : (_likesCount > 0 ? "$_likesCount" : "Like"),
                style: TextStyle(
                  color: _isLiked ? color : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}