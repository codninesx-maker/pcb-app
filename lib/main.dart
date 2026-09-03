import 'package:doctor_profile/dashboard/dashboard_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob SDK safely
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  await Supabase.initialize(
    url: 'https://jqmlivtchooqbrwlsdzo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxbWxpdnRjaG9vcWJyd2xzZHpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NTQ2NTcsImV4cCI6MjA3NzIzMDY1N30.VIqjh70dqKfy5iP4Sb2jqvNOhMrFrbPA0fVP1Lqh4Bc',
  );

  runApp(const MyApp());
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
      home: const DashboardViewScreen(),
    );
  }
}

