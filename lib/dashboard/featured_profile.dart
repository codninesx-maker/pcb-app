import 'package:flutter/material.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';


class FeaturedprofilesSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> profileFuture;
  final VoidCallback onprofileReturned;

  const FeaturedprofilesSection({
    super.key,
    required this.profileFuture,
    required this.onprofileReturned,
  });

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
          future: profileFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final featuredprofile = snapshot.data!
                .where((d) => d['is_featured'] == true)
                .toList()
              ..sort((a, b) {
                final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
                final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
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
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => profileDetailScreen(profile: profile),
                        ),
                      );
                      onprofileReturned();
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
                            backgroundImage: profile['image_url'] != null
                                ? NetworkImage(profile['image_url'])
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