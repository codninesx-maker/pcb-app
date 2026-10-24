import 'package:flutter/material.dart';

class VisitorLogsSheet extends StatelessWidget {
  final Map<String, dynamic> visitorData;

  const VisitorLogsSheet({
    super.key,
    required this.visitorData,
  });

  /// Helper to trigger the modal bottom sheet directly from anywhere
  static void show(BuildContext context, Map<String, dynamic> visitorData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => VisitorLogsSheet(visitorData: visitorData),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract recent activity & history safely
    final rawActivity = visitorData['recent_activity'];
    final List<Map<String, dynamic>> activityLogs = rawActivity is List
        ? rawActivity.map((e) => Map<String, dynamic>.from(e)).toList()
        : [];

    final int totalVisits = visitorData['daily_visits'] ?? 1;
    final String visitorName = visitorData['visitor_name'] ?? 'Visitor';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Visitor Activity Logs",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Detailed logs for $visitorName",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$totalVisits Visits Today",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Activity Logs List
              Expanded(
                child: activityLogs.isNotEmpty
                    ? ListView.builder(
                  controller: scrollController,
                  itemCount: activityLogs.length,
                  itemBuilder: (context, index) {
                    final log = activityLogs[index];
                    final String action = log['action'] ?? 'Visited Page';
                    final String timeStr = log['time'] ?? 'Recently';
                    final String page = log['page'] ?? 'Profile View';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                            Colors.blueAccent.withOpacity(0.1),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Section: $page",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
                    : const Center(
                  child: Text(
                    "No detailed activity logs recorded.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}