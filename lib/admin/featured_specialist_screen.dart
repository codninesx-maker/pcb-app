
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFeaturedSpecialistsScreen extends StatefulWidget {
  const AdminFeaturedSpecialistsScreen({super.key});

  @override
  State<AdminFeaturedSpecialistsScreen> createState() => _AdminFeaturedSpecialistsScreenState();
}

class _AdminFeaturedSpecialistsScreenState extends State<AdminFeaturedSpecialistsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _profile = [];
  List<Map<String, dynamic>> _filteredProfile = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _supabase.from('pcb').select().order('name');
      if (mounted) {
        setState(() {
          _profile = data;
          _filteredProfile = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterDoctors(String query) {
    setState(() {
      _filteredProfile = _profile.where((profile) {
        final name = (profile['name'] ?? "").toLowerCase();
        final specialty = (profile['specialization'] ?? "").toLowerCase();
        return name.contains(query.toLowerCase()) ||
            specialty.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _toggleFeatured(Map<String, dynamic> doctor, bool value) async {
    try {
      await _supabase
          .from('pcb')
          .update({'is_featured': value})
          .eq('id', doctor['id']);

      setState(() {
        doctor['is_featured'] = value;
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Featured Specialists List"),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterDoctors,
              decoration: InputDecoration(
                hintText: "Search specialists...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                      color: Colors.blueAccent, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent))
                : RefreshIndicator(
              onRefresh: _fetchProfile,
              child: ListView.builder(
                itemCount: _filteredProfile.length,
                itemBuilder: (context, index) {
                  final doctor = _filteredProfile[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: SwitchListTile(
                      activeColor: Colors.blueAccent,
                      title: Text(doctor['name'], style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          doctor['specialization'] ?? "No Specialty"),
                      value: (doctor['is_featured'] as bool?) ?? false,
                      onChanged: (bool value) => _toggleFeatured(doctor, value),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}