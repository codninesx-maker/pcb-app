import 'package:doctor_profile/profile/view_profile_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllDoctorsScreen extends StatelessWidget {
  const AllDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Professionals")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('pcb').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final doctors = snapshot.data!;
          return ListView.builder(
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return ListTile(
                leading: CircleAvatar(backgroundImage: doctor['image_url'] != null ? NetworkImage(doctor['image_url']) : null),
                title: Text(doctor['name']),
                subtitle: Text(doctor['specialization'] ?? ""),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(doctor: doctor))),
              );
            },
          );
        },
      ),
    );
  }
}