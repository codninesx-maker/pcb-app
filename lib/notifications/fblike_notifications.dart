import 'package:flutter/material.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';


class FbNotificationsWidget extends StatefulWidget {
  final String currentUserId;
  const FbNotificationsWidget({super.key, required this.currentUserId});

  @override
  State<FbNotificationsWidget> createState() => _FbNotificationsWidgetState();
}

class _FbNotificationsWidgetState extends State<FbNotificationsWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _playFbSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/fb_pop.mp3'));
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _supabase
          .from('pcb_notifications')
          .select()
          .eq('user_id', widget.currentUserId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _unreadCount = _notifications.where((n) => n['is_read'] == false).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _supabase
        .channel('public:pcb_notifications:${widget.currentUserId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'pcb_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: widget.currentUserId,
      ),
      callback: (payload) {
        _playFbSound();
        if (mounted) {
          setState(() {
            _notifications.insert(0, payload.newRecord);
            _unreadCount += 1;
          });
        }
      },
    )
        .subscribe();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('pcb_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'].toString() == notificationId);
        if (index != -1 && _notifications[index]['is_read'] == false) {
          _notifications[index]['is_read'] = true;
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
      });
    } catch (e) {
      debugPrint("Error updating notification status: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _supabase
          .from('pcb_notifications')
          .update({'is_read': true})
          .eq('user_id', widget.currentUserId);

      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  /// 🔵 Facebook-style Navigation: Opens actor profile or liked post context seamlessly
  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    final String notificationId = item['id'].toString();
    final bool isRead = item['is_read'] ?? false;
    final String? actorId = item['actor_id'];

    // 1. Mark notification as read immediately
    if (!isRead) {
      await _markAsRead(notificationId);
    }

    if (actorId == null || actorId.isEmpty) return;

    // Show loading dialog while fetching target profile
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      // Fetch actor's professional profile to display their timeline/posts (Facebook style)
      final fullProfile = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', actorId)
          .maybeSingle();

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog

        if (fullProfile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => profileDetailScreen(profile: fullProfile),
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
          SnackBar(content: Text("Error opening content: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _timeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'like':
      case 'love':
      case 'haha':
      case 'wow':
      case 'sad':
      case 'angry':
        return Icons.thumb_up_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'share':
        return Icons.share_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'like':
      case 'love':
      case 'haha':
      case 'wow':
      case 'sad':
      case 'angry':
        return Colors.blueAccent;
      case 'comment':
        return Colors.green;
      case 'share':
        return Colors.orangeAccent;
      case 'follow':
        return Colors.purpleAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Facebook Style Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text(
                      "Mark all as read",
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Notification List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      "No notifications",
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchNotifications,
                child: ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final bool isRead = item['is_read'] ?? false;
                    final String type = item['type'] ?? 'general';
                    final String title = item['title'] ?? 'Someone';
                    final String body = item['body'] ?? 'interacted with your content.';
                    final String createdAt = item['created_at'] ?? DateTime.now().toIso8601String();
                    final String? actorAvatar = item['actor_avatar'];

                    return InkWell(
                      onTap: () => _handleNotificationTap(item),
                      child: Container(
                        color: isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar Badge with valid NetworkImage fetching
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: (actorAvatar != null && actorAvatar.isNotEmpty)
                                      ? NetworkImage(actorAvatar)
                                      : null,
                                  child: (actorAvatar == null || actorAvatar.isEmpty)
                                      ? const Icon(Icons.person, color: Colors.grey, size: 30)
                                      : null,
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(type),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Notification Text & Timestamp
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                                      children: [
                                        TextSpan(
                                          text: "$title ",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        TextSpan(text: body),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRead ? Colors.grey.shade600 : Colors.blueAccent,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Facebook Blue Dot Unread Indicator
                            if (!isRead)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}