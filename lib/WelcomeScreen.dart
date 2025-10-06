import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'HomeScreen.dart';

class WelcomeScreen extends StatefulWidget {
  final String name;

  const WelcomeScreen({super.key, required this.name});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String firstName = "";
  int coins = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    fetchWalletDetails();
  }

  Future<void> fetchUserDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        await handleTokenExpired();
        return;
      }

      // Fetch user details
      final response = await http.get(
        Uri.parse("https://api.coinlaundryindia.com/users/me"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await handleTokenExpired();
        return;
      }

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);

        print(userData);
        setState(() {
          firstName = userData['firstName'] ?? '';
          coins = userData['wallet_balance'] ?? 0;
          isLoading = false;
        });
      } else {
        print('Failed to fetch user: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }



  Future<void> fetchWalletDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        await handleTokenExpired();
        return;
      }

      // Fetch user details to get user ID
      final userResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 401) {
        await handleTokenExpired();
        return;
      } else if (userResponse.statusCode != 200) {
        print("Failed to fetch user: ${userResponse.body}");
        return;
      }

      final userData = json.decode(userResponse.body);
      final userId = userData['id'];

      // Fetch wallet using userId
      final walletResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/$userId/wallets'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (walletResponse.statusCode == 401) {
        await handleTokenExpired();
        return;
      }

      if (walletResponse.statusCode == 200) {
        final List<dynamic> walletList = json.decode(walletResponse.body);
        if (walletList.isNotEmpty) {
          final wallet = walletList[0];
          setState(() {
            coins = wallet['balance'] ?? 0;
            isLoading = false;
          });
        } else {
          print('No wallet found');
        }
      } else {
        print("Failed to fetch wallet: ${walletResponse.body}");
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF692C5A),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hey $firstName", style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 10),
              const Text("Welcome to,", style: TextStyle(color: Colors.white, fontSize: 30,fontWeight: FontWeight.bold)),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: "Wash ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: "by Coin Laundromat",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

              const SizedBox(height: 8),
              const Text(
                "Unlocking new deals every day, choose the best deal you have today",
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),
              Row(
                children: const [
                  Icon(Icons.circle_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text("Get 0% reward on your payments", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.circle_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You have $coins coins in your wallet. Use them at the time of billing",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),

              const Spacer(),


              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF692C5A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: const Text("Start",style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
