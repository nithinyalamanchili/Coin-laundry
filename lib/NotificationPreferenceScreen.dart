import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationPreferenceScreen extends StatefulWidget {
  const NotificationPreferenceScreen({super.key});

  @override
  State<NotificationPreferenceScreen> createState() =>
      _NotificationPreferenceScreenState();
}

class _NotificationPreferenceScreenState
    extends State<NotificationPreferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool pushOffers = true;
  bool smsOffers = false;
  bool emailOffers = false;

  String mobile = "";
  String email = "";
  int coins = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("Token not found");

      // Fetch user info
      final userResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode != 200) {
        throw Exception("User fetch failed: ${userResponse.body}");
      }

      final userData = json.decode(userResponse.body);
      final userId = userData['id'];

      String userMobile = userData['mobile'] ?? '';
      String userEmail = userData['email'] ?? '';

      // Fetch wallet info
      final walletResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/$userId/wallets'),
        headers: {'Authorization': 'Bearer $token'},
      );

      int walletBalance = 0;
      if (walletResponse.statusCode == 200) {
        final walletList = json.decode(walletResponse.body);
        if (walletList is List && walletList.isNotEmpty) {
          walletBalance = (walletList[0]['balance'] ?? 0).toInt();
        }
      }

      setState(() {
        mobile = userMobile;
        email = userEmail;
        coins = walletBalance;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load profile data")),
      );
    }
  }

  Widget _buildPreferenceTab(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Offers Updates",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF692C5A),
          ),
        ],
      ),
    );
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
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
        children: [
        const CircleAvatar(
        radius: 40,
        backgroundColor: Colors.white,
        child: Icon(Icons.person,
            color: Color(0xFF692C5A), size: 50),
      ),
      const SizedBox(height: 8),
      Text(
        mobile.isNotEmpty ? mobile : "-",
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      Text(
        email.isNotEmpty ? email : "-",
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      const SizedBox(height: 20),

      // Coins Card
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF692C5A)),
              ),
            ),
            Text(
              "$coins",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF692C5A)),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Text(
          "*You can use coins at the time of payment",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      const SizedBox(height: 20),

      // White Section with Tabs
      Expanded(
      child: Container(
      decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24)),
    ),
    child: Column(
    children: [
    TabBar(
    controller: _tabController,
    indicatorColor: const Color(0xFF692C5A),
    labelColor: const Color(0xFF692C5A),
    unselectedLabelColor: Colors.grey,
    tabs: const [
    Tab(text: "Push"),
    Tab(text: "SMS"),
    Tab(text: "Email"),
    ],
    ),
    Expanded(
    child: TabBarView(
    controller: _tabController,
    children: [
    _buildPreferenceTab("Offers Updates", pushOffers,
    (v) => setState(() => pushOffers = v)),
    _buildPreferenceTab("Offers Updates", smsOffers,
    (v) => setState(() => smsOffers = v)),
    ],
    ),
    ),
    ],
    ),
      ),
      ),
        ],
      ),
    );
  }
}