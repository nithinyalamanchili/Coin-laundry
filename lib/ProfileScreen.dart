import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'main.dart'; // replace with your login screen
import 'AccountSettingsScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = '';
  String mobile = '';
  String email = '';
  int coins = 0;
  bool isLoading = true;

  final String playStoreUrl = "https://play.google.com/store/apps/details?id=com.example.coinlaundry";

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception("Token not found");

      final userResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode != 200) throw Exception("User fetch failed");

      final userData = json.decode(userResponse.body);
      final userId = userData['id'];

      setState(() {
        name = "${userData['firstName']} ${userData['lastName']}";
        mobile = userData['mobile'] ?? '';
        email = userData['email'] ?? '';
      });

      final walletResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/$userId/wallets'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (walletResponse.statusCode != 200) throw Exception("Wallet fetch failed");

      final walletList = json.decode(walletResponse.body);
      if (walletList is List && walletList.isNotEmpty) {
        setState(() {
          coins = walletList[0]['balance'] ?? 0;
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw Exception('Could not launch $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF692C5A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF692C5A),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF692C5A), size: 50),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mobile, style: const TextStyle(color: Colors.white)),
                      Text(email, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Total Earned coins",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF692C5A)),
                  ),
                ),
                Text("$coins", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("*You can use coins at the time of payment", style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileOption(
                    icon: Icons.settings,
                    label: "Account settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                      );
                    },
                  ),

                  const _ProfileOption(icon: Icons.notifications_off, label: "Notification preference"),
                  _ProfileOption(
                    icon: Icons.phone,
                    label: "Support",
                    onTap: () => _makePhoneCall("8880767777"),
                  ),
                  _ProfileOption(
                    icon: Icons.privacy_tip,
                    label: "Privacy Policy",
                    onTap: () => _launchUrl("https://api.coinlaundryindia.com/files/privacy-policy.pdf"),
                  ),
                  _ProfileOption(
                    icon: Icons.feedback,
                    label: "Feedback",
                    onTap: () => _launchUrl("https://play.google.com/store/apps/details?id=com.example.coinlaundry"),
                  ),
                  _ProfileOption(
                    icon: Icons.description,
                    label: "Legal",
                    onTap: () => _launchUrl("https://api.coinlaundryindia.com/files/legal-information-disclaimer.pdf"),
                  ),
                  _ProfileOption(
                    icon: Icons.share,
                    label: "Share",
                    onTap: () => Share.share("Check out WashBy App on Play Store:\n$playStoreUrl"),
                  ),
                  _ProfileOption(
                    icon: Icons.delete,
                    label: "Delete Account",
                    onTap: () {
                      // TODO: Implement delete account
                    },
                  ),
                  _ProfileOption(
                    icon: Icons.logout,
                    label: "Logout",
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileOption({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[800]),
      title: Text(label),
      onTap: onTap,
    );
  }
}
