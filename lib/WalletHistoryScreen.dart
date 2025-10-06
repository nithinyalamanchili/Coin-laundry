import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WalletHistoryScreen extends StatefulWidget {
  final int userId;

  const WalletHistoryScreen({super.key, required this.userId});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<dynamic> walletHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchWalletHistory();
  }

  Future<void> fetchWalletHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('https://api.coinlaundryindia.com/users/${widget.userId}/wallet-histories'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        walletHistory = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print("Failed to load wallet history");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text("Wallet History"),
        backgroundColor: const Color(0xFF692C5A),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: walletHistory.length,
        itemBuilder: (context, index) {
          final item = walletHistory[index];
          final transactionType = item['outletName'] ?? '';
          final createdDate = DateTime.parse(item['createdDate']);
          final washId = item['orderId'] ?? '';
          final coins = item['coins'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transactionType.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_formatTime(createdDate)}\nWash ID-$washId",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  "$coins INR",
                  style: TextStyle(
                    color: _isCredit(transactionType) ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )

              ],
            ),
          );
        },
      ),
    );
  }
  bool _isCredit(String type) {
    final t = type.toLowerCase();
    return t == 'refund' || t == 'credit';
  }

  String _formatTime(DateTime dateTime) {
    return "${_formatHour(dateTime)}\n${_formatDate(dateTime)}";
  }

  String _formatHour(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}";
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
