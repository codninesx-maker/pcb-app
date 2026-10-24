import 'package:flutter/material.dart';
import 'package:pharmacist_profile/dashboard/post/edit_post.dart';
import 'package:pharmacist_profile/profile/edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';

class AdminControlUserScreen extends StatefulWidget {
  const AdminControlUserScreen({super.key});

  @override
  State<AdminControlUserScreen> createState() => _AdminControlUserScreenState();
}

class _AdminControlUserScreenState extends State<AdminControlUserScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('pcb')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response);
          _filteredUsers = _allUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading users: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void fn_filterUsers(String query) {
    final searchTerm = query.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final profession = (user['profession'] ?? user['specialty'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(searchTerm) || profession.contains(searchTerm) || email.contains(searchTerm);
      }).toList();
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User Profile & Data"),
        content: Text(
          "Are you sure you want to permanently delete ${user['name'] ?? 'this user'}, their posts, and images from Cloudinary? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete Everything", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
        );

        final String? profileId = user['id']?.toString();
        final String? userId = user['user_id']?.toString();
        final String? imageUrl = user['image_url']?.toString();
        final String? coverUrl = user['cover_url']?.toString();

        // 1. Delete images from Cloudinary via Edge Function
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await _deleteFromCloudinary(imageUrl);
        }
        if (coverUrl != null && coverUrl.isNotEmpty) {
          await _deleteFromCloudinary(coverUrl);
        }

        // 2. Delete related posts and comments in Supabase
        if (profileId != null && profileId.isNotEmpty) {
          try {
            await _supabase.from('pcb_posts').delete().eq('user_id', profileId);
          } catch (_) {}
        }
        if (userId != null && userId.isNotEmpty) {
          try {
            await _supabase.from('pcb_posts').delete().eq('user_id', userId);
          } catch (_) {}
          try {
            await _supabase.from('pcb_comments').delete().eq('user_id', userId);
          } catch (_) {}
          try {
            await _supabase.from('doctor_notifications').delete().eq('user_id', userId);
          } catch (_) {}
        }

        // 3. Delete main profile row
        if (profileId != null && profileId.isNotEmpty) {
          await _supabase.from('pcb').delete().eq('id', profileId);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("User profile and Cloudinary images deleted successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          _fetchUsers();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          debugPrint("Error deleting user: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting user: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- Helper: Extract Public ID & Delete from Cloudinary ---
  Future<void> _deleteFromCloudinary(String url) async {
    try {
      if (!url.contains('cloudinary.com')) return;

      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) return;

      String resourceType = 'image';
      if (segments.contains('video') || url.contains('/video/')) {
        resourceType = 'video';
      }

      int startIndex = uploadIndex + 1;
      if (segments[startIndex].startsWith('v') && RegExp(r'^v\d+$').hasMatch(segments[startIndex])) {
        startIndex++;
      }

      final fullPath = segments.sublist(startIndex).join('/');
      final dotIndex = fullPath.lastIndexOf('.');
      final publicId = dotIndex != -1 ? fullPath.substring(0, dotIndex) : fullPath;

      debugPrint("Deleting Cloudinary asset: $publicId ($resourceType)");

      // Invoke the deployed 'delete-image' Supabase Edge Function
      final response = await _supabase.functions.invoke(
        'delete-image',
        body: {
          'public_id': publicId,
          'resource_type': resourceType,
        },
      );

      debugPrint("Cloudinary edge delete response: ${response.data}");

    } catch (e) {
      debugPrint("Cloudinary delete helper error: $e");
    }
  }

  // Helper to open and manage/edit the user's posts
  Future<void> _openUserPosts(Map<String, dynamic> user) async {
    final profileId = user['id']?.toString();
    final userId = user['user_id']?.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      // Safely build an or filter matching either profile id or user_id
      var query = _supabase.from('pcb_posts').select();

      if (profileId != null && userId != null && profileId != userId) {
        query = query.or('user_id.eq.$profileId,user_id.eq.$userId');
      } else if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      } else if (profileId != null && profileId.isNotEmpty) {
        query = query.eq('user_id', profileId);
      }

      final postsResponse = await query.order('created_at', ascending: false);

      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              final posts = List<Map<String, dynamic>>.from(postsResponse);
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${user['name']}'s Posts (${posts.length})",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: posts.isEmpty
                          ? const Center(child: Text("This user has no posts yet."))
                          : ListView.builder(
                        controller: scrollController,
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];

                          // Fallback check to ensure content displays even if named title or description
                          final contentValue = post['content'] ?? post['title'] ?? post['description'];
                          final content = (contentValue != null && contentValue.toString().trim().isNotEmpty)
                              ? contentValue.toString()
                              : 'Untitled Post';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditPostScreen(post: post),
                                    ),
                                  );

                                  if (updated == true && context.mounted) {
                                    Navigator.pop(context); // Close sheet
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Post updated successfully!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        debugPrint("Error fetching user posts: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching posts: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Control - Users", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueAccent.withOpacity(0.05),
            child: TextField(
              controller: _searchController,
              onChanged: fn_filterUsers,
              decoration: InputDecoration(
                hintText: "Search by name, profession, or email...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    fn_filterUsers('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Registered: ${_allUsers.length}",
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (_filteredUsers.length != _allUsers.length)
                  Text(
                    "Filtered: ${_filteredUsers.length}",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    "No users found",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers.length > index ? _filteredUsers[index] : null;
                  if (user == null) return const SizedBox.shrink();

                  final imageUrl = user['image_url']?.toString();
                  final name = user['name'] ?? 'No Name';
                  final profession = user['profession'] ?? user['specialty'] ?? 'Professional';
                  final email = user['email'] ?? 'No email provided';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null,
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? const Icon(Icons.person, color: Colors.grey, size: 28)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            profession,
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'view') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => profileDetailScreen(profile: user),
                              ),
                            );
                            _fetchUsers();
                          } else if (value == 'edit') {
                            try {
                              final freshUser = await _supabase
                                  .from('pcb')
                                  .select()
                                  .eq('id', user['id'])
                                  .maybeSingle();

                              if (context.mounted) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditprofileScreen(userData: freshUser ?? user),
                                  ),
                                );
                                _fetchUsers();
                              }
                            } catch (_) {
                              if (context.mounted) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditprofileScreen(userData: user),
                                  ),
                                );
                                _fetchUsers();
                              }
                            }
                          } else if (value == 'edit_posts') {
                            _openUserPosts(user);
                          } else if (value == 'delete') {
                            _deleteUser(user);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, color: Colors.blueAccent, size: 20),
                                SizedBox(width: 8),
                                Text("View Profile"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text("Edit Profile"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit_posts',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text("Edit Posts"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text("Delete User", style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => profileDetailScreen(profile: user),
                          ),
                        );
                        _fetchUsers();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}