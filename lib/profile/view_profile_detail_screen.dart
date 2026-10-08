import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../stats/views_screen.dart';
import '../stats/followers_screen.dart';
import 'edit_profile_screen.dart';
import '../dashboard/post/like_coments_share.dart';

class profileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  // FIX: Removed the redundant `profiles` parameter
  const profileDetailScreen({super.key, required this.profile});

  @override
  State<profileDetailScreen> createState() => _profileDetailScreenState();
}

class _profileDetailScreenState extends State<profileDetailScreen> {
  late Map<String, dynamic> _profile;
  bool _isFollowing = false;

  String? get _targetUserId => _profile['user_id']?.toString();
  String? get _targetPcbId => _profile['id']?.toString();

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _refreshData();
    _initializeprofile();
    _checkFollowStatus();
  }

  String? get _targetId =>
      (_profile['user_id'] ?? _profile['id'] ?? _profile['uuid'])?.toString();

  Future<void> _incrementViewCount(Map<String, dynamic> freshprofile) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final profileOwnerId = _targetId;

      if (currentUserId != null &&
          profileOwnerId != null &&
          currentUserId != profileOwnerId) {
        final currentCount = (freshprofile['view_count'] as num?)?.toInt() ?? 0;
        final newCount = currentCount + 1;

        final pcbId = freshprofile['id'] ?? profileOwnerId;
        await Supabase.instance.client
            .from('pcb')
            .update({'view_count': newCount})
            .eq('id', pcbId);

        if (mounted) {
          setState(() {
            _profile['view_count'] = newCount;
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
          _profile = response;
        });
        _incrementViewCount(response);
      }
    } catch (e) {
      debugPrint("Refresh Error: $e");
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || _targetId == null) return;

    try {
      if (_isFollowing) {
        // --- UNFOLLOW: Delete row ---
        await Supabase.instance.client
            .from('pcb_followers')
            .delete()
            .eq('follower_id', currentUser.id)
            .eq('following_id', _targetId!);

        setState(() {
          _isFollowing = false;
          int currentCount = int.tryParse(_profile['followers_count']?.toString() ?? '0') ?? 0;
          _profile['followers_count'] = currentCount > 0 ? currentCount - 1 : 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unfollowed")),
        );
      } else {
        // --- FOLLOW: Insert row ---
        await Supabase.instance.client
            .from('pcb_followers')
            .insert({
          'follower_id': currentUser.id,
          'following_id': _targetId!,
        });

        setState(() {
          _isFollowing = true;
          int currentCount = int.tryParse(_profile['followers_count']?.toString() ?? '0') ?? 0;
          _profile['followers_count'] = currentCount + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Following")),
        );
      }
    } catch (e) {
      debugPrint("Error toggling follow: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update follow status.")),
      );
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetId = _targetId;
    if (currentUser == null || targetId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('pcb_followers')
          .select('id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFollowing = response != null; // True if record exists, false otherwise
        });
      }
    } catch (e) {
      debugPrint("Error checking follow status: $e");
    }
  }

  Future<void> _initializeprofile() async {
    final targetUserId = _targetId;
    if (targetUserId == null || targetUserId.isEmpty) return;

    try {
      final responseList = await Supabase.instance.client
          .from('pcb')
          .select()
          .or('user_id.eq.$targetUserId,id.eq.$targetUserId')
          .limit(1);

      if (responseList.isNotEmpty) {
        setState(() {
          _profile = Map<String, dynamic>.from(responseList.first);
        });
      }
    } catch (e) {
      debugPrint("Error fetching full profile on init: $e");
    }

    await _refreshData();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final String? authEmail = currentUser?.email?.trim().toLowerCase();
    final String? docEmail = _profile['email']?.toString().trim().toLowerCase();

    final bool isOwner = (currentUser != null &&
        authEmail != null &&
        docEmail != null &&
        authEmail == docEmail);

    final String? imageUrl = (_profile['image_url'] != null &&
        _profile['image_url'].toString().isNotEmpty)
        ? _profile['image_url']
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
          "profile Details",
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
                        builder: (_) => EditprofileScreen(userData: _profile)));
                if (result == true) await _refreshData();
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
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
                      final coverUrl = (_profile['cover_url'] != null &&
                          _profile['cover_url'].toString().isNotEmpty)
                          ? _profile['cover_url']
                          : imageUrl;

                      if (coverUrl != null) {
                        _showFullImage(context, coverUrl);
                      }
                    },
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.blueAccent.withOpacity(0.15),
                      child: (_profile['cover_url'] != null &&
                          _profile['cover_url'].toString().isNotEmpty)
                          ? Image.network(
                        _profile['cover_url'],
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
                                          color: _profile['status'] ==
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
                                  "${_profile['view_count'] ?? 0}",
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
                                  "${_profile['followers_count'] ?? 0}",
                                  Icons.people_outline,
                                  onTap: () {
                                    final targetId = _targetId;
                                    if (targetId == null) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersScreen(
                                            profileId: targetId),
                                      ),
                                    );
                                  },
                                  onDoubleTap: _toggleFollow,
                                ),
                                _buildStatItem(
                                  "Following",
                                  "${_profile['following_count'] ?? 0}",
                                  Icons.person_add_alt_outlined,
                                  onTap: () {
                                    final targetId = _targetId;
                                    if (targetId == null) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowersScreen(
                                          profileId: targetId,
                                          listType: FollowListType.following,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildStatItem(
                                  "Posts",
                                  "${_profile['posts_count'] ?? 0}",
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

            _buildSectionCard(
              title: "Basic Information",
              children: [
                _buildDisplayField("Full Name", _profile['name'] ?? "N/A",
                    icon: Icons.badge),
                _buildDisplayField(
                    "Specialty", _profile['specialization'] ?? "N/A",
                    icon: Icons.medical_services_outlined),
                _buildDisplayField("Grade", _profile['grade'] ?? "N/A",
                    icon: Icons.military_tech_outlined),
                _buildDisplayField(
                    "Availability Status", _profile['status'] ?? "N/A",
                    icon: Icons.circle,
                    iconColor: _profile['status'] == "Available"
                        ? Colors.green
                        : Colors.redAccent),
                _buildDisplayField("Bio", _profile['about_profile'] ?? "N/A",
                    icon: Icons.info_outline, maxLines: 4),
              ],
            ),
            const SizedBox(height: 12),

            _buildSectionCard(
              title: "Work & Credentials",
              children: [
                _buildDisplayField("Company Name", _profile['company_name'] ?? "N/A",
                    icon: Icons.business),
                _buildDisplayField("Job Title", _profile['chamber_name'] ?? "N/A",
                    icon: Icons.work_outline),
                _buildDisplayField(
                    "Company Location", _profile['job_location'] ?? "N/A",
                    icon: Icons.location_on_outlined),
                _buildDisplayField("PCB Licence #", _profile['pcb_licence'] ?? "N/A",
                    icon: Icons.verified_outlined),
              ],
            ),
            const SizedBox(height: 12),

            _buildSectionCard(
              title: "Contact Information",
              children: [
                _buildDisplayField("Email Address", _profile['email'] ?? "N/A",
                    icon: Icons.email_outlined),
                Builder(
                  builder: (context) {
                    final String visibility =
                        _profile['phone_visibility'] ?? "Public";
                    final String rawPhone = _profile['phone'] ?? "N/A";
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

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: pharmacistTestBanner(adSize: AdSize.banner),
            ),
            const SizedBox(height: 16),

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

                // FIX APPLIED HERE: Map and normalize video/media fields
                final userPosts = snapshot.data?.map((post) {
                  final mutablePost = Map<String, dynamic>.from(post);

                  mutablePost['user_name'] = _profile['name'] ?? 'Professional';
                  mutablePost['user_avatar'] = imageUrl;

                  // Normalize video URL if it's stored in video_url instead of media_url
                  if ((mutablePost['media_url'] == null || mutablePost['media_url'].toString().isEmpty) &&
                      (mutablePost['video_url'] != null && mutablePost['video_url'].toString().isNotEmpty)) {
                    mutablePost['media_url'] = mutablePost['video_url'];
                    mutablePost['media_type'] = 'video';
                  }

                  return mutablePost;
                }).toList() ?? [];

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
      {int? maxLines, // Changed from default 1 to allow full display when needed
        IconData? icon,
        Color iconColor = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: iconColor, size: 22) : null,
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          maxLines: maxLines, // If null or 4, it wraps cleanly up to that limit (or fully if null)
          overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            height: 1.4, // Adds breathing room between lines for multi-line text like Bios
          ),
        ),
      ),
    );
  }

  Widget _buildInteractivePhoneField(String label, String value,
      {IconData? icon}) {
    final bool isPrivate = value.contains("Private");
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: icon != null
              ? const Icon(Icons.phone_outlined,
              color: Colors.blueAccent, size: 22)
              : null,
          suffixIcon: !isPrivate
              ? IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () {
              final rawPhone = _profile['phone'];
              if (rawPhone != null) {
                _makePhoneCall(rawPhone.toString());
              }
            },
          )
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
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}