import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TagUserScreen extends StatefulWidget {
  final Function(Map<String, dynamic> selectedUser) onUserTagged;

  const TagUserScreen({
    super.key,
    required this.onUserTagged,
  });

  @override
  State<TagUserScreen> createState() => _TagUserScreenState();
}

class _TagUserScreenState extends State<TagUserScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersToTag();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersToTag() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('pcb')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response);
          _filteredUsers = _allUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users for tagging: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterUsers(String query) {
    final searchTerm = query.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final specialty = (user['specialization'] ?? user['profession'] ?? '').toLowerCase();
        return name.contains(searchTerm) || specialty.contains(searchTerm);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tag a Professional", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Search Input Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: "Search name or specialty to tag...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterUsers('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
          ),

          // User Selection List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text("No professionals found", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final imageUrl = user['image_url']?.toString();
                final name = user['name'] ?? 'Unknown Name';
                final specialty = user['specialization'] ?? user['profession'] ?? 'Professional';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                          ? NetworkImage(imageUrl)
                          : null,
                      child: (imageUrl == null || imageUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.blueAccent)
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      specialty,
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    onTap: () {
                      // Trigger callback and pop back
                      widget.onUserTagged(user);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}