import 'package:flutter/material.dart';
import 'bottom_nav.dart';
import 'QRScannerScreen.dart';

class OrderHistoryScreen extends StatelessWidget {
  final List<dynamic> orders;

  const OrderHistoryScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // Sort orders by startTime in descending order (latest first)
    final sortedOrders = [...orders]; // Clone the list to avoid mutating original
    sortedOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a['startTime'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['startTime'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA); // descending
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          title: const Text('Order History'),
          backgroundColor: const Color(0xFF692C5A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  QRScannerScreen(orderType: 'self')),
            ),
          ),
        ),

      body: sortedOrders.isEmpty
          ? const Center(child: Text("No orders available."))
          : ListView.builder(
        itemCount: sortedOrders.length,
        itemBuilder: (context, index) {
          final order = sortedOrders[index];
          final startTime = DateTime.tryParse(order['startTime'] ?? '') ?? DateTime.now();
          final formattedDate = "${_formatTime(startTime)}, ${_formatDate(startTime)}";

          return Container(
            color: index % 2 == 0 ? Colors.white : Colors.grey.shade100,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order ID: ${order['id']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Wash type: ${order['opertationType'] ?? 'N/A'}",
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "MachineId: ${order['machineId'] ?? 0}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Right section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order['orderStatus'] ?? 'Unknown',
                      style: TextStyle(
                        color: (order['orderStatus'] == 'completed') ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order['paymentStatus'] ?? '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNav(currentIndex: 4),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}";
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }
}
