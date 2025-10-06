import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  String id = '';
  String firstName = '';
  String lastName = '';
  String mobile = '';
  String email = '';
  String dob = '';
  String stayIn = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse("https://api.coinlaundryindia.com/users/me"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        id = data['id'].toString();
        firstName = data['firstName'] ?? '';
        lastName = data['lastName'] ?? '';
        mobile = data['mobile'] ?? '';
        email = data['email'] ?? '';
        dob = data['dob'] ?? '';
        stayIn = data['stayIn'] ?? '';
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired, please log in again.")),
      );
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.patch(
        Uri.parse("https://api.coinlaundryindia.com/users/$id"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({
          "id": int.parse(id),
          "firstName": firstName,
          "lastName": lastName,
          "mobile": mobile,
          "email": email,
          "dob": dob,
          "stayIn": stayIn,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully.")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Update failed.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF692C5A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF692C5A),
        elevation: 0,
        title: const Text("Account Settings", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("First name", firstName, (val) => firstName = val),
              _buildTextField("Last name", lastName, (val) => lastName = val),
              _buildTextField("Mobile Number", mobile, (val) => mobile = val),
              _buildTextField("Email", email, (val) => email = val),
              _buildDatePickerField(context),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Living type", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRadio("Home"),
                  _buildRadio("Paying Guest"),
                  _buildRadio("Hostel"),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF692C5A),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                onPressed: _submit,
                child: const Text("Submit"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onSaved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
        onSaved: (val) => onSaved(val ?? ''),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: dob.isNotEmpty
                ? DateTime.tryParse(dob) ?? DateTime.now()
                : DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );

          if (pickedDate != null) {
            setState(() {
              dob =
              "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
            });
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: "Date of Birth",
              filled: true,
              fillColor: Colors.white,
            ),
            controller: TextEditingController(text: dob),
            readOnly: true,
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(String value) {
    return Expanded(
      child: RadioListTile<String>(
        title: Text(value),
        value: value,
        groupValue: stayIn,
        activeColor: Colors.white,
        onChanged: (val) {
          setState(() => stayIn = val!);
        },
        tileColor: Colors.white,
      ),
    );
  }
}
