import 'package:doctor_profile/admin/announcement_marque.dart';
import 'package:doctor_profile/admin/featured_specialist_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPannelScreen extends StatefulWidget {
  const AdminPannelScreen({super.key});

  @override
  State<AdminPannelScreen> createState() => _AdminPannelScreenState();
}

class _AdminPannelScreenState extends State<AdminPannelScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAuthorization();
  }

  void _checkAdminAuthorization() {
    final user = _supabase.auth.currentUser;
    const targetEmail = "codninesx@gmail.com";

    if (user != null && user.email == targetEmail) {
      setState(() {
        _isAuthorized = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : !_isAuthorized
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  "Access Denied",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You must be logged in as codninesx@gmail.com to access the Admin Panel.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Admin Dashboard",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              const Text(
                "Select an option below to manage platform content.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Option 1: Announcement Settings Card
              _buildMenuCard(
                context,
                title: "Announcement Settings",
                subtitle: "Update app marquee texts & announcements",
                icon: Icons.campaign,
                iconColor: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminAnnouncementMarquee()),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Featured Specialists List Card
              _buildMenuCard(
                context,
                title: "Featured Specialists List",
                subtitle: "Toggle and search professionals to feature",
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminFeaturedSpecialistsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}