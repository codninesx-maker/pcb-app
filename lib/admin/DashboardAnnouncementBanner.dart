import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart'; // Import the marquee package

class DashboardAnnouncementBanner extends StatelessWidget {
  final String announcementText;

  const DashboardAnnouncementBanner({super.key, required this.announcementText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 45, // Fixed height is required for the marquee widget
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.campaign, color: Colors.blueAccent, size: 20),
          ),
          Expanded(
            child: Marquee(
              text: announcementText,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w500,
              ),
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: 50.0,
              velocity: 50.0, // Speed of the marquee scroll
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
              accelerationDuration: const Duration(seconds: 1),
              decelerationDuration: const Duration(milliseconds: 500),
            ),
          ),
        ],
      ),
    );
  }
}