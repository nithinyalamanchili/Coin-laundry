import 'package:flutter/material.dart';

class PaymentStatusScreen extends StatelessWidget {
  final String orderId;
  final String paymentStatus;
  final int amount;
  final String dateTime;

  const PaymentStatusScreen({
    super.key,
    required this.orderId,
    required this.paymentStatus,
    required this.amount,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: const Color(0xFF692C5A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID: $orderId", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Payment Status: $paymentStatus", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text("Amount: ₹$amount", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text("Date & Time: $dateTime", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
