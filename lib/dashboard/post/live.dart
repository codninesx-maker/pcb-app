import 'package:flutter/material.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart' show ZegoUIKitPrebuiltLiveStreaming, ZegoUIKitPrebuiltLiveStreamingConfig, ZegoUIKitPrebuiltLiveStreamingController, ZegoUIKit;


class LiveScreen extends StatefulWidget {
  final String? broadcasterUserId; // If null, current user is broadcasting

  const LiveScreen({super.key, this.broadcasterUserId});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _chatController = TextEditingController();

  bool _isLive = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isLoadingProfile = true;

  Map<String, dynamic>? _broadcasterData;
  String? _currentStreamId;
  RealtimeChannel? _commentsChannel;
  RealtimeChannel? _streamStatusChannel;

  final List<Map<String, dynamic>> _liveComments = [
    {
      "user_id": "system_admin_id",
      "user_name": "Admin",
      "message": "Welcome to the live session!",
      "avatar_url": null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeLiveSession();
  }

  Future<void> _initializeLiveSession() async {
    await _fetchBroadcasterProfile();
    await _setupActiveStream();
  }

  Future<void> _fetchBroadcasterProfile() async {
    try {
      final targetId = widget.broadcasterUserId ?? _supabase.auth.currentUser?.id;
      if (targetId == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final response = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', targetId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _broadcasterData = response ?? {
            "user_id": targetId,
            "name": "Broadcaster",
            "image_url": null,
          };
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching broadcaster profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _setupActiveStream() async {
    try {
      final broadcasterId = _broadcasterData?['user_id'] ?? widget.broadcasterUserId;
      if (broadcasterId == null) return;

      // 1. Check existing active stream
      final existingStream = await _supabase
          .from('pcblive_streams')
          .select()
          .eq('host_user_id', broadcasterId)
          .eq('is_active', true)
          .maybeSingle();

      if (existingStream != null) {
        setState(() {
          _currentStreamId = existingStream['id'];
          if (broadcasterId == _supabase.auth.currentUser?.id) {
            _isLive = true;
          }
        });
        _listenToComments(_currentStreamId!);
      }

      // 2. Listen in real-time for when the host starts or stops the stream
      _streamStatusChannel = _supabase
          .channel('public:pcblive_streams:host_user_id=eq.$broadcasterId')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pcblive_streams',
        callback: (payload) {
          final record = payload.newRecord;
          if (record['host_user_id'] == broadcasterId) {
            final isActive = record['is_active'] == true;
            if (mounted) {
              setState(() {
                if (isActive) {
                  _currentStreamId = record['id'];
                  if (broadcasterId == _supabase.auth.currentUser?.id) {
                    _isLive = true;
                  }
                  _listenToComments(_currentStreamId!);
                } else {
                  if (_currentStreamId == record['id']) {
                    _currentStreamId = null;
                    _isLive = false;
                  }
                }
              });
            }
          }
        },
      )
          .subscribe();
    } catch (e) {
      debugPrint("Error setting up stream listener: $e");
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    if (_commentsChannel != null) _supabase.removeChannel(_commentsChannel!);
    if (_streamStatusChannel != null) _supabase.removeChannel(_streamStatusChannel!);
    super.dispose();
  }

  void _listenToComments(String streamId) {
    try {
      // Remove existing channel if open to prevent duplicate sinks
      if (_commentsChannel != null) {
        _supabase.removeChannel(_commentsChannel!);
      }

      _commentsChannel = _supabase
          .channel('public:pcblive_comments:stream_id=eq.$streamId')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'pcblive_comments',
        callback: (payload) async {
          final newComment = payload.newRecord;
          if (newComment['stream_id'] != streamId) return;

          final userProfile = await _supabase
              .from('pcb')
              .select('name, image_url')
              .eq('user_id', newComment['user_id'])
              .maybeSingle();

          if (mounted) {
            setState(() {
              _liveComments.add({
                "user_id": newComment['user_id'],
                "user_name": userProfile?['name'] ?? "User",
                "message": newComment['message'],
                "avatar_url": userProfile?['image_url'],
              });
            });
          }
        },
      )
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.closed || error != null) {
          debugPrint("Realtime WebSocket closed or errored: $error");
        }
      });
    } catch (e) {
      debugPrint("Error initializing realtime comments stream: $e");
    }
  }

  Future<void> _toggleLiveStatus() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (!_isLive) {
        // 1. START LIVE: Insert row into Supabase pcblive_streams table
        final response = await _supabase.from('pcblive_streams').insert({
          'host_user_id': currentUserId,
          'is_active': true,
        }).select().single();

        setState(() {
          _isLive = true;
          _currentStreamId = response['id']; // Gets the unique database stream ID
        });

        // Listen to real-time chat comments for this stream
        _listenToComments(_currentStreamId!);

      } else {
        // 2. END LIVE: Mark stream as inactive in Supabase
        if (_currentStreamId != null) {
          await _supabase
              .from('pcblive_streams')
              .update({'is_active': false})
              .eq('id', _currentStreamId!);
        }

        setState(() {
          _isLive = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLive ? "Stream posted and is now LIVE!" : "Live stream ended."),
            backgroundColor: _isLive ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error posting or updating live status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendComment() async {
    if (_chatController.text.trim().isEmpty || _currentStreamId == null) {
      if (_currentStreamId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stream is not active yet.")),
        );
      }
      return;
    }

    final messageText = _chatController.text.trim();
    _chatController.clear();

    try {
      await _supabase.from('pcblive_comments').insert({
        'stream_id': _currentStreamId,
        'user_id': _supabase.auth.currentUser?.id,
        'message': messageText,
      });
    } catch (e) {
      debugPrint("Error sending comment: $e");
    }
  }

  Future<void> _openProfile(String? userId) async {
    if (userId == null || userId == 'system_admin_id') return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final fullprofile = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (context.mounted) {
        Navigator.pop(context);
        if (fullprofile != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => profileDetailScreen(profile: fullprofile),
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

  @override
  Widget build(BuildContext context) {
    final broadcasterUserId = _broadcasterData?['user_id'] ?? widget.broadcasterUserId;
    final broadcasterName = _broadcasterData?['name'] ?? "Broadcaster";
    final broadcasterImage = _broadcasterData?['image_url'];
    final currentUserId = _supabase.auth.currentUser?.id ?? 'guest_user';
    final isMyStream = broadcasterUserId == currentUserId;

    // Determine if the current user is hosting or viewing
    final isHost = isMyStream && _isLive;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Live Telecast", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            if (_isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SafeArea(
        child: Stack(
          children: [
            // 1. ZegoCloud Live Streaming Video Integration
            _currentStreamId == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    isMyStream ? "Tap 'Go Live' to start streaming" : "Stream is offline",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ZegoUIKitPrebuiltLiveStreaming(
              appID: 242137755, // <-- Replace with your Zego App ID
              appSign: "4e13260077092834271ad1424b90b7ece98d5f3e3283d845c1902c21ff806d77", // <-- Replace with your Zego App Sign
              userID: currentUserId,
              userName: broadcasterName,
              liveID: _currentStreamId!,
              config: isHost
                  ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
                  : ZegoUIKitPrebuiltLiveStreamingConfig.audience(),
            ),

            // 2. Top Broadcaster Header Overlay (Clickable Profile)
            Positioned(
              top: 10,
              left: 16,
              child: GestureDetector(
                onTap: () => _openProfile(broadcasterUserId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: (broadcasterImage != null &&
                            broadcasterImage.toString().isNotEmpty)
                            ? NetworkImage(broadcasterImage)
                            : null,
                        child: (broadcasterImage == null ||
                            broadcasterImage.toString().isEmpty)
                            ? const Icon(Icons.person, size: 18, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        broadcasterName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Live Chat Comments Overlay Layer
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 160,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.0, 0.2],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _liveComments.length,
                    itemBuilder: (context, index) {
                      final comment = _liveComments[_liveComments.length - 1 - index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _openProfile(comment['user_id']),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                    backgroundImage: (comment['avatar_url'] != null &&
                                        comment['avatar_url'].toString().isNotEmpty)
                                        ? NetworkImage(comment['avatar_url'])
                                        : null,
                                    child: (comment['avatar_url'] == null ||
                                        comment['avatar_url'].toString().isEmpty)
                                        ? Text(
                                      (comment['user_name'] != null &&
                                          comment['user_name'].toString().isNotEmpty)
                                          ? comment['user_name'][0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                    )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${comment['user_name'] ?? 'User'}: ",
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                comment['message'] ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 4. Bottom Controls Bar
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // Audio Mute Button (Only for Host)
                  if (isMyStream && _isLive) ...[
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.red : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          // Use ZegoUIKit core method to control the microphone
                          ZegoUIKit().turnMicrophoneOn(!_isMuted);
                        });
                      },
                    ),

                    // Video Off Button (Only for Host)
                    IconButton(
                      icon: Icon(
                        _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        color: _isVideoOff ? Colors.red : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isVideoOff = !_isVideoOff;
                          // Use ZegoUIKit core method to control the camera
                          ZegoUIKit().turnCameraOn(!_isVideoOff);
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Existing Chat Input Field
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Say something...",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white24,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 20),
                            onPressed: _sendComment,
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Go Live / End Stream Button
                  if (isMyStream)
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isLive ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _toggleLiveStatus,
                        child: Text(_isLive ? "End Stream" : "Go Live",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}