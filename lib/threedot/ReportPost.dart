import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportHelper {
  static const String adminWhatsAppNumber = "+8801778073934";

  static Future<void> reportPostToWhatsApp(BuildContext context, String postId, String postContent) async {
    final String message = "Hello Admin, I would like to report a post on the PCB app.\n\nPost ID: $postId\nContent: \"$postContent\"";

    // WhatsApp URL scheme
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$adminWhatsAppNumber?text=${Uri.encodeComponent(message)}",
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open WhatsApp. Please ensure WhatsApp is installed."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error launching WhatsApp: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}