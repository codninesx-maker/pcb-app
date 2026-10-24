import 'package:flutter/material.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


enum FollowListType { followers, following }

class FollowersScreen extends StatefulWidget {
  final String profileId;
  final FollowListType listType;

  const FollowersScreen({
    super.key,
    required this.profileId,
    this.listType = FollowListType.followers,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _usersList = [];

  // Track follow status for each user ID in the list
  final Map<String, bool> _isFollowingMap = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      List<Map<String, dynamic>> fetchedUsers = [];

      if (widget.listType == FollowListType.followers) {
        final response = await _supabase
            .from('pcb_followers')
            .select('follower_id')
            .eq('following_id', widget.profileId);

        for (var item in response) {
          final targetUserId = item['follower_id'];
          if (targetUserId != null) {
            final profileRes = await _supabase
                .from('pcb')
                .select('*')
                .eq('user_id', targetUserId)
                .maybeSingle();

            if (profileRes != null) {
              fetchedUsers.add(profileRes);
            }
          }
        }
      } else {
        final response = await _supabase
            .from('pcb_followers')
            .select('following_id')
            .eq('follower_id', widget.profileId);

        for (var item in response) {
          final targetUserId = item['following_id'];
          if (targetUserId != null) {
            final profileRes = await _supabase
                .from('pcb')
                .select('*')
                .eq('user_id', targetUserId)
                .maybeSingle();

            if (profileRes != null) {
              fetchedUsers.add(profileRes);
            }
          }
        }
      }

      // Check current user's following status for each user in the list
      if (_currentUserId != null) {
        for (var user in fetchedUsers) {
          final targetUserId = user['user_id'];
          if (targetUserId != null) {
            final checkRes = await _supabase
                .from('pcb_followers')
                .select('id')
                .eq('follower_id', _currentUserId!)
                .eq('following_id', targetUserId)
                .maybeSingle();

            _isFollowingMap[targetUserId] = checkRes != null;
          }
        }
      }

      if (mounted) {
        setState(() {
          _usersList = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching follow list: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow(String targetUserId, String targetName) async {
    if (_currentUserId == null || _currentUserId == targetUserId) return;

    final currentlyFollowing = _isFollowingMap[targetUserId] ?? false;

    // Optimistic UI update
    setState(() {
      _isFollowingMap[targetUserId] = !currentlyFollowing;
    });

    try {
      if (currentlyFollowing) {
        // Unfollow
        await _supabase
            .from('pcb_followers')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', targetUserId);
      } else {
        // Follow & Insert Notification
        await _supabase.from('pcb_followers').insert({
          'follower_id': _currentUserId,
          'following_id': targetUserId,
        });

        // Get current user's profile info for the notification actor details
        final currentUserProfile = await _supabase
            .from('pcb')
            .select('name, image_url')
            .eq('user_id', _currentUserId!)
            .maybeSingle();

        final actorName = currentUserProfile?['name'] ?? 'Someone';
        final actorAvatar = currentUserProfile?['image_url'];

        // Send Notification
        await _supabase.from('pcb_notifications').insert({
          'user_id': targetUserId, // Recipient
          'actor_id': _currentUserId,
          'actor_avatar': actorAvatar,
          'title': actorName,
          'body': 'started following you.',
          'type': 'follow',
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint("Error toggling follow: $e");
      // Revert optimistic update on failure
      setState(() {
        _isFollowingMap[targetUserId] = currentlyFollowing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowers = widget.listType == FollowListType.followers;
    final titleText = isFollowers ? "Followers" : "Following";
    final emptyText = isFollowers ? "No followers yet" : "Not following anyone yet";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _usersList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _usersList.length,
        itemBuilder: (context, index) {
          final userData = _usersList[index];
          final targetUserId = userData['user_id'];
          final name = userData['name'] ?? 'User';
          final imageUrl = userData['image_url'];
          final specialty = userData['specialization'] ?? userData['designation'] ?? '';
          final isFollowing = _isFollowingMap[targetUserId] ?? false;
          final isSelf = _currentUserId == targetUserId;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                child: imageUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: specialty.isNotEmpty
                  ? Text(
                specialty,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              )
                  : null,
              trailing: isSelf
                  ? null
                  : ElevatedButton(
                onPressed: () => _toggleFollow(targetUserId, name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey.shade200 : Colors.blueAccent,
                  foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => profileDetailScreen(profile: userData),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}