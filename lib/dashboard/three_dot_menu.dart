import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_profile/admin/admin_pannel.dart';
import 'package:doctor_profile/admin/user_login.dart';

class ThreeDotMenuWidget extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onMyProfile;
  final VoidCallback onLogout;

  const ThreeDotMenuWidget({
    super.key,
    required this.onRefresh,
    required this.onMyProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black87),
      onSelected: (value) async {
        if (value == 'refresh') {
          onRefresh();
        } else if (value == 'my_profile') {
          onMyProfile();
        } else if (value == 'login') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserLoginScreen()),
          );
        } else if (value == 'logout') {
          onLogout();
        } else if (value == 'admin_panel') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminPannelScreen()),
          );
        }
      },
      itemBuilder: (BuildContext context) {
        final currentUser = supabase.auth.currentUser;
        final bool isLoggedIn = currentUser != null;
        final bool isUserAdmin = currentUser?.email == "codninesx@gmail.com";

        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 20, color: Colors.black87),
                SizedBox(width: 10),
                Text('Refresh Data'),
              ],
            ),
          ),
          if (isLoggedIn)
            const PopupMenuItem<String>(
              value: 'my_profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('My Profile'),
                ],
              ),
            ),
          if (!isLoggedIn)
            const PopupMenuItem<String>(
              value: 'login',
              child: Row(
                children: [
                  Icon(Icons.login, size: 20, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Login', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          if (isLoggedIn)
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          if (isUserAdmin)
            const PopupMenuItem<String>(
              value: 'admin_panel',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 20, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Admin Panel'),
                ],
              ),
            ),
        ];
      },
    );
  }
}