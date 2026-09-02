import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnnouncementMarquee extends StatefulWidget {
  final String? announcementText; // Made optional so it works when opened as a screen

  const AdminAnnouncementMarquee({
    super.key,
    this.announcementText,
  });

  @override
  State<AdminAnnouncementMarquee> createState() => _AdminAnnouncementMarqueeState();
}

class _AdminAnnouncementMarqueeState extends State<AdminAnnouncementMarquee> {
  final _supabase = Supabase.instance.client;
  final _announcementController = TextEditingController();
  late String _announcement;
  late final StreamSubscription _announcementSubscription;

  @override
  void initState() {
    super.initState();
    // Fallback to widget parameter if provided, otherwise default text
    _announcement = widget.announcementText ?? "Loading announcements...";
    _announcementController.text = _announcement;
    _listenToAnnouncements();
  }

  @override
  void dispose() {
    _announcementController.dispose();
    _announcementSubscription.cancel();
    super.dispose();
  }

  void _listenToAnnouncements() {
    _announcementSubscription = _supabase
        .from('pcb_app_settings')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          _announcement = data.first['announcement_text'] ?? "";
          if (_announcementController.text.isEmpty || _announcementController.text == "Loading announcements...") {
            _announcementController.text = _announcement;
          }
        });
      }
    }, onError: (error) {
      debugPrint("Stream error: $error");
    });
  }

  Future<void> _updateAnnouncement(String newText) async {
    if (newText.isEmpty) return;

    try {
      await _supabase
          .from('pcb_app_settings')
          .update({'announcement_text': newText})
          .eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Announcement updated successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Error updating announcement: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Announcement Settings"),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Current Active Marquee Text:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                _announcement,
                style: const TextStyle(fontSize: 15, color: Colors.blueAccent, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _announcementController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Update Marquee Text",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _updateAnnouncement(_announcementController.text),
                child: const Text("Save New Announcement", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}