import 'package:doctor_profile/admobs/ads_test_banner.dart';
import 'package:doctor_profile/dashboard/post/like_coments_share.dart';
import 'package:doctor_profile/profile/edit_profile_screen.dart';
import 'package:doctor_profile/stats/followers_screen.dart';
import 'package:doctor_profile/stats/views_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const ProfileDetailScreen({super.key, required this.doctor});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late Map<String, dynamic> _doctor;
  bool _isUpdatingFollower = false;

  // Helper to reliably find the user_id or pcb row id
  String? get _targetUserId => _doctor['user_id']?.toString();
  String? get _targetPcbId => _doctor['id']?.toString();

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _refreshData(); // Fetch fresh profile info and counts first
    _initializeProfile();
  }

  // Helper to safely obtain the user/profile ID regardless of navigation source
  String? get _targetId =>
      (_doctor['user_id'] ?? _doctor['id'] ?? _doctor['uuid'])?.toString();

  Future<void> _incrementViewCount(Map<String, dynamic> freshProfile) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final profileOwnerId = _targetId;

      if (currentUserId != null &&
          profileOwnerId != null &&
          currentUserId != profileOwnerId) {
        final currentCount = (freshProfile['view_count'] as num?)?.toInt() ?? 0;
        final newCount = currentCount + 1;

        // Update view count in PCB table
        final pcbId = freshProfile['id'] ?? profileOwnerId;
        await Supabase.instance.client
            .from('pcb')
            .update({'view_count': newCount})
            .eq('id', pcbId);

        if (mounted) {
          setState(() {
            _doctor['view_count'] = newCount;
          });
        }

        await Supabase.instance.client.from('pcb_profile_views').insert({
          'owner_id': profileOwnerId,
          'viewer_id': currentUserId,
        });
      }
    } catch (e) {
      debugPrint("Failed to update view count or log view: $e");
    }
  }

  Future<void> _refreshData() async {
    final String? pcbId = _targetPcbId;
    final String? userId = _targetUserId;

    if (pcbId == null && userId == null) {
      debugPrint("Refresh Error: Target IDs are missing.");
      return;
    }

    try {
      // 1. Fetch updated profile data safely avoiding null type mismatch
      List<Map<String, dynamic>> responseList;

      if (userId != null && pcbId != null) {
        responseList = await Supabase.instance.client
            .from('pcb')
            .select()
            .or('id.eq.$pcbId,user_id.eq.$userId')
            .limit(1);
      } else if (userId != null) {
        responseList = await Supabase.instance.client
            .from('pcb')
            .select()
            .eq('user_id', userId)
            .limit(1);
      } else {
        responseList = await Supabase.instance.client
            .from('pcb')
            .select()
            .eq('id', pcbId!)
            .limit(1);
      }

      if (responseList.isEmpty) return;

      final response = Map<String, dynamic>.from(responseList.first);
      final String actualUserId = response['user_id']?.toString() ?? userId ?? pcbId!;

      // 2. Fetch live counts accurately using the resolved user identifier
      final followersRes = await Supabase.instance.client
          .from('pcb_followers')
          .select('*')
          .eq('following_id', actualUserId)
          .count(CountOption.exact);

      final followingRes = await Supabase.instance.client
          .from('pcb_followers')
          .select('*')
          .eq('follower_id', actualUserId)
          .count(CountOption.exact);

      final postsRes = await Supabase.instance.client
          .from('pcb_posts')
          .select('*')
          .eq('user_id', actualUserId)
          .count(CountOption.exact);

      response['followers_count'] = followersRes.count;
      response['following_count'] = followingRes.count;
      response['posts_count'] = postsRes.count;

      if (mounted) {
        setState(() {
          _doctor = response;
        });
        _incrementViewCount(response);
      }
    } catch (e) {
      debugPrint("Refresh Error: $e");
    }
  }

  Future<void> _addFollower() async {
    if (_isUpdatingFollower) return;
    setState(() => _isUpdatingFollower = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You must be logged in to follow.")),
          );
        }
        setState(() => _isUpdatingFollower = false);
        return;
      }

      final targetDoctorId = _targetId;

      if (targetDoctorId == null || currentUserId == targetDoctorId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You cannot follow yourself.")),
          );
        }
        setState(() => _isUpdatingFollower = false);
        return;
      }

      await Supabase.instance.client.from('pcb_followers').insert({
        'follower_id': currentUserId,
        'following_id': targetDoctorId,
      });

      await _refreshData();

      if (mounted) {
        setState(() => _isUpdatingFollower = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully followed!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingFollower = false);
        final errorMessage = e.toString().contains('duplicate key')
            ? "You are already following this profile."
            : "Failed to follow: $e";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _initializeProfile() async {
    final targetUserId = _targetId;
    if (targetUserId == null || targetUserId.isEmpty) return;

    try {
      // Fetch the complete doctor/profile row from the 'pcb' table using the user_id or id
      final responseList = await Supabase.instance.client
          .from('pcb')
          .select()
          .or('user_id.eq.$targetUserId,id.eq.$targetUserId')
          .limit(1);

      if (responseList.isNotEmpty) {
        // Merge or replace with the full database profile so all fields exist
        setState(() {
          _doctor = Map<String, dynamic>.from(responseList.first);
        });
      }
    } catch (e) {
      debugPrint("Error fetching full profile on init: $e");
    }

    // Now refresh counts and view stats with the guaranteed full record
    await _refreshData();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  String _formatTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final String? authEmail = currentUser?.email?.trim().toLowerCase();
    final String? docEmail = _doctor['email']?.toString().trim().toLowerCase();

    final bool isOwner = (currentUser != null &&
        authEmail != null &&
        docEmail != null &&
        authEmail == docEmail);

    final String? imageUrl = (_doctor['image_url'] != null &&
        _doctor['image_url'].toString().isNotEmpty)
        ? _doctor['image_url']
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profile Details",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditProfileScreen(doctor: _doctor)));
                if (result == true) await _refreshData();
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final coverUrl = (_doctor['cover_url'] != null &&
                          _doctor['cover_url'].toString().isNotEmpty)
                          ? _doctor['cover_url']
                          : imageUrl;

                      if (coverUrl != null) {
                        _showFullImage(context, coverUrl);
                      }
                    },
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.blueAccent.withOpacity(0.15),
                      child: (_doctor['cover_url'] != null &&
                          _doctor['cover_url'].toString().isNotEmpty)
                          ? Image.network(
                        _doctor['cover_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                      )
                          : (imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : const Icon(Icons.image,
                          size: 50, color: Colors.blueAccent)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -35),
                          child: GestureDetector(
                            onTap: () {
                              if (imageUrl != null) {
                                _showFullImage(context, imageUrl);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: imageUrl != null
                                        ? NetworkImage(imageUrl)
                                        : null,
                                    child: imageUrl == null
                                        ? const Icon(Icons.person,
                                        size: 40, color: Colors.grey)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _doctor['status'] ==
                                              "Available"
                                              ? Colors.green
                                              : Colors.redAccent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  "Views",
                                  "${_doctor['view_count'] ?? 0}",
                                  Icons.remove_red_eye_outlined,
                                  onTap: () {
                                    final ownerId = _targetId;
                                    if (ownerId == null) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ViewsScreen(ownerId: ownerId),
                                      ),
                                    );
                                  },
                                ),
                                _buildStatItem(
                                  "Followers",
                                  "${_doctor['followers_count'] ?? 0}",
                                  Icons.people_outline,
                                  onTap: () {
                                    final targetId = _targetId;
                                    if (targetId == null) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersScreen(
                                            doctorId: targetId),
                                      ),
                                    );
                                  },
                                  onDoubleTap: _addFollower,
                                ),
                                _buildStatItem(
                                  "Following",
                                  "${_doctor['following_count'] ?? 0}",
                                  Icons.person_add_alt_outlined,
                                  onTap: () {
                                    final targetId = _targetId;
                                    if (targetId == null) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersScreen(
                                          doctorId: targetId,
                                          listType: FollowListType.following,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildStatItem(
                                  "Posts",
                                  "${_doctor['posts_count'] ?? 0}",
                                  Icons.article_outlined,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- BASIC INFO ---
            _buildSectionCard(
              title: "Basic Information",
              children: [
                _buildDisplayField("Full Name", _doctor['name'] ?? "N/A",
                    icon: Icons.badge),
                _buildDisplayField(
                    "Specialty", _doctor['specialization'] ?? "N/A",
                    icon: Icons.medical_services_outlined),
                _buildDisplayField("Grade", _doctor['grade'] ?? "N/A",
                    icon: Icons.military_tech_outlined),
                _buildDisplayField(
                    "Availability Status", _doctor['status'] ?? "N/A",
                    icon: Icons.circle,
                    iconColor: _doctor['status'] == "Available"
                        ? Colors.green
                        : Colors.redAccent),
                _buildDisplayField("Bio", _doctor['about_profile'] ?? "N/A",
                    icon: Icons.info_outline, maxLines: 4),
              ],
            ),
            const SizedBox(height: 12),

            // --- WORK & CREDENTIALS ---
            _buildSectionCard(
              title: "Work & Credentials",
              children: [
                _buildDisplayField("Company Name", _doctor['company_name'] ?? "N/A",
                    icon: Icons.business),
                _buildDisplayField("Job Title", _doctor['chamber_name'] ?? "N/A",
                    icon: Icons.work_outline),
                _buildDisplayField(
                    "Company Location", _doctor['job_location'] ?? "N/A",
                    icon: Icons.location_on_outlined),
                _buildDisplayField("BPC Licence #", _doctor['pcb_licence'] ?? "N/A",
                    icon: Icons.verified_outlined),
              ],
            ),
            const SizedBox(height: 12),

            // --- CONTACT ---
            _buildSectionCard(
              title: "Contact Information",
              children: [
                _buildDisplayField("Email Address", _doctor['email'] ?? "N/A",
                    icon: Icons.email_outlined),
                Builder(
                  builder: (context) {
                    final String visibility =
                        _doctor['phone_visibility'] ?? "Public";
                    final String rawPhone = _doctor['phone'] ?? "N/A";
                    final String displayPhone = visibility == "Private"
                        ? "🔒 Private (Hidden)"
                        : rawPhone;

                    return AbsorbPointer(
                      absorbing: visibility == "Private",
                      child: Opacity(
                        opacity: visibility == "Private" ? 0.7 : 1.0,
                        child: _buildInteractivePhoneField(
                          "Phone/Mobile",
                          displayPhone,
                          icon: Icons.phone_outlined,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- ADSMOB ---
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: DoctorTestBanner(adSize: AdSize.largeBanner),
            ),
            const SizedBox(height: 16),

            // --- POSTS ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "Posts & Updates",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 10),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('pcb_posts')
                  .select()
                  .eq('user_id', _targetId ?? '')
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator()));
                }

                final userPosts = snapshot.data ?? [];
                if (userPosts.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text("No posts shared by this user yet.",
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userPosts.length,
                  itemBuilder: (context, index) {
                    final post = userPosts[index];
                    final content = post['content'] ?? '';
                    final postImageUrl = post['image_url'];
                    final createdAt = post['created_at'];

                    // Inject profile details so they match the target user profile
                    post['user_name'] = _doctor['name'] ?? 'Professional';
                    post['user_avatar'] = imageUrl;

                    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                    final postUserId = post['user_id'];
                    final isMyPost = currentUserId != null && postUserId == currentUserId;

                    return GestureDetector(
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (BuildContext context) {
                            return SafeArea(
                              child: Wrap(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                                    child: Text(
                                      "Manage Post",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.copy, color: Colors.blueGrey),
                                    title: const Text("Copy Text"),
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (content.isNotEmpty) {
                                        Clipboard.setData(ClipboardData(text: content));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Post text copied to clipboard!"),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (isMyPost) ...[
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.redAccent),
                                      title: const Text("Delete Post"),
                                      onTap: () {
                                        Navigator.pop(context);
                                        // Trigger your delete confirmation or handler if you have one here
                                      },
                                    ),
                                  ] else ...[
                                    ListTile(
                                      leading: const Icon(Icons.report, color: Colors.orange),
                                      title: const Text("Report Post"),
                                      onTap: () {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Post reported.")),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Likecommentshare(post: post),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label,
      String value,
      IconData icon, {
        VoidCallback? onTap,
        VoidCallback? onDoubleTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const Divider(height: 20, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDisplayField(String label, String value,
      {int maxLines = 1,
        IconData? icon,
        Color iconColor = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon:
          icon != null ? Icon(icon, color: iconColor, size: 22) : null,
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildInteractivePhoneField(String label, String value,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _makePhoneCall(value),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.blueAccent, size: 22)
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue),
              ),
              const Icon(Icons.phone_forwarded,
                  size: 18, color: Colors.blueAccent),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Hero(
              tag: 'profile_image',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}