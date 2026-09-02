import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile-create_screen.dart'; // Or your profile detail view

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _myProfile;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Query the pcb table for the profile belonging to this auth user
      final data = await _supabase
          .from('pcb')
          .select()
          .eq('user_id', user.id) // Make sure 'user_id' exists in your 'pcb' table
          .maybeSingle();

      if (mounted) {
        setState(() {
          _myProfile = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching my profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myProfile == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "You haven't created a professional profile yet!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileCreateScreen()),
                  );
                  _fetchMyProfile(); // Refresh after creation
                },
                child: const Text("Create Profile", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _myProfile!['image_url'] != null
                  ? NetworkImage(_myProfile!['image_url'])
                  : null,
              child: _myProfile!['image_url'] == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _myProfile!['name'] ?? "No Name",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _myProfile!['specialization'] ?? "No Specialization",
              style: const TextStyle(fontSize: 16, color: Colors.blueAccent),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                title: const Text("Email / Contact"),
                subtitle: Text(_myProfile!['email'] ?? _supabase.auth.currentUser?.email ?? "N/A"),
                leading: const Icon(Icons.email, color: Colors.blueAccent),
              ),
            ),
            // Add more fields or an "Edit Profile" button here if desired
          ],
        ),
      ),
    );
  }
}