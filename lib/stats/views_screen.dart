import 'package:doctor_profile/profile/view_profile_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewsScreen extends StatefulWidget {
  final String ownerId;

  const ViewsScreen({super.key, required this.ownerId});

  @override
  State<ViewsScreen> createState() => _ViewsScreenState();
}

class _ViewsScreenState extends State<ViewsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _viewersList = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileViews();
  }

  Future<void> _fetchProfileViews() async {
    try {
      setState(() => _isLoading = true);

      // 1. Fetch raw view records for this owner (sorted newest first)
      debugPrint("DEBUG: Querying views for ownerId: ${widget.ownerId}");
      final viewsResponse = await _supabase
          .from('pcb_profile_views')
          .select('id, viewer_id, created_at') // Make sure 'id' is selected here
          .eq('owner_id', widget.ownerId)
          .order('created_at', ascending: false);
      debugPrint("DEBUG: Raw views returned: $viewsResponse");

      final List<dynamic> rawViews = viewsResponse;
      if (rawViews.isEmpty) {
        setState(() {
          _viewersList = [];
          _isLoading = false;
        });
        return;
      }

      // 1.5. Deduplicate in memory and collect IDs of older duplicates to delete
      final Map<String, Map<String, dynamic>> uniqueViewsMap = {};
      final List<String> duplicateRowIds = [];

      for (var view in rawViews) {
        final viewerId = view['viewer_id']?.toString();
        final rowId = view['id']?.toString();

        if (viewerId != null) {
          if (!uniqueViewsMap.containsKey(viewerId)) {
            // Keep the first (newest) occurrence
            uniqueViewsMap[viewerId] = view;
          } else if (rowId != null) {
            // Mark subsequent (older) occurrences for deletion
            duplicateRowIds.add(rowId);
          }
        }
      }

      // 1.6. Automatically delete older duplicate views from Supabase in the background
      if (duplicateRowIds.isNotEmpty) {
        // Supabase allows deleting in batches using .inFilter
        _supabase
            .from('pcb_profile_views')
            .delete()
            .inFilter('id', duplicateRowIds)
            .then((_) {
          debugPrint("Cleaned up ${duplicateRowIds.length} duplicate view records.");
        }).catchError((err) {
          debugPrint("Error cleaning up duplicate views: $err");
        });
      }

      final List<Map<String, dynamic>> distinctViews = uniqueViewsMap.values.toList();

      // 2. Extract unique viewer IDs from the deduplicated list
      final viewerIds = distinctViews
          .map((v) => v['viewer_id'].toString())
          .toSet()
          .toList();

      if (viewerIds.isEmpty) {
        setState(() {
          _viewersList = [];
          _isLoading = false;
        });
        return;
      }

      // 3. Fetch user details from the 'pcb' table using .inFilter()
      final usersResponse = await _supabase
          .from('pcb')
          .select('id, user_id, name, image_url, specialization, grade')
          .inFilter('user_id', viewerIds);

      final List<dynamic> usersData = usersResponse;

      // Populate userMap for quick lookups
      final Map<String, Map<String, dynamic>> userMap = {};
      for (var user in usersData) {
        if (user['id'] != null) userMap[user['id'].toString()] = user;
        if (user['user_id'] != null) userMap[user['user_id'].toString()] = user;
      }

      // 4. Combine the distinct view records with the fetched user profile details
      final combinedList = distinctViews.map((view) {
        final viewerId = view['viewer_id'].toString();
        final userInfo = userMap[viewerId] ?? {};
        return {
          'created_at': view['created_at'],
          'viewer': userInfo,
        };
      }).toList();

      setState(() {
        _viewersList = List<Map<String, dynamic>>.from(combinedList);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching profile views: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          "Profile Viewers",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewersList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No profile views yet",
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchProfileViews,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _viewersList.length,
          itemBuilder: (context, index) {
            final viewRecord = _viewersList[index];
            final viewer = viewRecord['viewer'] ?? {};
            final viewerName = viewer['name'] ?? "Anonymous User";
            final viewerImage = viewer['image_url'];
            final viewerSpecialty = viewer['specialization'] ?? "Professional";
            final viewedAt = viewRecord['created_at'];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () {
                  // Navigates to the profile screen when the card/tile is tapped
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileDetailScreen(
                        doctor: viewer,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: viewerImage != null && viewerImage.isNotEmpty
                      ? NetworkImage(viewerImage)
                      : null,
                  child: viewerImage == null || viewerImage.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  viewerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(viewerSpecialty, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    if (viewedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Viewed: ${_formatDate(viewedAt)}",
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}