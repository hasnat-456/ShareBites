import 'package:flutter/material.dart';
import 'ngo_service.dart';
import 'package:sharebites/models/ngo_model.dart';
import 'package:sharebites/verifier/ngo_dashboard.dart';
import 'package:sharebites/verifier/ngo_data_initializer.dart';

class NGOLogin extends StatefulWidget {
  const NGOLogin({super.key});

  @override
  State<NGOLogin> createState() => _NGOLoginState();
}

class _NGOLoginState extends State<NGOLogin> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final NGOService _ngoService = NGOService();

  List<NGO> _ngos = [];
  NGO? _selectedNGO;
  bool _loading = true;
  bool _loggingIn = false;
  bool _obscurePassword = true;
  bool _initializing = false;
  String _debugMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNGOs();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadNGOs() async {
    setState(() {
      _loading = true;
      _debugMessage = 'Loading NGOs from database...';
    });

    try {
      print('=== NGO LOAD DEBUG ===');
      print('Step 1: Fetching NGOs from service...');

      final ngos = await _ngoService.getAllNGOs();

      print('Step 2: NGOs fetched. Count: ${ngos.length}');

      if (ngos.isEmpty) {
        print('WARNING: No NGOs found in database!');
        setState(() {
          _ngos = [];
          _loading = false;
          _debugMessage = 'No NGOs found. Please add NGOs in Firebase Console.';
        });
      } else {
        print('NGOs found:');
        for (var ngo in ngos) {
          print('  - ${ngo.name} (${ngo.email})');
        }
        setState(() {
          _ngos = ngos;
          _loading = false;
          _debugMessage = '${ngos.length} NGOs loaded successfully';
        });
      }

      print('=== END NGO LOAD DEBUG ===');
    } catch (e) {
      print('ERROR loading NGOs: $e');
      setState(() {
        _loading = false;
        _debugMessage = 'Error: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading NGOs: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _manuallyInitializeNGOs() async {
    setState(() {
      _initializing = true;
      _debugMessage = 'Initializing NGO data...';
    });

    try {
      print('=== MANUAL NGO INITIALIZATION ===');
      print('Starting initialization...');

      await NGODataInitializer.initializeSampleNGOs();

      print('Initialization completed, reloading NGOs...');

      await _loadNGOs();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NGO data initialized successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      print('=== END MANUAL INITIALIZATION ===');
    } catch (e) {
      print('ERROR during manual initialization: $e');

      setState(() {
        _debugMessage = 'Initialization error: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Initialization failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedNGO == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an NGO'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loggingIn = true);

    try {
      final ngo = await _ngoService.ngoLogin(
        _selectedNGO!.id,
        _passwordController.text.trim(),
      );

      setState(() => _loggingIn = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NGODashboard(ngo: ngo),
        ),
      );
    } catch (e) {
      setState(() => _loggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NGO Login"),
        backgroundColor: Colors.blue,
        actions: [
          // Debug info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Debug Info"),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Status: $_debugMessage'),
                        const SizedBox(height: 10),
                        Text('NGOs loaded: ${_ngos.length}'),
                        const SizedBox(height: 10),
                        const Text(
                          'If no NGOs are showing:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('1. Check your internet connection'),
                        const Text('2. Try the "Initialize NGO Data" button'),
                        const Text('3. Check Firebase Console'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              _debugMessage,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Icon and Title
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 80,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "NGO / Verifier Login",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Verify acceptors and help the community",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Debug status banner
              if (_debugMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _ngos.isEmpty
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                      _ngos.isEmpty ? Colors.orange : Colors.green,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _ngos.isEmpty ? Icons.warning : Icons.check_circle,
                        color:
                        _ngos.isEmpty ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _debugMessage,
                          style: TextStyle(
                            color: _ngos.isEmpty
                                ? Colors.orange.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // NGO Selection Dropdown - FIXED OVERFLOW
              const Text(
                "Select Your Organization",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<NGO>(
                value: _selectedNGO,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.business, color: Colors.blue),
                  hintText: _ngos.isEmpty ? 'No NGOs available' : 'Choose NGO',
                ),
                items: _ngos.map((ngo) {
                  return DropdownMenuItem<NGO>(
                    value: ngo,
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 60,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ngo.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ngo.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (ngo) {
                  setState(() => _selectedNGO = ngo);
                },
                validator: (value) {
                  if (value == null) return 'Please select an NGO';
                  return null;
                },
                dropdownColor: Colors.white,
                menuMaxHeight: 300,
                selectedItemBuilder: (context) {
                  return _ngos.map((ngo) {
                    return Container(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: Text(
                        ngo.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList();
                },
              ),

              const SizedBox(height: 20),

              // Password Field
              const Text(
                "Password",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  hintText: 'Enter password',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Password hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "First time? Use the default password provided by your organization",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loggingIn || _ngos.isEmpty ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _loggingIn
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Login",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Manual initialization section (only show if no NGOs)
              if (_ngos.isEmpty) ...[
                const Divider(),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "No NGOs Found",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "The NGO database appears to be empty. This could be due to:",
                      ),
                      const SizedBox(height: 5),
                      const Text("• First time running the app"),
                      const Text("• Network connectivity issues"),
                      const Text("• Database initialization error"),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                          _initializing ? null : _manuallyInitializeNGOs,
                          icon: _initializing
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _initializing
                                ? "Initializing..."
                                : "Initialize NGO Data",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Refresh button
              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : _loadNGOs,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh NGO List"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}