import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_profile/profile/view_profile_detail_screen.dart';

enum FollowListType { followers, following }

class FollowersScreen extends StatefulWidget {
  final String doctorId; // Matches what you are passing in your onTap
  final FollowListType listType; // Optional, defaults to followers

  const FollowersScreen({
    super.key,
    required this.doctorId,
    this.listType = FollowListType.followers, // Defaults so you don't break existing calls
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _usersList = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      List<Map<String, dynamic>> fetchedUsers = [];

      if (widget.listType == FollowListType.followers) {
        final response = await _supabase
            .from('pcb_followers')
            .select('follower_id')
            .eq('following_id', widget.doctorId);

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
            .eq('follower_id', widget.doctorId);

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
          final name = userData['name'] ?? 'User';
          final imageUrl = userData['image_url'];
          final specialty = userData['specialization'] ?? userData['designation'] ?? '';

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
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileDetailScreen(doctor: userData),
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