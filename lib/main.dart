import 'package:doctor_profile/dashboard/dashboard_view_screen.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Conditionally import AdMob so it compiles on web
import 'package:google_mobile_ads/google_mobile_ads.dart' 
    if (dart.library.html) 'ads_stub.dart';

// Conditionally import dart:html only when running on the web
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob SDK ONLY on mobile platforms
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  await Supabase.initialize(
    url: 'https://jqmlivtchooqbrwlsdzo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxbWxpdnRjaG9vcWJyd2xzZHpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NTQ2NTcsImV4cCI6MjA3NzIzMDY1N30.VIqjh70dqKfy5iP4Sb2jqvNOhMrFrbPA0fVP1Lqh4Bc',
  );

  runApp(const MyApp());
}

void checkForPostDeepLink(BuildContext context) {
  if (kIsWeb) {
    final String hash = getWebWindowHash();
    if (hash.contains('/post/')) {
      final uri = Uri.parse(hash.replaceFirst('#', ''));
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2 && pathSegments[0] == 'post') {
        final String postId = pathSegments[1];
        clearWebWindowHash();
        _openPostById(context, postId);
      }
    }
  }
}

Future<void> _openPostById(BuildContext context, String postId) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
  );

  try {
    final response = await Supabase.instance.client
        .from('pcb_posts')
        .select('''
          id,
          content,
          image_url,
          created_at,
          user_id,
          likes_count,
          comments_count,
          shares_count,
          liked_by,
          pcb:user_id (name, image_url)
        ''')
        .eq('id', postId)
        .maybeSingle();

    if (!context.mounted) return;
    Navigator.pop(context);

    if (response != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: response['pcb']?['image_url'] != null && response['pcb']['image_url'].toString().isNotEmpty
                    ? NetworkImage(response['pcb']['image_url'])
                    : null,
                child: response['pcb']?['image_url'] == null || response['pcb']['image_url'].toString().isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  response['pcb']?['name'] ?? 'PCB User',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  response['content'] ?? '',
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                if (response['image_url'] != null && response['image_url'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      response['image_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post not found or has been deleted.")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      debugPrint("Error opening deep link post: $e");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PCB App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeWrapper(),
    );
  }
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForPostDeepLink(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const DashboardViewScreen();
  }
}
