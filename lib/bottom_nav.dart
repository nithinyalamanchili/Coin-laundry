import 'package:flutter/material.dart';
import 'HomeScreen.dart';
import 'AllOrdersScreen.dart';
import 'QRScannerScreen.dart';
import 'WalletHistoryScreen.dart';
import 'OrderHistoryScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  Future<void> handleTokenExpired(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: (index) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (index == 1 && token != null) {
          final response = await http.get(
            Uri.parse('https://api.coinlaundryindia.com/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final id = data['id'];
            final orderResponse = await http.get(
              Uri.parse('https://api.coinlaundryindia.com/users/$id/orders'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (orderResponse.statusCode == 200) {
              final orderData = json.decode(orderResponse.body);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AllOrdersScreen(orders: orderData)),
              );
            } else if (orderResponse.statusCode == 401) {
              await handleTokenExpired(context);
            }
          }
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const QRScannerScreen(orderType: 'self')),
          );
        } else if (index == 3 && token != null) {
          final response = await http.get(
            Uri.parse('https://api.coinlaundryindia.com/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final id = data['id'];
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => WalletHistoryScreen(userId: id)),
            );
          }
        } else if (index == 4 && token != null) {
          final response = await http.get(
            Uri.parse('https://api.coinlaundryindia.com/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final id = data['id'];
            final orderResponse = await http.get(
              Uri.parse('https://api.coinlaundryindia.com/users/$id/orders'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (orderResponse.statusCode == 200) {
              final orderData = json.decode(orderResponse.body);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => OrderHistoryScreen(orders: orderData)),
              );
            }
          }
        }
      },
      selectedItemColor: const Color(0xFF692C5A),
      unselectedItemColor: Colors.black,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.article), label: ''),
      ],
    );
  }
}
