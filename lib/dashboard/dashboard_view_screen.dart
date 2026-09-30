import 'dart:async';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/admin/DashboardAnnouncementBanner.dart';
import 'package:pharmacist_profile/dashboard/create_post_news_feed.dart';
import 'package:pharmacist_profile/dashboard/featured_profile.dart';
import 'package:pharmacist_profile/dashboard/post/create_post_screen.dart';
import 'package:pharmacist_profile/dashboard/profile_list_five_connected_dash.dart';
import 'package:pharmacist_profile/dashboard/search_bar.dart';
import 'package:pharmacist_profile/dashboard/three_dot_menu.dart';
import 'package:pharmacist_profile/profile/profile-create_screen.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../image/cloudinary_service.dart';
import 'chat_screen.dart';


class DashboardViewScreen extends StatefulWidget {
  const DashboardViewScreen({super.key});

  @override
  State<DashboardViewScreen> createState() => _DashboardViewScreenState();
}

class _DashboardViewScreenState extends State<DashboardViewScreen> {
  String? _userName;
  String? _avatarUrl;

  late final StreamSubscription<AuthState> _authSubscription;

  Future<List<Map<String, dynamic>>> _profileFuture = Future.value([]);
  Future<List<Map<String, dynamic>>> _postsFuture = Future.value([]);
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  String _searchQuery = "";
  bool _isAdminMode = false;
  bool _isLoading = true;
  int _tapCount = 0;
  late StreamSubscription _announcementSubscription;
  String _announcementText = "Welcome to our platform!";
  InterstitialAd? _interstitialAd;
  final user = Supabase.instance.client.auth.currentUser;
  final _cloudinary = CloudinaryService();
  late final RealtimeChannel _postsChannel;

  @override
  void initState() {
    super.initState();
    _initializeAllData();
    _listenToAuthChanges();
    _listenToAnnouncements();
    _setupPostsRealtime();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _announcementSubscription.cancel();
    _searchController.dispose();
    _supabase.removeChannel(_postsChannel);
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setupPostsRealtime() {
    // Check session before subscribing
    final session = _supabase.auth.currentSession;
    if (session == null || session.isExpired) {
      _supabase.auth.refreshSession().then((_) {
        _subscribeToPostsChannel();
      }).catchError((e) {
        debugPrint("Failed to refresh session for realtime: $e");
      });
    } else {
      _subscribeToPostsChannel();
    }
  }

  void _subscribeToPostsChannel() {
    try {
      _postsChannel = _supabase
          .channel('public:pcb_posts')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pcb_posts',
        callback: (payload) {
          if (payload.eventType == PostgresChangeEvent.update) {
            final currentUserId = _supabase.auth.currentUser?.id;
            final newData = payload.newRecord;
            final String likedByString = newData['liked_by']?.toString() ?? '';

            if (currentUserId != null && likedByString.contains(currentUserId)) {
              return;
            }
          }
          _fetchPosts();
        },
      )
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint("Realtime channel error: $error");
          // Attempt session refresh if token expired
          if (error.toString().contains('Token has expired')) {
            _supabase.auth.refreshSession();
          }
        }
      });
    } catch (e) {
      debugPrint("Error setting up posts realtime: $e");
    }
  }

  void _listenToAnnouncements() {
    _announcementSubscription = Supabase.instance.client
        .from('pcb_app_settings')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (data.isNotEmpty) {
        setState(() {
          _announcementText = data.first['announcement_text'] ?? "Welcome!";
        });
      }
    });
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-7494179033430216/4636802475',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeAllData() async {
    setState(() => _isLoading = true);
    await _initializeUserAndData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    _listenToAnnouncements();
    _loadInterstitialAd();
  }

  Future<void> _initializeUserAndData() async {
    final client = Supabase.instance.client;
    var currentUser = client.auth.currentUser;

    if (currentUser == null) {
      try {
        final response = await client.auth.signInAnonymously();
        currentUser = response.user;
      } catch (e) {
        debugPrint("Anonymous sign-in error: $e");
      }
    }

    await Future.wait([
      _fetchUserData(currentUser),
      _fetchprofile(),
      _fetchPosts(),
    ]);
  }

  Future<void> _fetchUserData(User? currentUser) async {
    if (currentUser != null) {
      setState(() {
        _userName = currentUser.userMetadata?['full_name'] ??
            currentUser.email?.split('@')[0] ??
            "User_${currentUser.id.substring(0, 5)}";
        _avatarUrl = currentUser.userMetadata?['avatar_url'] ??
            'https://ui-avatars.com/api/?name=$_userName';
      });
    }
  }

  Future<void> _fetchPosts() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      final data = await Supabase.instance.client
          .from('pcb_posts')
          .select('''
            id,
            content,
            image_url,
            video_url,
            media_type,
            media_url,
            created_at,
            user_id,
            likes_count,
            comments_count,
            shares_count,
            liked_by,
            pcb!pcb_posts_user_id_fkey (name, image_url)
          ''')
          .order('created_at', ascending: false)
          .limit(05);

      final List<Map<String, dynamic>> processedPosts = data.map((post) {
        final Map<String, dynamic> mutablePost = Map<String, dynamic>.from(post);
        final String likedByString = mutablePost['liked_by']?.toString() ?? '';

        final userList = likedByString
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        mutablePost['is_liked'] = currentUserId != null && userList.contains(currentUserId);
        mutablePost['liked_by'] = likedByString;
        return mutablePost;
      }).toList();

      if (mounted) {
        setState(() {
          _postsFuture = Future.value(processedPosts);
        });
      }
    } catch (e) {
      debugPrint("Fetch Posts Error: $e");
    }
  }

  Future<void> _fetchprofile() async {
    try {
      final data = await Supabase.instance.client
          .from('pcb')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _profileFuture = Future.value(data);
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> _deleteprofile(String profileId) async {
    try {
      final existingData = await Supabase.instance.client
          .from('pcb')
          .select('image_url, cover_url')
          .eq('id', profileId)
          .maybeSingle();

      if (existingData != null) {
        final String? imageUrl = existingData['image_url'];
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await _cloudinary.deleteMedia(imageUrl);
          } catch (_) {}
        }

        final String? coverUrl = existingData['cover_url'];
        if (coverUrl != null && coverUrl.isNotEmpty) {
          try {
            await _cloudinary.deleteMedia(coverUrl);
          } catch (_) {}
        }
      }

      await Supabase.instance.client
          .from('pcb')
          .delete()
          .eq('id', profileId);

      if (mounted) {
        _fetchprofile();
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> profile) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Professional"),
        content: Text("Are you sure you want to delete ${profile['name']}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              final String profileId = profile['id']?.toString() ?? "";
              _deleteprofile(profileId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );

      await _supabase.auth.signOut();

      if (context.mounted) {
        Navigator.pop(context);
        setState(() {
          _userName = null;
          _avatarUrl = null;
        });

        _fetchprofile();
        _fetchPosts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logged out successfully!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging out: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToMyprofile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final profileData = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (context.mounted) {
        Navigator.pop(context);
        if (profileData != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => profileDetailScreen(profile: profileData), // Changed from profile: to profiles:
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You haven't created a professional profile yet! Login or Tap '+' to create one."),
              backgroundColor: Colors.orange,
            ),
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

  Future<void> _navigateToAuthorprofile(String? userId) async {
    if (userId == null) return;

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
          _fetchprofile();
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

  Future<void> _confirmDeletePost(dynamic postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post and all associated media? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
        );

        // 1. Fetch post data first to get any media URLs
        final postData = await Supabase.instance.client
            .from('pcb_posts')
            .select('image_url, video_url, media_url')
            .eq('id', postId)
            .maybeSingle();

        if (postData != null) {
          final String? imageUrl = postData['image_url'];
          final String? videoUrl = postData['video_url'];
          final String? mediaUrl = postData['media_url'];

          // Use a Set to keep track of unique URLs so we don't delete the same file twice
          final Set<String> urlsToDelete = {};

          if (imageUrl != null && imageUrl.isNotEmpty) urlsToDelete.add(imageUrl);
          if (videoUrl != null && videoUrl.isNotEmpty) urlsToDelete.add(videoUrl);
          if (mediaUrl != null && mediaUrl.isNotEmpty) urlsToDelete.add(mediaUrl);

          // 2. Delete unique media files safely from Cloudinary
          for (final url in urlsToDelete) {
            try {
              await _cloudinary.deleteMedia(url);
            } catch (e) {
              debugPrint("Cloudinary Media Delete Error for $url: $e");
            }
          }
        }

        // 3. Delete related records first (if foreign keys aren't set to cascade)
        try {
          await Supabase.instance.client
              .from('pcb_post_comments')
              .delete()
              .eq('post_id', postId);
        } catch (e) {
          debugPrint("Comments Delete Error: $e");
        }

        // 4. Delete the main post row from Supabase
        await Supabase.instance.client
            .from('pcb_posts')
            .delete()
            .eq('id', postId);

        if (mounted) {
          Navigator.pop(context); // Pop loading dialog

          // Refresh state
          await _fetchPosts();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Post and associated media deleted successfully"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          debugPrint("Complete Post Deletion Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error deleting post: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isKeyboardVisible
          ? null
          : FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const profileCreateScreen()),
          );
          _fetchprofile();
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchprofile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // --- HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(

                      child: const Text(
                        "PCB",
                        style: TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  userName: _userName,
                                  avatarUrl: _avatarUrl,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 24),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_interstitialAd != null) {
                              _interstitialAd!.show();
                              _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
                                onAdDismissedFullScreenContent: (ad) {
                                  ad.dispose();
                                  _loadInterstitialAd();
                                },
                              );
                            }
                          },
                          icon: const Text("😊", style: TextStyle(fontSize: 24)),
                        ),
                        ThreeDotMenuWidget(
                          onRefresh: () => _fetchprofile(),
                          onMyprofile: () => _navigateToMyprofile(),
                          onLogout: () => _handleLogout(),
                        ),
                      ],
                    ),
                  ],
                ),

                // --- SEARCH BAR ---
                const SizedBox(height: 20),
                CustomSearchBar(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),

                // --- ANNOUNCEMENT MARQUEE ---
                const SizedBox(height: 20),
                DashboardAnnouncementBanner(announcementText: _announcementText),

                // --- FEATURED SECTION ---
                FeaturedprofilesSection(
                  profileFuture: _profileFuture,
                  onprofileReturned: () => _fetchprofile(),
                ),

                // --- ALL PROFESSIONALS LIST ---
                AllProfessionalsListSection(
                  profileFuture: _profileFuture,
                  searchQuery: _searchQuery,
                  onprofileReturned: () => _fetchprofile(),
                  onDeleteRequested: (profile) => _showDeleteConfirmation(profile),
                ),

                // --- COMMUNITY POSTS FEED SECTION ---
                CommunityNewsFeedSection(
                  postsFuture: _postsFuture,
                  onCreatePostPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                    );
                    if (result == true) {
                      _fetchPosts();
                    }
                  },
                  onPostsRefreshed: () => _fetchPosts(),
                  onNavigateToAuthorprofile: (userId) => _navigateToAuthorprofile(userId),
                  onShowImagePreview: (imageUrl) => _showImagePreview(context, imageUrl),
                  onConfirmDeletePost: (postId) => _confirmDeletePost(postId),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}