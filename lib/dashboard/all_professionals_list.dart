import 'package:doctor_profile/admobs/ads_test_banner.dart';
import 'package:doctor_profile/profile/view_all_profile_screen.dart';
import 'package:doctor_profile/profile/view_profile_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


class AllProfessionalsListSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> doctorsFuture;
  final String searchQuery;
  final VoidCallback onProfileReturned;
  final ValueChanged<Map<String, dynamic>> onDeleteRequested;

  const AllProfessionalsListSection({
    super.key,
    required this.doctorsFuture,
    required this.searchQuery,
    required this.onProfileReturned,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "All Professionals",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: doctorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final allDoctors = snapshot.data ?? [];
            final filteredDoctors = allDoctors.where((doctor) {
              final name = (doctor['name'] ?? "").toLowerCase();
              final specialty = (doctor['specialization'] ?? "").toLowerCase();
              return name.contains(searchQuery) || specialty.contains(searchQuery);
            }).toList();

            final displayList = filteredDoctors.take(10).toList();

            if (displayList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No doctors found."),
              );
            }

            int adCount = (displayList.length > 5 ? 1 : 0) + (displayList.length > 10 ? 1 : 0);

            return Column(
              children: [
                ...List.generate(displayList.length + adCount, (index) {
                  if (index == 5 || (index > 5 && (index - 1) % 6 == 0)) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        height: 100,
                        child: DoctorTestBanner(adSize: AdSize.largeBanner),
                      ),
                    );
                  }

                  int adsPassed = index > 5 ? 1 : 0;
                  if (index > 11) adsPassed = 2;
                  final doctorIndex = index - adsPassed;

                  if (doctorIndex >= displayList.length) return const SizedBox.shrink();

                  final doctor = displayList[doctorIndex];
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
                            builder: (context) => ProfileDetailScreen(doctor: doctor),
                          ),
                        );
                        onProfileReturned();
                      },
                      onLongPress: () {
                        debugPrint("Long Press detected for: ${doctor['name']}");
                        onDeleteRequested(doctor);
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: doctor['image_url'] != null
                            ? NetworkImage(doctor['image_url'])
                            : null,
                        child: doctor['image_url'] == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        doctor['name'] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(doctor['specialization'] ?? ""),
                      trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                    ),
                  );
                }),
                if (filteredDoctors.length > 10)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AllDoctorsScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
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