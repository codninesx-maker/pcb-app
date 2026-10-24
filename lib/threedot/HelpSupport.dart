import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // List of FAQs
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I create or update my professional profile?',
      'answer':
      'Tap the "+" button on the home screen or open the menu and select "My profile". Fill in your registration details, designation, grade, and workplace information, then save.',
    },
    {
      'question': 'Who can join the PCB platform?',
      'answer':
      'PCB is dedicated to registered pharmacists, pharmacy students, and healthcare professionals seeking professional networking and community collaboration.',
    },
    {
      'question': 'How does offline mode work?',
      'answer':
      'The app automatically caches previously loaded profiles, news feed posts, and announcements so you can view them even without an active internet connection.',
    },
    {
      'question': 'How do I connect with or follow other pharmacists?',
      'answer':
      'Search for a colleague using the search bar on the home screen, open their profile, and double tap the "Follow" button.',
    },
    {
      'question': 'How can I report inappropriate posts or profiles?',
      'answer':
      'Tap the three dots icon on any post or profile card and select "Report". Our moderation team will review the content promptly.',
    },
    {
      'question': 'How do notifications work?',
      'answer':
      'You receive real-time popup notifications when someone follows your profile, reacts to your post, or sends a direct message.',
    },
  ];

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch $urlString: $e");
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'codninesx@gmail.com',
      queryParameters: {
        'subject': 'PCB App Support Request',
      },
    );

    try {
      bool launched = false;

      // Try launching external non-browser application first
      if (await canLaunchUrl(emailUri)) {
        launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }

      // Fallback attempt with external application mode
      if (!launched) {
        launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
      }

      // If still not launched (e.g. no mail app on emulator), copy to clipboard
      if (!launched && mounted) {
        _copyEmailToClipboard();
      }
    } catch (e) {
      if (mounted) {
        _copyEmailToClipboard();
      }
    }
  }

  void _copyEmailToClipboard() {
    Clipboard.setData(const ClipboardData(text: 'codninesx@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No mail app detected. Email 'codninesx@gmail.com' copied to clipboard!"),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter FAQs based on search query
    final filteredFaqs = _faqs.where((faq) {
      final question = faq['question']!.toLowerCase();
      final answer = faq['answer']!.toLowerCase();
      return question.contains(_searchQuery) || answer.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Help & Support",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Banner ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "How can we help you?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Search our FAQs or contact our support team directly.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Search Bar ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
                decoration: const InputDecoration(
                  hintText: "Search help topics...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Quick Contact Options ---
            const Text(
              "Contact Support",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.email_outlined,
                    iconColor: Colors.blueAccent,
                    title: "Email Us",
                    subtitle: "Get response in 24h",
                    onTap: _sendEmail,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.star_outline,
                    iconColor: Colors.amber.shade700,
                    title: "Play Store",
                    subtitle: "Rate & Feedback",
                    onTap: () => _launchUrl(
                      'https://play.google.com/store/apps/details?id=com.rxai.pcb',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Frequently Asked Questions (FAQs) ---
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            if (filteredFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "No matching help topics found.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredFaqs.length,
                itemBuilder: (context, index) {
                  final faq = filteredFaqs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        faq['question']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 30),

            // --- Footer Info ---
            Center(
              child: Column(
                children: [
                  Text(
                    "PCB Support Team",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Version 1.2.1",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}