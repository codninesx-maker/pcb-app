import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static RealtimeChannel? _notificationChannel;

  // Initialize Local Notifications & Create Android Channel
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Request notification permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Android channel configuration for popup banners (heads-up notifications)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pcb_high_importance_channel',
      'PCB Community Notifications',
      description: 'Used for important notifications like new followers, profile updates, and likes.',
      importance: Importance.max, // High importance enables popup banners
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Helper method to download image bytes from URL for notification large icon
  static Future<ByteArrayAndroidBitmap?> _getByteArrayFromUrl(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return ByteArrayAndroidBitmap(response.bodyBytes);
      }
    } catch (e) {
      // Fallback if download fails
    }
    return null;
  }

  // Show the popup banner on screen with optional avatar image
  static Future<void> showPopupBanner({
    required int id,
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    ByteArrayAndroidBitmap? largeIconBitmap;

    // Download the actor's avatar if available
    if (imageUrl != null && imageUrl.isNotEmpty) {
      largeIconBitmap = await _getByteArrayFromUrl(imageUrl);
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pcb_high_importance_channel',
      'PCB Community Notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
      largeIcon: largeIconBitmap, // Displays avatar image on the notification side
      styleInformation: largeIconBitmap != null
          ? BigTextStyleInformation(body, contentTitle: title)
          : null,
    );

    NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  // Subscribe to real-time changes in pcb_notifications table
  static void listenToUserNotifications(String currentUserId) {
    // Prevent duplicate channel subscriptions
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }

    _notificationChannel = Supabase.instance.client
        .channel('public:pcb_notifications:user_id=eq.$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'pcb_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: currentUserId,
      ),
      callback: (payload) {
        final newNotif = payload.newRecord;
        final String title = newNotif['title'] ?? 'PCB Notification';
        final String body = newNotif['body'] ?? 'You have a new update.';
        final String? actorAvatar = newNotif['actor_avatar']?.toString();

        // Trigger local popup banner instantly with actor's avatar
        showPopupBanner(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          imageUrl: actorAvatar,
        );
      },
    )
        .subscribe();
  }

  static void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
  }
}