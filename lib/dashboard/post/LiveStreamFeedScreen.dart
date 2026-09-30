import 'package:flutter/material.dart';
import 'package:pharmacist_profile/dashboard/post/Liveplaceholder.dart';
import 'package:pharmacist_profile/dashboard/post/live.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LiveStreamFeedScreen extends StatefulWidget {
  const LiveStreamFeedScreen({super.key});

  @override
  State<LiveStreamFeedScreen> createState() => _LiveStreamFeedScreenState();
}

class _LiveStreamFeedScreenState extends State<LiveStreamFeedScreen> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Streams"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Listen to real-time changes on active streams
        stream: _supabase
            .from('pcblive_streams')
            .stream(primaryKey: ['id'])
            .eq('is_active', true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading live streams: ${snapshot.error}"));
          }

          final streams = snapshot.data ?? [];

          if (streams.isEmpty) {
            return const Center(
              child: Text(
                "No live streams right now.\nTap 'Go Live' to start one!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: streams.length,
            itemBuilder: (context, index) {
              final stream = streams[index];
              final streamId = stream['id'];
              final hostUserId = stream['host_user_id'];

              return FutureBuilder<Map<String, dynamic>?>(
                // Fetch host details from your 'pcb' profile table
                future: _supabase
                    .from('pcb')
                    .select('name, image_url')
                    .eq('user_id', hostUserId)
                    .maybeSingle(),
                builder: (context, userSnapshot) {
                  final hostData = userSnapshot.data;
                  final hostName = hostData?['name'] ?? 'Pharmacist Host';
                  final hostAvatar = hostData?['image_url'];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: hostAvatar != null
                            ? NetworkImage(hostAvatar)
                        as ImageProvider
                            : const AssetImage('assets/icon/logo.png'),
                      ),
                      title: Text(
                        "$hostName's Live",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("Tap to watch and join chat"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Navigate to your LiveScreen passing the host's user ID
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveScreenPlaceholder(
                                broadcasterUserId: hostUserId, // Pass the host's user ID here
                              ),
                            ),
                          );
                        },
                        child: const Text("Join"),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}