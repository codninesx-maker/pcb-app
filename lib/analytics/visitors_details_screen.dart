import 'package:flutter/material.dart';
import 'package:pharmacist_profile/analytics/visitor_logs_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitorsDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> visitorData;

  const VisitorsDetailsScreen({
    super.key,
    required this.visitorData,
  });

  @override
  State<VisitorsDetailsScreen> createState() => _VisitorsDetailsScreenState();
}

class _VisitorsDetailsScreenState extends State<VisitorsDetailsScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _visitor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _visitor = widget.visitorData;
    _trackAndRefreshAnalytics();

  }

  // --- Real-time Activity & Visit Increment Logging ---
  Future<void> _trackAndRefreshAnalytics() async {
    final recordId = _visitor['id']?.toString();
    if (recordId == null || recordId.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      // 1. Fetch latest analytics data from Supabase table
      final response = await _supabase
          .from('pcb_visitor_analytics')
          .select()
          .eq('id', recordId)
          .maybeSingle();

      if (response != null) {
        if (mounted) {
          setState(() {
            _visitor = Map<String, dynamic>.from(response);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching visitor analytics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to format minutes into readable hours & minutes
  String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes mins';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }



  @override
  Widget build(BuildContext context) {
    // Extracting data with safe fallbacks matching your table schema
    final String visitorName = _visitor['visitor_name'] ?? 'Anonymous Visitor';
    final String visitorAvatar = _visitor['avatar_url'] ?? '';
    final int dailyVisits = _visitor['daily_visits'] ?? 1;
    final int dailyDurationMinutes = _visitor['daily_duration_minutes'] ?? 0;

    // Safely parse PostgreSQL text[] array
    final List<String> preferences = List<String>.from(_visitor['preferences'] ?? []);

    // Safely parse PostgreSQL jsonb[] array
    final rawActivity = _visitor['recent_activity'];
    final List<Map<String, dynamic>> recentActivity = rawActivity is List
        ? rawActivity.map((e) => Map<String, dynamic>.from(e)).toList()
        : [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Visitor Analytics'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _trackAndRefreshAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : RefreshIndicator(
        onRefresh: _trackAndRefreshAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- VISITOR PROFILE HEADER ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: visitorAvatar.isNotEmpty ? NetworkImage(visitorAvatar) : null,
                        child: visitorAvatar.isEmpty
                            ? const Icon(Icons.person, size: 28, color: Colors.blueAccent)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visitorName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => VisitorLogsSheet.show(context, _visitor), // ✅ Calls the separate class sheet method
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Tracked Visitor Analytics",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueAccent.shade700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blueAccent),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- DAILY METRICS CARDS ---
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: "Daily Visits",
                      value: "$dailyVisits times",
                      icon: Icons.touch_app_outlined,
                      iconColor: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: "Daily Duration",
                      value: _formatDuration(dailyDurationMinutes),
                      icon: Icons.timer_outlined,
                      iconColor: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- VISITOR PREFERENCES ---
              const Text(
                "Visitor Preferences",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: preferences.isNotEmpty
                      ? Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: preferences.map((pref) {
                      return Chip(
                        avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                        label: Text(pref),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide.none,
                      );
                    }).toList(),
                  )
                      : const Text(
                    "No specific preferences recorded yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- RECENT ACTIVITY TIMELINE ---
              const Text(
                "Recent Activity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: recentActivity.isNotEmpty
                    ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentActivity.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = recentActivity[index];
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.blueGrey, size: 20),
                      title: Text(
                        activity['action'] ?? 'Visited page',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        activity['time'] ?? 'Recently',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    );
                  },
                )
                    : const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No recent activity recorded.", style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Metric Card Helper Widget
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}