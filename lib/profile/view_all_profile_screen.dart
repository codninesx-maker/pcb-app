import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:pharmacist_profile/profile/view_profile_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllprofileScreen extends StatefulWidget {
  const AllprofileScreen({super.key});

  @override
  State<AllprofileScreen> createState() => _AllprofileScreenState();
}

class _AllprofileScreenState extends State<AllprofileScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _searchCategory = "All"; // Default filter category

  final List<String> _categories = ["All", "Name", "Specialty", "Company", "Grade"];

  // Offline caching state
  static const String _cachedAllProfilesKey = 'cached_all_profiles_data';
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfilesWithOfflineFallback();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilesWithOfflineFallback() async {
    setState(() => _isLoading = true);

    // 1. Load cached profiles locally first for immediate offline viewing
    await _loadCachedProfiles();

    // 2. Fetch fresh data from Supabase if online
    try {
      final data = await Supabase.instance.client
          .from('pcb')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> fetchedProfiles =
      List<Map<String, dynamic>>.from(data);

      // Save fresh data to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedAllProfilesKey, jsonEncode(fetchedProfiles));

      if (mounted) {
        setState(() {
          _profiles = fetchedProfiles;
        });
      }
    } catch (e) {
      debugPrint("Offline mode active: Using cached profiles ($e)");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCachedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_cachedAllProfilesKey);

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final List<Map<String, dynamic>> cachedList =
        decoded.map((e) => Map<String, dynamic>.from(e)).toList();

        if (mounted) {
          setState(() {
            _profiles = cachedList;
          });
        }
      }
    } catch (e) {
      debugPrint("Error reading cached profiles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter profiles dynamically based on dropdown category & search query
    final filteredProfiles = _profiles.where((profile) {
      final name = (profile['name'] ?? "").toString().toLowerCase();
      final specialty = (profile['specialization'] ?? "").toString().toLowerCase();
      final company = (profile['company_name'] ?? "").toString().toLowerCase();
      final grade = (profile['grade'] ?? "").toString().toLowerCase();

      if (_searchQuery.isEmpty) return true;

      switch (_searchCategory) {
        case "Name":
          return name.contains(_searchQuery);
        case "Specialty":
          return specialty.contains(_searchQuery);
        case "Company":
          return company.contains(_searchQuery);
        case "Grade":
          return grade.contains(_searchQuery);
        case "All":
        default:
          return name.contains(_searchQuery) ||
              specialty.contains(_searchQuery) ||
              company.contains(_searchQuery) ||
              grade.contains(_searchQuery);
      }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("All Professionals"),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfilesWithOfflineFallback,
        child: Column(
          children: [
            // --- Top Search Bar & Dropdown Container ---
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  // --- Dropdown Menu ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _searchCategory,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _searchCategory = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // --- Search Input ---
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search by $_searchCategory...",
                        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
                            });
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Colors.blueAccent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Profiles List View ---
            Expanded(
              child: _isLoading && _profiles.isEmpty
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : filteredProfiles.isEmpty
                  ? const Center(
                child: Text(
                  "No matching profiles found.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : Builder(
                builder: (context) {
                  int adCount = filteredProfiles.length >= 5
                      ? filteredProfiles.length ~/ 5
                      : 0;
                  int totalItems = filteredProfiles.length + adCount;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      final bool isAdSlot =
                          filteredProfiles.length >= 5 && (index + 1) % 6 == 0;

                      if (isAdSlot) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            height: 50,
                            child: pharmacistTestBanner(adSize: AdSize.banner),
                          ),
                        );
                      }

                      int adsBeforeThis =
                      filteredProfiles.length >= 5 ? index ~/ 6 : 0;
                      int profileIndex = index - adsBeforeThis;

                      if (profileIndex < 0 ||
                          profileIndex >= filteredProfiles.length) {
                        return const SizedBox.shrink();
                      }

                      final profile = filteredProfiles[profileIndex];
                      final imageUrl = profile['image_url'];
                      final name = profile['name'] ?? "Unknown";
                      final specialization = profile['specialization'] ??
                          "Specialization not specified";
                      final company = profile['company_name'];
                      final grade = profile['grade'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    profileDetailScreen(profile: profile),
                              ),
                            ),

                            // --- Offline-Safe Avatar Implementation ---
                            // --- Offline-Safe Avatar Implementation ---
                            leading: ClipOval(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                                    ? CachedNetworkImage(
                                  imageUrl: imageUrl.toString(),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    child: const Icon(Icons.person, color: Colors.blueAccent),
                                  ),
                                )
                                    : Container(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Colors.blueAccent),
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  specialization,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13),
                                ),
                                if (grade != null &&
                                    grade.toString().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent
                                              .withOpacity(0.1),
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "Grade: $grade",
                                          style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (company != null &&
                                    company.toString().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    company.toString(),
                                    style: TextStyle(
                                        color: Colors.blueGrey.shade400,
                                        fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.blueAccent),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}