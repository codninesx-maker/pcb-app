import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';

class FeaturedprofilesSection extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> profileFuture;
  final VoidCallback onprofileReturned;

  const FeaturedprofilesSection({
    super.key,
    required this.profileFuture,
    required this.onprofileReturned,
  });

  @override
  State<FeaturedprofilesSection> createState() => _FeaturedprofilesSectionState();
}

class _FeaturedprofilesSectionState extends State<FeaturedprofilesSection> {
  static const String _cachedProfilesKey = 'cached_featured_profiles';
  late Future<List<Map<String, dynamic>>> _combinedFuture;

  @override
  void initState() {
    super.initState();
    _combinedFuture = _fetchWithOfflineFallback();
  }

  @override
  void didUpdateWidget(covariant FeaturedprofilesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileFuture != widget.profileFuture) {
      setState(() {
        _combinedFuture = _fetchWithOfflineFallback();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWithOfflineFallback() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final profiles = await widget.profileFuture;
      if (profiles.isNotEmpty) {
        await prefs.setString(_cachedProfilesKey, jsonEncode(profiles));
      }
      return profiles;
    } catch (e) {
      final cachedString = prefs.getString(_cachedProfilesKey);
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        const Text(
          "Featured Pharmacists",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _combinedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox();
            }

            final featuredprofile = snapshot.data!
                .where((d) => d['is_featured'] == true)
                .toList()
              ..sort((a, b) {
                final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
                final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
                return bDate.compareTo(aDate);
              });

            if (featuredprofile.isEmpty) return const SizedBox();

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: featuredprofile.length,
                itemBuilder: (context, index) {
                  final profile = featuredprofile[index];
                  final imageUrl = profile['image_url'];

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => profileDetailScreen(profile: profile),
                        ),
                      );
                      widget.onprofileReturned();
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (imageUrl != null && imageUrl.toString().isNotEmpty)
                                ? CachedNetworkImageProvider(imageUrl.toString()) as ImageProvider
                                : const NetworkImage('https://i.pravatar.cc/150'),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              profile['name'] ?? "Unknown",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              profile['specialization'] ?? "",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}