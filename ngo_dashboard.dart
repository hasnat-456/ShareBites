import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:sharebites/models/ngo_model.dart';
import 'package:sharebites/models/verification_request_model.dart';
import 'package:sharebites/verifier/ngo_service.dart';
import 'package:sharebites/verifier/ngo_settings.dart';
import 'package:sharebites/cnic_verification/verification_detail.dart';
import 'package:sharebites/overall_files/user_type_selection.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:sharebites/notifications/notification_page.dart';
import 'package:sharebites/overall_files/firebase_debugger.dart';

class NGODashboard extends StatefulWidget {
  final NGO ngo;

  const NGODashboard({super.key, required this.ngo});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  final NGOService _ngoService = NGOService();
  final SupabaseNotificationService _notificationService = SupabaseNotificationService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<VerificationRequest> _requests = [];
  bool _loading = true;

  // Live statistics — all recomputed from actual Firebase data
  int _verifiedCount = 0;
  int _pendingCount = 0;
  int _rejectedCount = 0;
  int _totalAssigned = 0;
  bool _loadingStats = true;

  StreamSubscription<DatabaseEvent>? _verificationsListener;
  StreamSubscription<DatabaseEvent>? _ngoStatsListener;

  @override
  void initState() {
    super.initState();
    print('=== NGO DASHBOARD INITIALIZED ===');
    print('NGO: ${widget.ngo.name}');
    print('NGO ID: ${widget.ngo.id}');

    _registerForNotifications();
    _loadStatistics();
    _loadRequests();
    _setupRealtimeListener();
    _setupStatsListener();
    _runAutoDebugCheck();
  }

  @override
  void dispose() {
    _verificationsListener?.cancel();
    _ngoStatsListener?.cancel();
    super.dispose();
  }

  Future<void> _runAutoDebugCheck() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    print('\n[INFO] AUTO-RUNNING FIREBASE DEBUG CHECK...\n');
    await FirebaseDebugger.printFullDebugInfo(ngoId: widget.ngo.id);
  }

  void _setupRealtimeListener() {
    print('=== SETTING UP REALTIME LISTENER ===');
    print('NGO ID: ${widget.ngo.id}');

    try {
      _verificationsListener = _databaseRef
          .child('verification_requests')
          .orderByChild('assignedNgoId')
          .equalTo(widget.ngo.id)
          .onValue
          .listen((event) {
        print('[INFO] Firebase data changed (indexed query) - reloading requests');

        if (mounted) {
          _loadRequestsWithoutLoading();
        }
      }, onError: (error) {
        print('[ERROR] Error in indexed listener: $error');
        print('[WARNING]  Falling back to full scan listener');
        _setupFallbackListener();
      });

      print('[SUCCESS] Indexed realtime listener setup complete');
    } catch (e) {
      print('[ERROR] Failed to setup indexed listener: $e');
      print('[WARNING]  Using fallback listener');
      _setupFallbackListener();
    }
  }

  void _setupStatsListener() {
    print('=== SETTING UP STATISTICS LISTENER ===');

    try {
      _ngoStatsListener = _databaseRef
          .child('ngos')
          .child(widget.ngo.id)
          .onValue
          .listen((event) {
        print('[INFO] NGO statistics changed - updating');

        if (mounted && event.snapshot.value != null) {
          final ngoData = Map<String, dynamic>.from(event.snapshot.value as Map);
          // Firebase may return num instead of int — use (as num).toInt() for safety
          setState(() {
            _verifiedCount = (ngoData['verifiedCount'] as num? ?? 0).toInt();
            _pendingCount = (ngoData['pendingCount'] as num? ?? 0).toInt();
            _rejectedCount = (ngoData['rejectedCount'] as num? ?? 0).toInt();
            _totalAssigned = _verifiedCount + _pendingCount + _rejectedCount;
            _loadingStats = false;
          });
          print('✅ Statistics updated: Verified=\$_verifiedCount, Pending=\$_pendingCount, Rejected=\$_rejectedCount');
        }
      }, onError: (error) {
        print('[ERROR] Error in stats listener: $error');
      });

      print('[SUCCESS] Statistics listener setup complete');
    } catch (e) {
      print('[ERROR] Failed to setup stats listener: $e');
    }
  }

  void _setupFallbackListener() {
    print('[SETUP]™ Setting up fallback listener (full scan)');

    _verificationsListener?.cancel();

    _verificationsListener = _databaseRef
        .child('verification_requests')
        .onValue
        .listen((event) {
      print('[INFO] Firebase data changed (full scan) - filtering and reloading');

      if (mounted) {
        _loadRequestsWithoutLoading();
      }
    }, onError: (error) {
      print('[ERROR] Error in fallback listener: $error');
    });
  }

  Future<void> _loadStatistics() async {
    try {
      print('=== LOADING NGO STATISTICS ===');

      final ngoSnapshot = await _databaseRef.child('ngos').child(widget.ngo.id).once();

      if (ngoSnapshot.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);

        if (mounted) {
          setState(() {
            _verifiedCount = (ngoData['verifiedCount'] as num? ?? 0).toInt();
            _pendingCount = (ngoData['pendingCount'] as num? ?? 0).toInt();
            _rejectedCount = (ngoData['rejectedCount'] as num? ?? 0).toInt();
            _totalAssigned = _verifiedCount + _pendingCount + _rejectedCount;
            _loadingStats = false;
          });
        }

        print('✅ Statistics loaded: Verified=$_verifiedCount, Pending=$_pendingCount, Rejected=$_rejectedCount');
      } else {
        // No NGO data yet — trigger a stats recompute
        if (mounted) {
          setState(() => _loadingStats = false);
        }
      }
    } catch (e) {
      print('[ERROR] Error loading statistics: $e');
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _registerForNotifications() async {
    try {
      await _notificationService.registerUser(
        userId: widget.ngo.id,
        userType: 'NGO',
      );
      print('[SUCCESS] NGO registered for notifications: ${widget.ngo.id}');
    } catch (e) {
      print('[WARNING]  Failed to register NGO for notifications: $e');
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);

    try {
      print('=== LOADING VERIFICATION REQUESTS ===');

      await _ngoService.checkAndReassignExpiredRequests();

      final requests = await _ngoService.getNGORequests(widget.ngo.id);

      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }

      print('[SUCCESS] Loaded ${requests.length} verification requests');

      for (var request in requests) {
        print('Request: ${request.id}');
        print('  - Acceptor: ${request.acceptorName}');
        print('  - Status: ${request.status}');
        print('  - Assigned NGO: ${request.assignedNgoId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      print('[ERROR] Error loading requests: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadRequestsWithoutLoading() async {
    try {
      print('=== RELOADING VERIFICATION REQUESTS (REALTIME) ===');

      await _ngoService.checkAndReassignExpiredRequests();

      final requests = await _ngoService.getNGORequests(widget.ngo.id);

      if (mounted) {
        setState(() {
          _requests = requests;
        });
      }

      print('[SUCCESS] Reloaded ${requests.length} verification requests');
    } catch (e) {
      print('[ERROR] Error reloading requests: $e');
    }
  }

  Future<void> _runDebugCheck() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Running Firebase Debug...'),
              ],
            ),
          ),
        ),
      ),
    );

    print('\n[INFO] MANUAL FIREBASE DEBUG CHECK...\n');
    await FirebaseDebugger.printFullDebugInfo(ngoId: widget.ngo.id);

    final message = await FirebaseDebugger.quickCheckForDashboard(widget.ngo.id);

    if (!mounted) return;

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange),
            SizedBox(width: 8),
            Text('Firebase Debug Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Check console logs for detailed analysis',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (message.contains('INDEX MISSING'))
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showIndexFixInstructions();
              },
              icon: const Icon(Icons.build),
              label: const Text('Fix Index'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
        ],
      ),
    );
  }

  void _showIndexFixInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.orange),
            SizedBox(width: 8),
            Text('Fix Firebase Index'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The Firebase index is missing. Follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Go to Firebase Console'),
              SizedBox(height: 8),
              Text('2. Select your project'),
              SizedBox(height: 8),
              Text('3. Click "Realtime Database"'),
              SizedBox(height: 8),
              Text('4. Click "Rules" tab'),
              SizedBox(height: 8),
              Text('5. Add the required index (check console)'),
              SizedBox(height: 16),
              Text(
                'The app will work, but may be slower without the index.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openRequestDetail(VerificationRequest request) async {
    print('Opening request detail: ${request.id}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationDetail(
          request: request,
          ngoId: widget.ngo.id,
        ),
      ),
    );

    print('Returned from detail page: $result');

    // Always reload requests and statistics when returning — ensures stats
    // are accurate even if result was null (e.g. back button pressed)
    if (mounted) {
      await _loadRequests();
      await _loadStatistics();
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NGOSettings(ngo: widget.ngo),
      ),
    );
    // Reload statistics when returning from settings
    _loadStatistics();
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsPage(
          userId: widget.ngo.id,
          userType: 'NGO',
        ),
      ),
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _ngoService.signOut();
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UserTypeSelection()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NGO Dashboard'),
            Text(
              widget.ngo.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _openNotifications,
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _runDebugCheck,
            tooltip: 'Debug Firebase',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadRequests();
        await _loadStatistics();
      },
      child: Column(
        children: [
          // Live Updates Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Updates Active',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Statistics Card (Always Visible)
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Organization Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _loadingStats
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Pending',
                            _pendingCount.toString(),
                            Colors.orange,
                            Icons.pending_actions,
                          ),
                          _buildStatItem(
                            'Verified',
                            _verifiedCount.toString(),
                            Colors.green,
                            Icons.verified,
                          ),
                          _buildStatItem(
                            'Rejected',
                            _rejectedCount.toString(),
                            Colors.red,
                            Icons.cancel,
                          ),
                          _buildStatItem(
                            'Total',
                            _totalAssigned.toString(),
                            Colors.blue,
                            Icons.assessment,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Requests Section
          Expanded(
            child: _requests.isEmpty
                ? _buildEmptyState()
                : _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No Pending Requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'New verification requests will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              await _loadRequests();
              await _loadStatistics();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(VerificationRequest request) {
    final daysLeft = request.expiresAt != null
        ? request.expiresAt!.difference(DateTime.now()).inDays
        : 0;

    final isUrgent = daysLeft <= 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _openRequestDetail(request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.acceptorName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.acceptorEmail,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    request.acceptorPhone,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.family_restroom, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Family Size: ${request.familySize ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expires in: $daysLeft day${daysLeft == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: isUrgent ? Colors.red : Colors.grey[600],
                      fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _openRequestDetail(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Review'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}