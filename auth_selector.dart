import 'package:flutter/material.dart';
import 'auth_form.dart';
import 'user_type_selection.dart';

class AuthSelector extends StatefulWidget {
  final String userType; // 'Donor' or 'Acceptor'
  const AuthSelector({super.key, required this.userType});

  @override
  State<AuthSelector> createState() => _AuthSelectorState();
}

class _AuthSelectorState extends State<AuthSelector> {
  void _openAuthForm(BuildContext context, String action) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthForm(action: action, userType: widget.userType),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const UserTypeSelection(),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${widget.userType} Authentication"),
          backgroundColor: widget.userType == 'Donor' ? Colors.orange : Colors.green,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.userType == 'Donor' ? Icons.volunteer_activism : Icons.handshake,
                  size: 80,
                  color: widget.userType == 'Donor' ? Colors.orange : Colors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome, ${widget.userType}!",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.userType == 'Donor'
                      ? "Share your blessings with those in need"
                      : "Find food donations near you",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openAuthForm(context, "Sign Up"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.userType == 'Donor' ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openAuthForm(context, "Log In"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(
                        color: widget.userType == 'Donor' ? Colors.orange : Colors.green,
                      ),
                    ),
                    child: Text(
                      "Log In",
                      style: TextStyle(
                        fontSize: 18,
                        color: widget.userType == 'Donor' ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}