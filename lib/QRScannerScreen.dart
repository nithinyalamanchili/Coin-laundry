// QRScannerScreen.dart — Optimized, validation injected (Option D)
import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

class QRScannerScreen extends StatefulWidget {
  final String orderType;




  QRScannerScreen({super.key, required this.orderType});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  BleStatus _bleStatus = BleStatus.unknown;
  StreamSubscription<BleStatus>? _bleStatusSub;
  bool isScanning = true;
  bool _loading = false;
  bool _connecting = false;
  String? _selectedOrderType; // values: "self" or "dropoff"

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

  // Debounce for scans
  Timer? _scanDebounce;

  @override
  void initState() {
    super.initState();
    _bleStatusSub = _ble.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _bleStatus = status;
        });
      }
    });
    // Show existing popup you had in file
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOrderTypeSelection();
    });

    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  Future<bool> _ensureBluetoothAndLocationOn() async {
    // 1. Check and request permissions if missing
    if (_bleStatus == BleStatus.unauthorized) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      // Give a brief moment for the BLE status stream to update
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (_bleStatus == BleStatus.ready) {
      return true;
    }

    // 2. Determine the specific issue if still not ready
    String title = "Hardware Required";
    String content = "Please ensure Bluetooth and Location (GPS) are turned ON to connect to the machine.";
    String actionLabel = "Retry";

    if (_bleStatus == BleStatus.poweredOff) {
      title = "Bluetooth Required";
      content = "Bluetooth is OFF. Please enable Bluetooth to start the machine.";
    } else if (_bleStatus == BleStatus.locationServicesDisabled) {
      title = "Location Required";
      content = "Location services (GPS) are OFF. Android requires Location to be ON for Bluetooth scanning.";
    } else if (_bleStatus == BleStatus.unauthorized) {
      title = "Permission Required";
      content = "Bluetooth or Location permissions were denied. Please grant them in App Settings.";
      actionLabel = "Open Settings";
    }

    bool? result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (_bleStatus == BleStatus.unauthorized) {
                await openAppSettings();
              }
              Navigator.pop(context, true);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (result == true) {
      // If user clicked Retry/Open Settings, check again recursively
      return await _ensureBluetoothAndLocationOn();
    }

    return _bleStatus == BleStatus.ready;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _couponCtrl.dispose();
    machineIdController.dispose();
    _razorpay.clear();
    _bleScanSub?.cancel();
    _connectionSub?.cancel();
    _scanDebounce?.cancel();
    _bleStatusSub?.cancel();
    super.dispose();
  }

  // ---------------------------
  // Order Type Popup (kept as-is)
  // ---------------------------
  void _showOrderTypeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Choose Order Type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrderTypeButton("Self Operated", "self"),
              const SizedBox(height: 12),
              _buildOrderTypeButton("Drop-off", "dropoff"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderTypeButton(String title, String type) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF692C5A),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
      ),
      onPressed: () {
        setState(() => _selectedOrderType = type);
        Navigator.of(context).pop();
      },
      child: Text(title),
    );
  }

  // ---------------------------
  // Razorpay callbacks
  // ---------------------------
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
                        child: const Center(
                          child: Icon(Icons.check, color: Colors.green, size: 60),
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
    await _showPaymentSuccessDialog(context);
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
      'payment_capture': 1,
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      _showSnack('Error opening Razorpay: $e');
    }
  }

  // ---------------------------
  // QR scan handler (debounced)
  // ---------------------------
  void _onQRCodeScanned(String code) async {
    if (!isScanning) return;

    // require user to choose order type
    if (_selectedOrderType == null) {
      _showSnack("Please select order type");
      _showOrderTypeSelection();
      return;
    }

    // debounce to avoid multiple rapid calls
    _scanDebounce?.cancel();
    _scanDebounce = Timer(const Duration(milliseconds: 500), () {
      _handleScannedCode(code);
    });
  }

  Future<void> _handleScannedCode(String code) async {
    if (!mounted) return;
    setState(() => isScanning = false);

    await fetchMachineAndWalletDetails(code);

    if (mounted) setState(() => isScanning = true);
  }

  // ---------------------------
  // Manual machine ID submission
  // ---------------------------
  void _onMachineIdSubmitted() async {
    if (_selectedOrderType == null) {
      _showSnack("Please select order type first");
      _showOrderTypeSelection();
      return;
    }

    final machineId = machineIdController.text.trim();
    if (machineId.isEmpty) {
      _showSnack("Please enter a valid Machine ID");
      return;
    }
    setState(() => _loading = true);
    await fetchMachineAndWalletDetails(machineId);
    if (mounted) setState(() => _loading = false);
  }

  // ---------------------------
  // Fetch machine + wallet and VALIDATE against _selectedOrderType
  // ---------------------------
  Future<void> fetchMachineAndWalletDetails(String machineId) async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnack("Authentication token missing");
      setState(() => _loading = false);
      return;
    }

    try {
      final headers = {"Authorization": "Bearer $token"};

      // fetch user
      final userResp = await http.get(
        Uri.parse("https://api.coinlaundryindia.com/users/me"),
        headers: headers,
      );

      if (userResp.statusCode == 401) {
        await _handleTokenExpired();
        return;
      }

      final userJson = json.decode(userResp.body);
      _userId = userJson['id'];

      // fetch machine and wallet in parallel
      final machineFuture = http.get(
        Uri.parse("https://api.coinlaundryindia.com/machines/$machineId"),
        headers: headers,
      );
      final walletFuture = http.get(
        Uri.parse("https://api.coinlaundryindia.com/users/$_userId/wallets"),
        headers: headers,
      );

      final responses = await Future.wait([machineFuture, walletFuture]);
      final machineResp = responses[0];
      final walletResp = responses[1];

      if (machineResp.statusCode != 200) {
        _showSnack("Machine not found");
        return;
      }
      if (walletResp.statusCode != 200) {
        _showSnack("Failed to fetch wallet");
        return;
      }

      final machineJson = json.decode(machineResp.body);
      final walletJson = json.decode(walletResp.body);

      final m = machineJson is List ? machineJson.first : machineJson;
      final w = walletJson is List ? walletJson.first : walletJson;

      _franchiseId = m['franchiseId'];

      // Validate machine operation type matches user selection
      if (!matchesSelection(m['operationType']?.toString() ?? "", _selectedOrderType!)) {
        await _showMismatchDialog(m, _selectedOrderType!);
        return;
      }

      if (mounted) _showMachineWalletPopup(m, w);
    } catch (e) {
      _showSnack("Something went wrong");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // tolerant matching: handles "drop offf", spaces, hyphens etc.
  bool matchesSelection(String machineOp, String selected) {
    final m = machineOp.toLowerCase();
    if (selected == "self") {
      return m.contains("self");
    } else if (selected == "dropoff" || selected == "drop-off") {
      return m.contains("drop");
    }
    // fallback: try normalized equality
    String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');
    return normalize(m) == normalize(selected);
  }

  Future<void> _showMismatchDialog(Map<String, dynamic> machine, String selected) async {
    final op = machine['operationType'] ?? 'Unknown';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invalid Selection"),
        content: Text(
          "The machine is configured as '$op'.\nYou selected '${selected == 'self' ? 'Self Operated' : 'Drop-off'}'.\nPlease choose the correct option.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // reopen selection for convenience
              _showOrderTypeSelection();
            },
            child: const Text("Change Selection"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Token expired
  // ---------------------------
  Future<void> _handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Session expired. Please login again")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen(name: "")),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------
  // Create self order
  // ---------------------------
  Future<int?> _createSelfOrder({
    required Map<String, dynamic> machine,
    required int walletDeduct,
    required int promoDeduct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return null;

    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    final nowIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .format(DateTime.now().toUtc());

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
      "weight": 0,
    });

    final resp = await http.post(
      Uri.parse("https://api.coinlaundryindia.com/users/$_userId/orders"),
      headers: headers,
      body: body,
    );

    if (resp.statusCode != 200) return null;

    final jsonResp = json.decode(resp.body);
    return jsonResp['order']?['id'];
  }


  Future<int?> _createDropoffOrder({
    required Map<String, dynamic> machine,
    required int walletDeduct,
    required int promoDeduct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return null;

    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    final nowIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .format(DateTime.now().toUtc());

    final endIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .format(DateTime.now().toUtc().add(const Duration(minutes: 30)));

    final body = json.encode({
      "amount": _payableInr,
      "btTrigger": false,
      "endTime": endIso,
      "feedback": "",
      "franchiseId": _franchiseId,
      "machineId": machine['id'],
      "opertationType": "drop off",
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
      "weight": 0,
    });

    final resp = await http.post(
      Uri.parse("https://api.coinlaundryindia.com/users/$_userId/orders"),
      headers: headers,
      body: body,
    );
    if (resp.statusCode != 200) return null;

    final jsonResp = json.decode(resp.body);
    print("@@@@@@@@@@@@ $jsonResp");
    return jsonResp['order']?['id'];
  }

  // ---------------------------
  // Payment + BLE trigger flow
  // ---------------------------
  void _goToPayment(Map<String, dynamic> machine, Map<String, dynamic> wallet) async {
    if (_userId == null) {
      _showSnack("User info missing — please re-scan.");
      return;
    }

    bool ok = false;

    if (_selectedOrderType == "self") {

      /// CHECK BLUETOOTH & LOCATION BEFORE ORDER CREATION
      final hardwareReady = await _ensureBluetoothAndLocationOn();

      if (!hardwareReady) {
        return; // Message already shown in dialog
      }

      final walletBal = (wallet['balance'] ?? 0).toInt();
      final charges = (machine['charges'] ?? 0).toInt();

      final walletDeduct = walletBal >= charges ? charges : walletBal;
      final promoDeduct = _couponApplied ? _discountInr : 0;

      _orderId = await _createSelfOrder(
        machine: machine,
        walletDeduct: walletDeduct,
        promoDeduct: promoDeduct,
      );

      ok = _orderId != null;
    }else if (_selectedOrderType == "dropoff") {
      // Drop-off flow (existing)
      final walletBal = (wallet['balance'] ?? 0).toInt();
      final charges = (machine['charges'] ?? 0).toInt();

      final walletDeduct = walletBal >= charges ? charges : walletBal;
      final promoDeduct = _couponApplied ? _discountInr : 0;

      _orderId = await _createDropoffOrder(
        machine: machine,
        walletDeduct: walletDeduct,
        promoDeduct: promoDeduct,
      );

      ok = _orderId != null;
    }

    if (!ok) {
      _showSnack("Could not create order. Try again.");
      return;
    }

    // Only attempt BLE for self-operated machines
    if (_selectedOrderType == "self") {

      final hardwareReady = await _ensureBluetoothAndLocationOn();

      if (!hardwareReady) {
        return;
      }

      _startBLEScan(machine['id']);


    } else {
      // For drop-off proceed to appropriate screen (keeps existing behaviour)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _startBLEScan(int machineId) async {
    if (_connecting) return;

    setState(() => _connecting = true);

    final perms = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (perms[Permission.location] != PermissionStatus.granted ||
        perms[Permission.bluetoothScan] != PermissionStatus.granted ||
        perms[Permission.bluetoothConnect] != PermissionStatus.granted) {
      _showSnack("Hardware permissions not granted");
      setState(() => _connecting = false);
      return;
    }

    bool deviceFound = false;

    _bleScanSub?.cancel();

    _bleScanSub = _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen((device) async {

      // Flexible name matching to handle variations in BLE reporting
      if (device.name.trim().contains("Coin_Laundry_Machine_$machineId")) {
        deviceFound = true;

        _bleScanSub?.cancel();

        await _connectToDevice(device);
      }

    }, onError: (e) {
      _showSnack("BLE Scan failed");
      setState(() => _connecting = false);
    });

    /// BLE SCAN TIMEOUT (Increased to 10s for better compatibility)
    Future.delayed(const Duration(seconds: 10), () {
      if (!deviceFound) {
        _bleScanSub?.cancel();

        if (mounted) {
          setState(() => _connecting = false);

          _showSnack("Machine not detected. Please ensure you are near the machine.");

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _connectionSub?.cancel();

    _connectionSub = _ble.connectToDevice(id: device.id).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        _showSnack("BLE Connected.");
        await _discoverAndTrigger(device.id);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _showSnack("BLE Disconnected.");
        setState(() => _connecting = false);
      }
    }, onError: (e) {
      _showSnack("BLE Connection failed: $e");
      setState(() => _connecting = false);
    });
  }

  Future<void> _discoverAndTrigger(String deviceId) async {
    try {
      final serviceId = Uuid.parse("858d4d61-ec4f-433a-9022-02e7f3d66ff5");
      final charId = Uuid.parse("51fe2520-5bfb-496d-bbb5-b7326c634f41");

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

  Future<void> _markOrderTriggered(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      await _handleTokenExpired();
      return;
    }

    final resp = await http.patch(
      Uri.parse("https://api.coinlaundryindia.com/users/$_userId/orders"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"id": orderId, "btTrigger": true}),
    );

    if (resp.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showSnack("Failed to update order status");
    }
  }

  // ---------------------------
  // Machine + wallet confirmation dialog
  // ---------------------------
  void _showMachineWalletPopup(Map<String, dynamic> machine, Map<String, dynamic> wallet) {
    final charges = (machine['charges'] ?? 0).toInt();
    final walletBal = (wallet['balance'] ?? 0).toInt();

    final walletDeduct = walletBal >= charges ? charges : walletBal;
    _payableInr = charges - walletDeduct;
    final enoughCoins = _payableInr == 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool applyDisabled = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Confirm Order"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow("Wallet Balance:", "$walletBal coin"),
                  _infoRow("Charges:", "$charges INR"),
                  _infoRow("Wallet Deductions:", "$walletDeduct coin"),
                  _infoRow("Coupon Discount:", _couponApplied ? "-$_discountInr INR" : "0 INR"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          enabled: !applyDisabled,
                          decoration: const InputDecoration(
                            hintText: "Enter Coupon Code",
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
                            ? null
                            : () async {
                          final code = _couponCtrl.text.trim();
                          if (code.isEmpty) {
                            _showSnack("Enter coupon code");
                            return;
                          }

                          await _applyCoupon(code, setDialogState, () {
                            setDialogState(() => applyDisabled = true);
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
                  _infoRow("Amount to Pay:", "$_payableInr INR"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("CANCEL"),
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
                  child: Text(enoughCoins ? "Proceed with Deduction" : "Proceed to Payment"),
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
    final token = prefs.getString("auth_token");

    if (token == null) {
      _showSnack("Please log in again");
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse("https://api.coinlaundryindia.com/promocode"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({"coupon": code, "franchiseId": _franchiseId}),
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final discount = (data['coins'] ?? 0).toInt();

        setDialogState(() {
          _couponApplied = true;
          _discountInr = discount;
          _payableInr = max(0, _payableInr - discount).toInt();
          _couponMsg = "Coupon applied successfully (-₹$discount)";
        });

        onSuccessDisable();
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF692C5A))),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------
  // UI Build
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final val = capture.barcodes.first.rawValue;
                          if (val != null && isScanning) {
                            _onQRCodeScanned(val);
                          }
                        },
                      ),
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
                                hintText: "Machine-ID",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            if (_loading || _connecting)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------
// Animated scanner box (kept and slightly simplified)
// ---------------------------
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
    )..repeat(reverse: true);
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
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
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
