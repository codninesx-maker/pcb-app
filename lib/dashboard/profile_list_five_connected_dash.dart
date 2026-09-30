import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart';
import 'package:pharmacist_profile/profile/view_all_profile_screen.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';

import '../admobs/ads_test_banner.dart';

class AllProfessionalsListSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> profileFuture;
  final String searchQuery;
  final VoidCallback onprofileReturned;
  // Optional: If you want to notify parent or handle it locally.
  // We can change the callback name or keep it flexible.
  final ValueChanged<Map<String, dynamic>> onDeleteRequested;

  const AllProfessionalsListSection({
    super.key,
    required this.profileFuture,
    required this.searchQuery,
    required this.onprofileReturned,
    required this.onDeleteRequested,
  });

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
          future: profileFuture,
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
              return name.contains(searchQuery) || specialty.contains(searchQuery);
            }).toList();

            // Limit dashboard view to a maximum of 5 profiles
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
                        onprofileReturned();
                      },
                      onLongPress: () {
                        // 1. Get the profile details (using a unique identifier or name)
                        final name = profile['name'] ?? "Unknown";
                        final profileId = profile['id'] ?? name; // Uses profile ID or falls back to name

                        // 2. Create your app's link using the profile data
                        final appLink = "https://codninesx-maker.github.io/pcb-app/#/post/$profileId";

                        // 3. Copy the link to the clipboard
                        Clipboard.setData(ClipboardData(text: appLink));

                        // 4. Provide feedback to the user via SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Copied link for $name to clipboard!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        debugPrint("Long Press: Copied link -> $appLink");
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: profile['image_url'] != null
                            ? NetworkImage(profile['image_url'])
                            : null,
                        child: profile['image_url'] == null ? const Icon(Icons.person) : null,
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
                      label: const Text("View More Professionals"),
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