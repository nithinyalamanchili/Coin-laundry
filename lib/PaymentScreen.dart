import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  final Map<String, dynamic> machine;
  final Map<String, dynamic> wallet;
  final String orderType;

  const PaymentScreen({
    super.key,
    required this.machine,
    required this.wallet,
    required this.orderType,
  });

  @override
  Widget build(BuildContext context) {
    final machineName = machine['name'] ?? 'N/A';
    final machinePrice = machine['price'] ?? '0';
    final walletBalance = wallet['balance'] ?? '0';

    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Payment")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Machine: $machineName", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text("Price: ₹$machinePrice", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text("Your Wallet Balance: ₹$walletBalance", style: const TextStyle(fontSize: 18, color: Colors.green)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // TODO: Trigger payment logic
              },
              child: const Text("Proceed to Pay"),
            )
          ],
        ),
      ),
    );
  }
}
