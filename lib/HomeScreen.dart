import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ProfileScreen.dart';
import 'PaymentStatusScreen.dart';
import 'OrderHistoryScreen.dart';
import 'WalletHistoryScreen.dart';
import 'AllOrdersScreen.dart';
import 'QRScannerScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName = '';
  int? userId;
  int coinBalance = 0;
  bool isLoading = true;
  List<dynamic> orders = [];
  int _selectedIndex = 0;
  String _orderType = "self"; // self or drop
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _startCountdownUpdater();
  }

  void _startCountdownUpdater() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchUserData() async {


    print("::::::::::::::::::: fetch User data started:::::::::::::");


    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print("::::::::::::::::::: $token :::::::::::::");


      if (token == null) throw Exception("Token not found");

      final response = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print("**********************");
        print(data['coinBalance']);
        print("**********************");
        userId = data['id'];
        userName = "${data['firstName']} ${data['lastName']}";
        coinBalance = data['coinBalance'] ?? 0;
      } else if (response.statusCode == 401) {
        await handleTokenExpired();
      } else {
        userName = "Guest";
      }


      final walletResponse = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/$userId/wallets'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("**********************");
      print(walletResponse);
      print("**********************");

      if (walletResponse.statusCode == 200) {
        final List<dynamic> walletList = json.decode(walletResponse.body);
        if (walletList.isNotEmpty) {
          final wallet = walletList[0];
          setState(() {
            coinBalance = wallet['balance'] ?? 0;
            isLoading = false;
          });
          await fetchOrders(userId!, token, _orderType);
        } else {
          print('No wallet found');
        }
      } else {
        print("Failed to fetch wallet: ${walletResponse.body}");
      }
    } catch (e) {
      userName = "Guest";
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchOrders(int id, String token, String type) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coinlaundryindia.com/users/$id/orders'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Filter orders based on type
        List<dynamic> filteredOrders = data.where((order) {
          final operationType = order['opertationType'] ?? order['operationType'] ?? '';
          if (type.toLowerCase() == 'self') return operationType.toLowerCase() == 'self operated';
          if (type.toLowerCase() == 'drop') return operationType.toLowerCase() == 'drop off';
          return true;
        }).toList();

        setState(() {
          orders = List.from(filteredOrders.reversed);
        });
      } else if (response.statusCode == 401) {
        await handleTokenExpired();
      }
    } catch (e) {
      print("Error fetching orders: $e");
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

  String getRemainingTime(String endTime) {
    if (endTime.isEmpty) return '00:00:00';
    final end = DateTime.tryParse(endTime)?.toLocal();
    if (end == null) return '00:00:00';

    final now = DateTime.now();
    final diff = end.difference(now);
    if (diff.isNegative) return '00:00:00';

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_selectedIndex == 4
            ? OrderHistoryScreen(orders: orders)
            : _buildHomeBody()),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (index == 1 && userId != null && token != null) {
            final response = await http.get(
              Uri.parse('https://api.coinlaundryindia.com/users/$userId/orders'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AllOrdersScreen(orders: data)),
              );
            } else if (response.statusCode == 401) {
              await handleTokenExpired();
            }
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  QRScannerScreen(orderType: 'self')),
            );
          } else if (index == 3 && userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => WalletHistoryScreen(userId: userId!)),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
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
      ),
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF692C4A),
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hello, ${userName?.isNotEmpty == true ? userName : 'User'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Text("Welcome to Coin Laundry", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF692C5A)),
                const SizedBox(width: 10),
                const Text("Coin balance", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 20)),
                const Spacer(),
                Text("$coinBalance", style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/banner.jpg', fit: BoxFit.cover, height: 180, width: double.infinity),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _orderType = "self";
                      isLoading = true;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');
                    if (userId != null && token != null) {
                      await fetchOrders(userId!, token, "self");
                    }
                    setState(() => isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orderType == "self" ? const Color(0xFF692C5A) : Colors.white,
                    foregroundColor: _orderType == "self" ? Colors.white : Colors.black,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Self Operated",style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _orderType = "drop";
                      isLoading = true;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');
                    if (userId != null && token != null) {
                      await fetchOrders(userId!, token, "drop");
                    }
                    setState(() => isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orderType == "drop" ? const Color(0xFF692C5A) : Colors.white,
                    foregroundColor: _orderType == "drop" ? Colors.white : Colors.black,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Drop Off",style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...orders.map((order) => _buildWashCard(order)).toList(),
        ],
      ),
    );
  }

  Widget _buildWashCard(dynamic order) {
    
    print(order);
    
    
    String operation = order['opertationType'] ?? order['operationType'] ??
        'Unknown';
    String orderId = order['id']?.toString() ?? '';
    String paymentStatus = order['paymentStatus'] ?? 'N/A';
    String orderStatus = order['orderStatus'] ?? 'N/A';
    int amount = order['amount'] ?? 0;
    String startTime = order['startTime'] ?? '';
    String endTime = order['endTime'] ?? '';
    bool btTrigger = order['btTrigger'] ?? false;
    String machinename = order['franchise']?['name'] ?? 'Unknown';

    DateTime? end = DateTime.tryParse(endTime)?.toLocal();
    Duration timeLeft = end != null ? end.difference(DateTime.now()) : Duration
        .zero;


    if (operation == "self operated"){
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    text: "You choose ",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                    children: [
                      TextSpan(
                        text: operation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  btTrigger ? orderStatus : "Not triggered",
                  style: TextStyle(
                    color: btTrigger ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Text(
              "Order ID: $orderId",
              style: const TextStyle(
                color: Color(0xFF692C5A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text("Estimated time for completing wash"),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Color(0xFF692C5A), size: 60),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [


                      !btTrigger
                          ? const Text(
                        "--:--:--",
                        style: TextStyle(
                          fontSize: 40,
                          color: Color(0xFF692C5A),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : timeLeft.isNegative
                          ? const Text(
                        "00:00:00",
                        style: TextStyle(
                          fontSize: 40,
                          color: Color(0xFF692C5A),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : timeLeft.inSeconds < 60
                          ? BlinkingCountdown(timeLeft: timeLeft)
                          : Text(
                        getRemainingTime(endTime),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Color(0xFF692C5A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Time remaining to complete wash",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF692C5A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PaymentStatusScreen(
                                  orderId: orderId,
                                  machinename:machinename,
                                  orderstatus:orderStatus,
                                  paymentStatus: paymentStatus,
                                  amount: amount,
                                  dateTime: startTime,
                                ),
                          ),
                        );
                      },
                      child: const Text('Payment Status', style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 0),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF692C5A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PaymentStatusScreen(
                                  orderId: orderId,
                                  machinename:machinename,
                                  orderstatus:orderStatus,
                                  paymentStatus: paymentStatus,
                                  amount: amount,
                                  dateTime: startTime,
                                ),
                          ),
                        );
                      },
                      child: const Text('Order Status', style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      );

  } else {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 8,
    offset: const Offset(0, 4),
    )
    ],
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

    /// --- TOP CONTENT ---
    Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

    RichText(
    text: TextSpan(
    text: "You choose ",
    style: const TextStyle(fontSize: 16, color: Colors.grey),
    children: [
    TextSpan(
    text: operation,
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.black,
    fontSize: 18,
    ),
    ),
    ],
    ),
    ),

    const SizedBox(height: 6),

    Text("Order ID: $orderId",style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,),
    ),

    const SizedBox(height: 4),

    const Text(
    "Track your wash",
    style: TextStyle(fontSize: 14, color: Colors.grey),
    ),

    const SizedBox(height: 20),

    _OrderTimeline(currentStep: 2),
    ],
    ),
    ),

    /// --- BOTTOM ACTION BAR ---
    Row(
    children: [
    Expanded(
    child: SizedBox(
    height: 56,
    child: ElevatedButton(
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF692C5A),
    shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
    bottomLeft: Radius.circular(12),
    ),
    ),
    ),
    onPressed: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => PaymentStatusScreen(
    orderId: orderId,
    orderstatus:orderStatus,
    machinename: machinename,
    paymentStatus: paymentStatus,
    amount: amount,
    dateTime: startTime,
    ),
    ),
    );
    },
    child: const Text(
    "Payment Status",
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    ),
    ),
    ),
    Expanded(
    child: SizedBox(
    height: 56,
    child: ElevatedButton(
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF692C5A),
    shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
    bottomRight: Radius.circular(12),
    ),
    ),
    ),
    onPressed: () {},
    child: const Text(
    "Order Status",
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    ),
    ),
    ),
    ],
    ),
    ],
    ),
    );
    }
  }
}

class BlinkingCountdown extends StatefulWidget {
  final Duration timeLeft;

  const BlinkingCountdown({super.key, required this.timeLeft});

  @override
  State<BlinkingCountdown> createState() => _BlinkingCountdownState();
}

class _BlinkingCountdownState extends State<BlinkingCountdown> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _opacity = Tween(begin: 1.0, end: 0.3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        formatTime(widget.timeLeft),
        style: const TextStyle(
          fontSize: 20,
          color: Color(0xFF692C5A),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


}
class _OrderTimeline extends StatelessWidget {
  final int currentStep;
  const _OrderTimeline({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = [
      "Order Received",
      "Wash Initiated",
      "In Progress",
      "Completed",
      "Delivered"
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final done = i <= currentStep;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 6,
                backgroundColor:
                done ? const Color(0xFF692C5A) : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      }),
    );
  }
}

