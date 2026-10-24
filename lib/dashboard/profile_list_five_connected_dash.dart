import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/profile/view_all_profile_screen.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';

import '../admobs/ads_test_banner.dart';

class AllProfessionalsListSection extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> profileFuture;
  final String searchQuery;
  final VoidCallback onprofileReturned;
  final ValueChanged<Map<String, dynamic>> onDeleteRequested;

  const AllProfessionalsListSection({
    super.key,
    required this.profileFuture,
    required this.searchQuery,
    required this.onprofileReturned,
    required this.onDeleteRequested,
  });

  @override
  State<AllProfessionalsListSection> createState() => _AllProfessionalsListSectionState();
}

class _AllProfessionalsListSectionState extends State<AllProfessionalsListSection> {
  static const String _cachedAllProfilesKey = 'cached_all_professionals';
  late Future<List<Map<String, dynamic>>> _combinedFuture;

  @override
  void initState() {
    super.initState();
    _combinedFuture = _fetchWithOfflineFallback();
  }

  @override
  void didUpdateWidget(covariant AllProfessionalsListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileFuture != widget.profileFuture) {
      setState(() {
        _combinedFuture = _fetchWithOfflineFallback();
      });
    }
  }

  // Attempts to fetch online data, sort newest first, and cache locally
  Future<List<Map<String, dynamic>>> _fetchWithOfflineFallback() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final profiles = await widget.profileFuture;

      // Ensure newest profiles are always sorted at top
      profiles.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime); // Descending order
      });

      if (profiles.isNotEmpty) {
        await prefs.setString(_cachedAllProfilesKey, jsonEncode(profiles));
      }
      return profiles;
    } catch (e) {
      final cachedString = prefs.getString(_cachedAllProfilesKey);
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        final cachedList = decoded.map((item) => Map<String, dynamic>.from(item)).toList();

        cachedList.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        return cachedList;
      }
      rethrow;
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "New Pharmacists",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _combinedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final allprofile = snapshot.data ?? [];
            final filteredprofile = allprofile.where((profile) {
              final name = (profile['name'] ?? "").toLowerCase();
              final specialty = (profile['specialization'] ?? "").toLowerCase();
              return name.contains(widget.searchQuery) || specialty.contains(widget.searchQuery);
            }).toList();

            // Limit dashboard view to top 5 newest profiles
            final displayList = filteredprofile.take(5).toList();

            if (displayList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No profiles found."),
              );
            }

            bool showAd = displayList.length >= 5;
            int totalItems = displayList.length + (showAd ? 1 : 0);

            return Column(
              children: [
                ...List.generate(totalItems, (index) {
                  if (showAd && index == 5) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        height: 50,
                        child: pharmacistTestBanner(adSize: AdSize.banner),
                      ),
                    );
                  }

                  int profileIndex = (showAd && index > 5) ? index - 1 : index;

                  if (profileIndex >= displayList.length) return const SizedBox.shrink();

                  final profile = displayList[profileIndex];
                  final imageUrl = profile['image_url'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => profileDetailScreen(profile: profile),
                          ),
                        );
                        widget.onprofileReturned();
                      },
                      onLongPress: () {
                        final name = profile['name'] ?? "Unknown";
                        final profileId = profile['id'] ?? name;
                        final appLink = "https://codninesx-maker.github.io/pcb-app/#/post/$profileId";

                        Clipboard.setData(ClipboardData(text: appLink));

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Copied link for $name to clipboard!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        debugPrint("Long Press: Copied link -> $appLink");
                      },
                      leading: GestureDetector(
                        onTap: () {
                          // Prevents the ListTile's onTap from triggering when tapping the avatar
                          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                            _showFullImage(context, imageUrl.toString());
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          backgroundImage: (imageUrl != null && imageUrl.toString().isNotEmpty)
                              ? CachedNetworkImageProvider(imageUrl.toString()) as ImageProvider
                              : null,
                          child: (imageUrl == null || imageUrl.toString().isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                      ),
                      title: Text(
                        profile['name'] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(profile['specialization'] ?? ""),
                      trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                    ),
                  );
                }),

                if (filteredprofile.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AllprofileScreen()),
                        );
                      },
                      icon: const Icon(Icons.people),
                      label: const Text("View More Pharmacists"),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}