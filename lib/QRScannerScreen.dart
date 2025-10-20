import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'WelcomeScreen.dart';
import 'HomeScreen.dart';
import 'bottom_nav.dart';
import 'dart:math';


import 'PaymentScreen.dart';

class QRScannerScreen extends StatefulWidget {
  final String orderType;

  const QRScannerScreen({super.key, required this.orderType});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isScanning = true;
  bool _loading = false;
  bool _connecting = false;



  final TextEditingController machineIdController = TextEditingController();
  final TextEditingController _couponCtrl = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  late Razorpay _razorpay;

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _bleScanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  int _payableInr = 0;
  Map<String, dynamic>? _lastMachine;
  Map<String, dynamic>? _lastWallet;
  int? _userId;
  int? _franchiseId;
  int? _orderId;

  int _discountInr = 0;
  bool _couponApplied = false;
  String _couponMsg = "";


  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _couponCtrl.dispose();
    machineIdController.dispose();
    _razorpay.clear();
    _bleScanSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  Future<void> _showPaymentSuccessDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Circle with tick animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 4),
                          color: Colors.green.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 60,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "Payment Successful",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF692C5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }




  void _onPaySuccess(PaymentSuccessResponse response) async {
    await _showPaymentSuccessDialog(context); // 🎉 Show animated success popup

    if (_lastMachine != null && _lastWallet != null) {
      _goToPayment(_lastMachine!, _lastWallet!);
    }
  }

  void _onPayError(PaymentFailureResponse response) {
    _showSnack('Payment failed: ${response.message}');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnack('External wallet selected: ${response.walletName}');
  }

  void _startRazorpayPayment(int amountInr) {
    const key = 'rzp_live_1FMhHw7pwKiV36';
    final options = {
      'key': key,
      'amount': amountInr * 100,
      'currency': 'INR',
      'name': 'Coin Laundry',
      'description': 'Machine usage charge',
      'theme': {'color': '#692C5A'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _showSnack('Error opening Razorpay: $e');
    }
  }

  void _onQRCodeScanned(String code) async {
    if (!isScanning) return;
    setState(() => isScanning = false);
    await fetchMachineAndWalletDetails(code);
    if (mounted) setState(() => isScanning = true);
  }

  void _onMachineIdSubmitted() async {
    final machineId = machineIdController.text.trim();
    if (machineId.isEmpty) {
      _showSnack("Please enter a valid Machine ID");
      return;
    }
    await fetchMachineAndWalletDetails(machineId);
  }

  Future<void> fetchMachineAndWalletDetails(String machineId) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      _showSnack("Authentication token missing");
      setState(() => _loading = false);
      return;
    }

    final headers = {'Authorization': 'Bearer $token'};
    try {
      final userResp = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/me'),
        headers: headers,
      );

      if (userResp.statusCode == 401) {
        await _handleTokenExpired();
        return;
      }

      if (userResp.statusCode != 200) {
        _showSnack("Failed to fetch user details");
        return;
      }

      _userId = json.decode(userResp.body)['id'];

      final machineUri = Uri.parse('https://api.coinlaundryindia.com/machines/$machineId');
      final walletUri = Uri.parse('https://api.coinlaundryindia.com/users/$_userId/wallets');

      final responses = await Future.wait([
        http.get(machineUri, headers: headers),
        http.get(walletUri, headers: headers),
      ]);

      if (responses[0].statusCode == 401 || responses[1].statusCode == 401) {
        await _handleTokenExpired();
        return;
      }

      if (responses[0].statusCode != 200) {
        _showSnack("Machine not found");
        return;
      }
      if (responses[1].statusCode != 200) {
        _showSnack("Failed to fetch wallet");
        return;
      }

      final machine = json.decode(responses[0].body);
      final wallet = json.decode(responses[1].body);

      final m = machine is List ? machine.first : machine;
      final w = wallet is List ? wallet.first : wallet;

      _franchiseId = m['franchiseId'] as int?;
      if (mounted) _showMachineWalletPopup(m, w);
    } catch (e) {
      _showSnack("Something went wrong");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired. Please log in again')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen(name: "")),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<int?> _createSelfOrder({
    required Map<String, dynamic> machine,
    required int walletDeduct,
    required int promoDeduct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final nowIso =
        DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());
    final endIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .format(DateTime.now().toUtc().add(const Duration(minutes: 30)));

    final body = json.encode({
      "amount": _payableInr,
      "btTrigger": false,
      "endTime": endIso,
      "feedback": "",
      "franchiseId": _franchiseId,
      "machineId": machine['id'],
      "opertationType": "self operated",
      "orderStatus": "ongoing",
      "paymentStatus": "paid",
      "promoCode": "",
      "promoDeductions": promoDeduct,
      "rewardAmount": 0,
      "startTime": nowIso,
      "transactionAmount": 0,
      "transactionId": "promocode",
      "userId": _userId,
      "walletDeductions": walletDeduct,
      "weight": 0
    });

    final uri =
        Uri.parse('https://api.coinlaundryindia.com/users/$_userId/orders');
    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 200) return null;

    final order = json.decode(resp.body);
    return order['order']['id'] as int?;
  }

  void _goToPayment(Map<String, dynamic> machine, Map<String, dynamic> wallet) async {
    if (_userId == null) {
      _showSnack('User info missing – please re‑scan.');
      return;
    }

    bool ok = false;

    if (widget.orderType == 'self') {
      final walletBal = (wallet['balance'] ?? 0).toInt();
      final charges = (machine['charges'] ?? 0).toInt();
      final walletDeduct = walletBal >= charges ? charges : walletBal;
      final promoDeduct = _couponCtrl.text.trim().isEmpty ? 0 : 1;

      _orderId = await _createSelfOrder(
        machine: machine,
        walletDeduct: walletDeduct,
        promoDeduct: promoDeduct,
      );
      ok = _orderId != null;
    }

    if (!ok) {
      _showSnack('Could not create order – try again.');
      return;
    }

    _startBLEScan(machine['id']);
  }

  Future<void> _markOrderTriggered(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      await _handleTokenExpired();
      return;
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final body = json.encode({'id': orderId, 'btTrigger': true});

    try {
      final response = await http.patch(
        Uri.parse('https://api.coinlaundryindia.com/users/$_userId/orders'),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        // ✅ Machine started, redirect to welcome screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );

        }
      } else if (response.statusCode == 401) {
        await _handleTokenExpired();
      } else {
        _showSnack("Failed to update order status");
      }
    } catch (e) {
      print('btTrigger patch failed: $e');
      _showSnack("Error updating order");
    }
  }


  Future<void> _startBLEScan(int machineId) async {
    if (_connecting) return;
    setState(() => _connecting = true);

    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    _bleScanSub?.cancel();
    _bleScanSub = _ble.scanForDevices(withServices: [], scanMode: ScanMode.lowLatency).listen(
      (device) async {
        if (device.name == 'Coin_Laundry_Machine_$machineId') {
          _bleScanSub?.cancel();
          await _connectToDevice(device);
        }
      },
      onError: (err) {
        _showSnack('BLE Scan failed: $err');
        setState(() => _connecting = false);
      },
    );
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _connectionSub?.cancel();
    _connectionSub = _ble.connectToDevice(id: device.id).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        _showSnack('BLE Connected.');
        await _discoverAndTrigger(device.id);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _showSnack('BLE Disconnected.');
        setState(() => _connecting = false);
      }
    }, onError: (e) {
      _showSnack('BLE Connection failed: $e');
      setState(() => _connecting = false);
    });
  }

  Future<void> _discoverAndTrigger(String deviceId) async {
    try {
      final serviceId = Uuid.parse('858d4d61-ec4f-433a-9022-02e7f3d66ff5');
      final charId = Uuid.parse('51fe2520-5bfb-496d-bbb5-b7326c634f41');

      final char = QualifiedCharacteristic(
        serviceId: serviceId,
        characteristicId: charId,
        deviceId: deviceId,
      );

      await _ble.writeCharacteristicWithResponse(
        char,
        value: utf8.encode("coin2020laundry"),
      );

      final result = await _ble.readCharacteristic(char);
      final value = utf8.decode(result);

      if (value == "coin2020laundry") {
        if (_orderId != null) {
          await _markOrderTriggered(_orderId!);
          _showSnack("Machine started & order updated.");

        }
      } else {
        _showSnack("BLE write/read mismatch.");
      }
    } catch (e) {
      _showSnack("BLE command failed: $e");
    } finally {
      setState(() => _connecting = false);
    }
  }



  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF692C5A)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMachineWalletPopup(Map<String, dynamic> machine, Map<String, dynamic> wallet) {
    final charges = (machine['charges'] ?? 0).toInt();
    final walletBal = (wallet['balance'] ?? 0).toInt();
    final walletDeduct = charges > walletBal ? walletBal : charges;
    _payableInr = charges - walletDeduct;

    final enoughCoins = _payableInr == 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool applyDisabled = false; // 🔹 local state for Apply button

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Order'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('Wallet Balance:', '$walletBal coin'),
                  _infoRow('Charges:', '$charges INR'),
                  _infoRow('Wallet Deductions:', '$walletDeduct coin'),
                  _infoRow('Coupon Discount:', _couponApplied ? '-$_discountInr INR' : '0 INR'),
                  const SizedBox(height: 8),

                  // 🧾 Coupon input + Apply button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          enabled: !applyDisabled, // 🔹 disable input if applied
                          decoration: const InputDecoration(
                            hintText: 'Enter Coupon Code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF692C5A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: applyDisabled
                            ? null // 🔹 disable after success
                            : () async {
                          final code = _couponCtrl.text.trim();
                          if (code.isEmpty) {
                            _showSnack("Please enter a coupon code");
                            return;
                          }
                          await _applyCoupon(code, setDialogState, () {
                            setDialogState(() => applyDisabled = true); // ✅ disable on success
                          });
                        },
                        child: const Text("Apply"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  if (_couponMsg.isNotEmpty)
                    Text(
                      _couponMsg,
                      style: TextStyle(
                        color: _couponApplied ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const SizedBox(height: 8),
                  _infoRow('Amount to Pay:', '$_payableInr INR'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF692C5A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _lastMachine = machine;
                    _lastWallet = wallet;
                    if (enoughCoins) {
                      _goToPayment(machine, wallet);
                    } else {
                      _startRazorpayPayment(_payableInr);
                    }
                  },
                  child: Text(enoughCoins ? 'Proceed with Deduction' : 'Proceed to Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }




  Future<void> _applyCoupon(
      String code,
      void Function(void Function()) setDialogState,
      VoidCallback onSuccessDisable,
      ) async {
    if (_franchiseId == null) {
      _showSnack("Franchise info missing");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      _showSnack("Please log in again");
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('https://api.coinlaundryindia.com/promocode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "coupon": code,
          "franchiseId": _franchiseId,
        }),
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final discount = (data['coins'] ?? 0).toInt();

        setDialogState(() {
          _discountInr = discount;
          _couponApplied = true;
          _payableInr = max(0, _payableInr - discount) as int;
          _couponMsg = "Coupon applied successfully (-₹$discount)";
        });

        onSuccessDisable(); // ✅ disable Apply button after success
      } else {
        setDialogState(() {
          _couponApplied = false;
          _couponMsg = "Invalid or expired coupon.";
        });
      }
    } catch (e) {
      setDialogState(() {
        _couponApplied = false;
        _couponMsg = "Failed to apply coupon. Try again.";
      });
    }
  }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,

      // 🧭 Add bottom navigation bar
      bottomNavigationBar: const BottomNav(currentIndex: 2),

      body: SafeArea(
        child: Stack(
          children: [
            // 📷 Camera Preview
            Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scanner view
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final val = capture.barcodes.first.rawValue;
                          if (val != null && isScanning) _onQRCodeScanned(val);
                        },
                      ),

                      // 🟩 Animated Scan Box
                      Center(
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: _AnimatedScannerBox(),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🧾 Instructions + Manual Entry
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "*Scan QR to start the order",
                        style: TextStyle(color: Color(0xFF692C5A), fontSize: 20),
                      ),
                      const Text("or"),
                      const Text(
                        "*Enter Machine ID to start the order",
                        style: TextStyle(color: Color(0xFF692C5A), fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: machineIdController,
                              decoration: InputDecoration(
                                hintText: 'Machine-Id',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF692C5A),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _onMachineIdSubmitted,
                            child: const Text("Go"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ⏳ Loader Overlay
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }


}

class _AnimatedScannerBox extends StatefulWidget {
  @override
  State<_AnimatedScannerBox> createState() => _AnimatedScannerBoxState();
}

class _AnimatedScannerBoxState extends State<_AnimatedScannerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // keeps moving up & down forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Black bordered box
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // Moving red line
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: _controller.value * 250,
              child: Container(
                width: 220,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

}

