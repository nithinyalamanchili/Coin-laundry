import 'package:flutter/material.dart';

class PaymentStatusScreen extends StatelessWidget {
  final String orderId;
  final String orderstatus;
  final String machinename;
  final String paymentStatus;
  final int amount;
  final String dateTime;

  const PaymentStatusScreen({
    super.key,
    required this.orderId,
    required this.orderstatus,
    required this.paymentStatus,
    required this.amount,
    required this.dateTime,
    required this.machinename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomAppBar(
        color: Colors.black87,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Icon(Icons.home, color: Colors.grey),
              Icon(Icons.card_giftcard, color: Colors.grey),
              CircleAvatar(
                backgroundColor: Color(0xFF692C5A),
                child: Icon(Icons.qr_code, color: Colors.white),
              ),
              Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
              Icon(Icons.description_outlined, color: Colors.grey),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                "Promising\nQuality",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black12,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "10 years Industry trust",
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Wash type: self operated", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Order ID: $orderId", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Machine Name: $machinename"),
                          const SizedBox(height: 4),
                          Text(dateTime),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child:  Center(
                        child: Text(
                          "Order Status : $orderstatus",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

            ],
          ),
        ),
      ),
    );
  }
}
