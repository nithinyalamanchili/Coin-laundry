import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'bottom_nav.dart';

class AllOrdersScreen extends StatelessWidget {
  final List<dynamic> orders;

  const AllOrdersScreen({super.key, required this.orders});

  String formatDate(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return DateFormat('hh:mm a, dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    print("🧾 All Orders: ${orders.toString()}");
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF692C5A),
        title: const Text('Rewarded Coins'),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF692C5A),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rewarded Coins", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                const Text("0", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                        child: const Text("Rewards"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                        child: const Text("Recharge"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You Have Earned 0 coins", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("*You can use coins at the time of payment", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:Container(
              color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final reward = order['rewardAmount'] ?? 0;
                final machineName = order['franchise']?['name'] ?? 'Unknown';
                final orderId = order['id'];
                final amount = order['amount'] ?? 0;

                return Container(
                color: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline dot and line
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index != orders.length - 1)
                          Container(
                            width: 2,
                            height: 70,
                            color: Colors.green,
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Order info
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              machineName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(order['startTime']),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Wash ID-$orderId",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),

                            // 🎉 Reward chip (only if reward > 0)
                            if (reward > 0)
                              Container(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Kudos $reward coins added to wallet",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Amount
                    const SizedBox(width: 8),
                    Text(
                      "$amount INR",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                );
              },

            ),
    ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
