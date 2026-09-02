import 'package:doctor_profile/profile/view_profile_detail_screen.dart';
import 'package:flutter/material.dart';
// TODO: Import your ProfileDetailScreen here, e.g.:
// import 'profile_detail_screen.dart';

class FeaturedProfilesSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> doctorsFuture;
  final VoidCallback onProfileReturned;

  const FeaturedProfilesSection({
    super.key,
    required this.doctorsFuture,
    required this.onProfileReturned,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        const Text(
          "Featured Specialists",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: doctorsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final featuredDoctors = snapshot.data!
                .where((d) => d['is_featured'] == true)
                .toList()
              ..sort((a, b) {
                final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
                final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
                return bDate.compareTo(aDate);
              });

            if (featuredDoctors.isEmpty) return const SizedBox();

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: featuredDoctors.length,
                itemBuilder: (context, index) {
                  final doctor = featuredDoctors[index];
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileDetailScreen(doctor: doctor),
                        ),
                      );
                      onProfileReturned();
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
                            backgroundImage: doctor['image_url'] != null
                                ? NetworkImage(doctor['image_url'])
                                : const NetworkImage('https://i.pravatar.cc/150'),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              doctor['name'] ?? "Unknown",
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
                              doctor['specialization'] ?? "",
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