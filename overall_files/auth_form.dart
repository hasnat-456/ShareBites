import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/donor/dashboard.dart';
import 'package:sharebites/acceptor/acceptor_dashboard.dart';
import 'auth_selector.dart';
import 'user_service.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

class AuthForm extends StatefulWidget {
  final String action;
  final String userType;
  const AuthForm({super.key, required this.action, required this.userType});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String phone = '';
  String accountType = 'Individual';
  String familySize = '4';
  String monthlyIncome = 'Less than 20,000';

  bool _obscurePassword = true;
  bool _isGoogleLoading = false;
  bool _isLoading = false;
  bool _useGoogleSignUp = false;
  String? _googleEmail;

  final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
  final RegExp passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#+-?&]).{8,}$');
  final RegExp phoneRegex = RegExp(r'^03\d{9}$');

  @override
  void initState() {
    super.initState();
    print('AuthForm initialized - Action: ${widget.action}, UserType: ${widget.userType}');
  }

  // Handle device back button
  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthSelector(userType: widget.userType),
      ),
    );
    return false; // Prevent default back behavior
  }

  // ================= GOOGLE SIGN IN =================
  Future<void> _signInWithGoogle() async {
    if (widget.action != "Log In") return;

    setState(() => _isGoogleLoading = true);

    try {
      print('Starting Google Sign-In for ${widget.userType}...');

      final authService = AuthService();
      final user = await authService.signInWithGoogle(widget.userType);

      _showSuccessMessage("Welcome back, ${user.name}!");

      // FIXED: Use handleSuccessfulAuth without blocking
      _handleSuccessfulAuth(user);

    } catch (e) {
      String errorMessage = e.toString();

      // Clean up error message for display
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }

      _showErrorMessage("Google Sign-In Failed", errorMessage);
      print('Google Sign-In Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _handleSuccessfulAuth(User user) {
    // Initialize notifications in the background (don't await)
    _registerUserForNotifications(user);

    // Navigate immediately without waiting for notification registration
    _navigateToDashboard(user);
  }

  Future<void> _registerUserForNotifications(User user) async {
    try {
      print('Registering user ${user.id} for notifications...');
      await SupabaseNotificationService().registerUser(
        userId: user.id,
        userType: user.userType,
      );
      print('âœ… User registered for notifications');
    } catch (e) {
      print('âš ï¸ Failed to register for notifications: $e');
    }
  }
  // ================= GOOGLE SIGN UP =================
  Future<void> _initiateGoogleSignUp() async {
    if (widget.action != "Sign Up") return;

    setState(() => _isGoogleLoading = true);

    try {
      print('Starting Google Sign-Up for ${widget.userType}...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: '816352002695-jef42n9jil8b9ppntb0kcup27ufkk8bs.apps.googleusercontent.com',
      );

      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        setState(() {
          _useGoogleSignUp = true;
          _googleEmail = googleUser.email;
          email = googleUser.email;
        });

        _showSuccessMessage("Google account selected. Please fill remaining details.");
        print('Google account selected: ${googleUser.email}');
      } else {
        _showInfoMessage("Google sign up cancelled");
      }
    } catch (e) {
      _showErrorMessage("Google Sign-Up Error", e.toString());
      print('Google Sign-Up Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  // ================= EMAIL/PASSWORD SUBMIT =================
  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showInfoMessage("Please fix all errors before submitting");
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final authService = AuthService();

    try {
      User user;

      if (_useGoogleSignUp && widget.action == "Sign Up") {
        // Google Sign Up
        print('Completing Google Sign-Up...');

        int? fSize = widget.userType == 'Acceptor' ? int.tryParse(familySize) : null;
        if (widget.userType == 'Acceptor' && (fSize == null || fSize < 1)) {
          throw Exception('Please enter a valid family size (minimum 1)');
        }

        user = await authService.signUpWithGoogle(
          userType: widget.userType,
          phone: phone,
          accountType: widget.userType == 'Donor' ? accountType : null,
          familySize: fSize,
          monthlyIncome: widget.userType == 'Acceptor' ? monthlyIncome : null,
        );

        _showSuccessMessage("Account created successfully with Google!");
        print('Google Sign-Up successful for: ${user.email}');

      } else if (widget.action == "Sign Up") {
        // Email Sign Up
        print('Starting Email Sign-Up...');

        int? fSize = widget.userType == 'Acceptor' ? int.tryParse(familySize) : null;

        user = await authService.signUp(
          email: email,
          password: password,
          name: email.split('@')[0],
          phone: phone,
          userType: widget.userType,
          accountType: widget.userType == 'Donor' ? accountType : null,
          familySize: fSize,
          monthlyIncome: widget.userType == 'Acceptor' ? monthlyIncome : null,
        );

        _showSuccessMessage("Account created successfully! Welcome to ShareBites!");
        print('Email Sign-Up successful for: ${user.email}');

      } else {
        // Email/Password Login
        print('Attempting Email/Password Login for: $email');

        user = await authService.signIn(email, password, widget.userType);

        _showSuccessMessage("Welcome back, ${user.name}!");
        print('Login successful for: ${user.email}');
      }

      // FIXED: Don't await, just call the method
      _handleSuccessfulAuth(user);

    } catch (e) {
      String errorTitle = widget.action == "Sign Up" ? "Sign Up Failed" : "Login Failed";
      String errorMessage = e.toString();

      // Clean up error message
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }

      _showErrorMessage(errorTitle, errorMessage);
      print('Auth Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDashboard(User user) {
    if (!mounted) return;

    print('Navigating to dashboard for ${user.userType}');

    // Register for notifications (don't wait for it)
    _registerUserForNotifications(user);

    // IMPORTANT: Fetch fresh user data before navigating
    _fetchFreshUserData(user.id).then((freshUser) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => freshUser.userType == 'Donor'
                ? Dashboard(user: freshUser)
                : AcceptorDashboard(user: freshUser),
          ),
        );
      }
    }).catchError((e) {
      // If fetching fails, use the original user
      print('Error fetching fresh user data: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => user.userType == 'Donor'
                ? Dashboard(user: user)
                : AcceptorDashboard(user: user),
          ),
        );
      }
    });
  }

  void _resetForm() {
    setState(() {
      _useGoogleSignUp = false;
      _googleEmail = null;
      email = '';
      password = '';
      phone = '';
      _formKey.currentState?.reset();
    });
    _showInfoMessage("Form reset");
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String title, String message) {
    if (!mounted) return;

    print('Error: $title - $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid Gmail address\n(example@gmail.com)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (widget.action == "Log In") {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }
      return null;
    } else {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }
      if (!passwordRegex.hasMatch(value)) {
        return 'Password must contain:\nÃ¢â‚¬Â¢ At least 8 characters\nÃ¢â‚¬Â¢ Letters & numbers\nÃ¢â‚¬Â¢ Special character (@\$!%*#?&)';
      }
      return null;
    }
  }

  String? _validatePhone(String? value) {
    if (widget.action == "Sign Up") {
      if (value == null || value.isEmpty) {
        return 'Phone number is required';
      }
      if (!phoneRegex.hasMatch(value)) {
        return 'Phone must be 11 digits\nstarting with 03 (e.g., 03123456789)';
      }
      return null;
    }
    return null;
  }

  String? _validateFamilySize(String? value) {
    if (widget.action == "Sign Up" && widget.userType == "Acceptor") {
      if (value == null || value.isEmpty) {
        return 'Family size is required';
      }
      final fSize = int.tryParse(value);
      if (fSize == null || fSize < 1) {
        return 'Enter valid number of members\n(minimum 1)';
      }
      return null;
    }
    return null;
  }

  Future<User> _fetchFreshUserData(String userId) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userSnapshot = await databaseRef.child('users').child(userId).once();

      if (userSnapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
        final freshUser = User.fromJson(userData);
        print('Fresh user data loaded with profile image: ${freshUser.profileImageUrl}');
        return freshUser;
      }
      throw Exception('User data not found');
    } catch (e) {
      print('Error fetching fresh user data: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${widget.userType} - ${widget.action}"),
          backgroundColor: widget.userType == 'Donor' ? Colors.orange : Colors.green,
          actions: [
            if (_useGoogleSignUp)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _resetForm,
                tooltip: 'Reset Form',
              ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Google Sign-In/Sign-Up Button
                    if (widget.action == "Log In" || (widget.action == "Sign Up" && !_useGoogleSignUp))
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: widget.action == "Log In"
                                  ? (_isGoogleLoading ? null : _signInWithGoogle)
                                  : (_isGoogleLoading ? null : _initiateGoogleSignUp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Colors.grey),
                                ),
                              ),
                              child: _isGoogleLoading
                                  ? const CircularProgressIndicator(color: Colors.blue)
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.g_mobiledata,
                                    size: 28,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.action == "Log In"
                                        ? "Sign in with Google"
                                        : "Sign up with Google",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "OR",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),

                    // Google Sign-Up Info
                    if (_useGoogleSignUp)
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Google Account Connected",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      "Email: $_googleEmail",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _resetForm,
                                child: const Text(
                                  "Change",
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // EMAIL (disabled if using Google Sign-Up)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Gmail Address',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email),
                        suffixIcon: _useGoogleSignUp
                            ? const Icon(Icons.lock, color: Colors.green, size: 16)
                            : null,
                      ),
                      initialValue: _useGoogleSignUp ? _googleEmail : null,
                      readOnly: _useGoogleSignUp,
                      validator: _validateEmail,
                      onSaved: (v) => email = v!,
                    ),
                    const SizedBox(height: 16),

                    // PASSWORD (hidden for Google Sign-Up)
                    if (!_useGoogleSignUp || widget.action == "Log In")
                      TextFormField(
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: _validatePassword,
                        onSaved: (v) => password = v ?? '',
                      ),

                    if (!_useGoogleSignUp || widget.action == "Log In")
                      const SizedBox(height: 16),

                    if (widget.action == "Sign Up") ...[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '03123456789',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                        onSaved: (v) => phone = v!,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (widget.action == "Sign Up" && widget.userType == "Donor")
                      DropdownButtonFormField<String>(
                        value: accountType,
                        decoration: const InputDecoration(
                          labelText: 'Account Type',
                          border: OutlineInputBorder(),
                          helperText: 'Select your account type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Individual', child: Text('Individual')),
                          DropdownMenuItem(value: 'Organization', child: Text('Organization')),
                        ],
                        onChanged: (v) => setState(() => accountType = v!),
                        validator: (v) {
                          if (widget.action == "Sign Up" && widget.userType == "Donor" && v == null) {
                            return 'Please select account type';
                          }
                          return null;
                        },
                      ),

                    if (widget.action == "Sign Up" && widget.userType == "Acceptor") ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Family Size',
                          border: OutlineInputBorder(),
                          hintText: 'Enter number of family members',
                          helperText: 'Minimum 1 member',
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: '4',
                        validator: _validateFamilySize,
                        onSaved: (v) => familySize = v ?? '4',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: monthlyIncome,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Income',
                          border: OutlineInputBorder(),
                          helperText: 'Select your income range',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Less than 20,000', child: Text('Less than 20,000')),
                          DropdownMenuItem(value: '20,000 - 40,000', child: Text('20,000 - 40,000')),
                          DropdownMenuItem(value: '40,000 - 60,000', child: Text('40,000 - 60,000')),
                          DropdownMenuItem(value: 'Above 60,000', child: Text('Above 60,000')),
                        ],
                        onChanged: (v) => setState(() => monthlyIncome = v!),
                        validator: (v) {
                          if (widget.action == "Sign Up" && widget.userType == "Acceptor" && v == null) {
                            return 'Please select income range';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.userType == 'Donor' ? Colors.orange : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                            : Text(
                          _useGoogleSignUp ? "Complete Sign Up" : widget.action,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    if (_useGoogleSignUp)
                      const SizedBox(height: 10),

                    if (_useGoogleSignUp)
                      TextButton(
                        onPressed: _resetForm,
                        child: const Text(
                          "Use email sign up instead",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}