import 'package:flutter/material.dart';

class LocationScreen extends StatefulWidget {
  final Function(String selectedLocation)? onLocationSelected;

  const LocationScreen({
    super.key,
    this.onLocationSelected,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _popularLocations = [
    "Dhaka",
    "Rajshahi",
    "Chittagong",
    "Sylhet",
    "Khulna",
    "Barisal",
    "Rangpur",
    "Mymensingh",
    "New York",
    "London",
  ];

  List<String> _filteredLocations = [];

  @override
  void initState() {
    super.initState();
    _filteredLocations = _popularLocations;
    _searchController.addListener(_filterLocations);
  }

  void _filterLocations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = _popularLocations;
      } else {
        _filteredLocations = _popularLocations
            .where((location) => location.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check in Location"),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search where you are...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // List of Locations
          Expanded(
            child: _filteredLocations.isEmpty
                ? const Center(
              child: Text(
                "No locations found",
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _filteredLocations.length,
              itemBuilder: (context, index) {
                final location = _filteredLocations[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    location,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text("Popular Place"),
                  onTap: () {
                    // 1. Trigger optional callback
                    widget.onLocationSelected?.call(location);

                    // 2. Safely pop and return the selected string back
                    Navigator.of(context).pop(location);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}