import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifications/fblike_notifications.dart';

class NotificationBellButton extends StatefulWidget {
  final String currentUserId;

  const NotificationBellButton({super.key, required this.currentUserId});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _setupRealtimeBadge();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _supabase
          .from('pcb_notifications')
          .select('id')
          .eq('user_id', widget.currentUserId)
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadCount = res.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  void _setupRealtimeBadge() {
    _supabase
        .channel('public:pcb_notifications_badge:${widget.currentUserId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pcb_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: widget.currentUserId,
      ),
      callback: (payload) {
        _fetchUnreadCount();
      },
    )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = _unreadCount > 9 ? '9+' : '$_unreadCount';
    final bool hasUnread = _unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200, // Facebook circular button background
          shape: BoxShape.circle,
        ),
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FbNotificationsWidget(currentUserId: widget.currentUserId),
              ),
            );
            _fetchUnreadCount(); // Refresh badge when returning from notifications screen
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                hasUnread ? Icons.notifications_rounded : Icons.notifications_outlined,
                color: Colors.black87, // Facebook dark icon color style
                size: 22,
              ),
              if (hasUnread)
                Positioned(
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      displayCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}