import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'apply_for_donation.dart';
import 'package:sharebites/acceptor/received_donations.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/cnic_verification/verification_status_widget.dart';
import 'package:sharebites/overall_files/settings_page.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:intl/intl.dart';

class AcceptorDashboard extends StatefulWidget {
  final User user;

  const AcceptorDashboard({super.key, required this.user});

  @override
  State<AcceptorDashboard> createState() => _AcceptorDashboardState();
}

class _AcceptorDashboardState extends State<AcceptorDashboard> {
  final AuthService _authService = AuthService();
  final SupabaseNotificationService _notificationService = SupabaseNotificationService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  late User user;
  ImageProvider? profileImage;
  int _receivedDonationsCount = 0;
  bool _loadingStats = true;
  bool _sessionChecking = false;

  @override
  void initState() {
    super.initState();
    print('AcceptorDashboard initialized for user: ${widget.user.email}');
    user = widget.user;


    _initializeData();


    _registerForNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugUserData();

      if (_authService.needsProfileCompletion(user)) {
        _showProfileCompletionDialog();
      }
    });
  }


  Future<void> _registerForNotifications() async {
    try {
      await _notificationService.registerUser(
        userId: user.id,
        userType: 'Acceptor',
      );
      print('[SUCCESS] User registered for notifications');
    } catch (e) {
      print('[WARNING] Failed to register for notifications: $e');
    }
  }

  void _initializeData() async {
    await _loadUserData();
    await _loadReceivedDonationsCount();


    if (mounted && user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _forceLoadImageWithCacheBusting(user.profileImageUrl!);
        }
      });
    }
  }


  Stream<int> _getUnreadCountStream() {
    return _notificationService.watchUnreadCount(user.id);
  }

  Future<void> _loadUserData() async {
    print('=== LOADING USER DATA (ACCEPTOR) ===');
    setState(() => _sessionChecking = true);

    try {

      await _authService.refreshUserDataCompletely();

      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        print('[SUCCESS] User loaded: ${currentUser.name}');
        print('Profile image URL: ${currentUser.profileImageUrl}');

        setState(() {
          user = currentUser;

          profileImage = null;
        });


        if (currentUser.profileImageUrl != null && currentUser.profileImageUrl!.isNotEmpty) {
          _forceLoadImageWithCacheBusting(currentUser.profileImageUrl!);
        }
      } else {
        print('[ERROR] User session expired');
        _showSessionExpiredMessage();
        _redirectToLogin();
      }
    } catch (e, stackTrace) {
      print('[ERROR] Error loading user data: $e');
      print('Stack trace: $stackTrace');
      _showErrorMessage('Session Error', 'Unable to load user data');
    } finally {
      if (mounted) {
        setState(() => _sessionChecking = false);
      }
      print('=== USER DATA LOADING COMPLETE ===');
    }
  }

  void _forceLoadImageWithCacheBusting(String imageUrl) {
    print('=== FORCE LOADING IMAGE ===');
    print('Original URL: $imageUrl');


    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheBustedUrl = imageUrl.contains('?')
        ? '$imageUrl&_t=$timestamp'
        : '$imageUrl?_t=$timestamp';

    print('Cache-busted URL: $cacheBustedUrl');

    try {

      final completer = Completer<ImageProvider>();
      final imageProvider = NetworkImage(
        cacheBustedUrl,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );


      final stream = imageProvider.resolve(ImageConfiguration.empty);

      final listener = ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
          print('[SUCCESS] Image loaded successfully');
          if (mounted) {
            setState(() {
              profileImage = imageProvider;
            });
          }
          completer.complete(imageProvider);
        },
        onError: (exception, StackTrace? stackTrace) {
          print('[ERROR] Error loading image: $exception');
          // Try original URL as fallback
          if (mounted) {
            setState(() {
              profileImage = NetworkImage(imageUrl);
            });
          }
          completer.completeError(exception);
        },
      );

      stream.addListener(listener);


      Future.delayed(const Duration(seconds: 10), () {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Image load timeout'));
        }
      });

    } catch (e) {
      print('Error in force load: $e');

      if (mounted) {
        setState(() {
          profileImage = NetworkImage(imageUrl);
        });
      }
    }
  }

  Future<void> _clearImageCache() async {
    print('=== CLEARING IMAGE CACHE ===');

    try {

      imageCache.clear();
      imageCache.clearLiveImages();


      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      print('[SUCCESS] Image cache cleared');
    } catch (e) {
      print('[ERROR] Error clearing cache: $e');
    }
  }

  Future<void> _loadReceivedDonationsCount() async {
    print('=== LOADING DONATION STATISTICS ===');
    setState(() => _loadingStats = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('[ERROR] No current user');
        setState(() => _loadingStats = false);
        return;
      }

      print('Loading stats for: ${currentUser.name} (${currentUser.id})');


      print('Step 1: Counting from received_donations table...');
      final DatabaseReference receivedRef = FirebaseDatabase.instance
          .ref()
          .child('received_donations');

      final receivedSnapshot = await receivedRef
          .orderByChild('acceptorId')
          .equalTo(currentUser.id)
          .once();

      int acceptedCount = 0;

      if (receivedSnapshot.snapshot.exists) {
        final receivedMap = Map<String, dynamic>.from(receivedSnapshot.snapshot.value as Map);


        receivedMap.forEach((key, value) {
          final donationData = Map<String, dynamic>.from(value as Map);
          final status = donationData['status']?.toString() ?? '';

          if (status == 'Accepted') {
            acceptedCount++;
            print('  [SUCCESS] Accepted: ${donationData['title']} (${donationData['id']})');
          } else {
            print('  [ERROR] Skipped (${status}): ${donationData['title']}');
          }
        });
      }

      print('[SUCCESS] Accepted donations from received_donations: $acceptedCount');


      print('Step 2: Cross-checking with donations table...');
      final DatabaseReference donationsRef = FirebaseDatabase.instance
          .ref()
          .child('donations');

      final donationsSnapshot = await donationsRef
          .orderByChild('acceptorId')
          .equalTo(currentUser.id)
          .once();

      int completedCount = 0;

      if (donationsSnapshot.snapshot.exists) {
        final donationsMap = Map<String, dynamic>.from(donationsSnapshot.snapshot.value as Map);


        donationsMap.forEach((key, value) {
          final donationData = Map<String, dynamic>.from(value as Map);
          final status = donationData['status']?.toString() ?? '';

          if (status == 'Completed') {
            completedCount++;
            print('  [SUCCESS] Completed: ${donationData['title']} (${donationData['id']})');
          }
        });
      }

      print('[SUCCESS] Completed donations from donations table: $completedCount');


      final totalAccepted = acceptedCount > completedCount ? acceptedCount : completedCount;

      print('');
      print('=== STATISTICS SUMMARY ===');
      print('Accepted (received_donations): $acceptedCount');
      print('Completed (donations): $completedCount');
      print('Final Count: $totalAccepted');
      print('=========================');

      setState(() {
        _receivedDonationsCount = totalAccepted;
        _loadingStats = false;
      });

      print('=== STATISTICS LOADED SUCCESSFULLY ===');

    } catch (e, stackTrace) {
      print('[ERROR] Error loading donation statistics: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _receivedDonationsCount = 0;
        _loadingStats = false;
      });

      _showErrorMessage('Statistics Error', 'Unable to load donation statistics: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _logout(BuildContext context) async {
    final dialogContext = context;

    final confirm = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      print('=== LOGGING OUT (ACCEPTOR) ===');


      await _notificationService.unregisterUser(user.id);


      await _clearImageCache();


      await _authService.signOut();
      print('[SUCCESS] User signed out');

      if (mounted) {
        _showSuccessMessage('Logged out successfully');


        await Future.delayed(const Duration(milliseconds: 300));

        _redirectToLogin();
      }
    } catch (e) {
      print('[ERROR] Logout error: $e');
      if (mounted) {
        _showErrorMessage('Logout Failed', 'Error during logout: ${e.toString()}');
      }
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSessionExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Session expired. Please login again.',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _debugUserData() async {
    print('=== DEBUG USER DATA (Acceptor) ===');
    print('Local user: ${user.name}');
    print('Local profileImageUrl: ${user.profileImageUrl}');
    print('AuthService currentUser: ${_authService.currentUser?.name}');
    print('AuthService profileImageUrl: ${_authService.currentUser?.profileImageUrl}');

    try {
      final userRef = FirebaseDatabase.instance.ref().child('users').child(user.id);
      final userSnapshot = await userRef.once();

      if (userSnapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
        print('Database profileImageUrl: ${userData['profileImageUrl']}');
      }
    } catch (e) {
      print('Error reading from database: $e');
    }
    print('=== END DEBUG ===');
  }

  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.green),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Complete Your Profile',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please complete your profile to access all features:',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              const Text(
                '• Upload CNIC (Front & Back)',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const Text(
                '• Add your address',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const Text(
                '• Select address location on map',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const Text(
                '• Verify your phone number',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              const Text(
                'This helps us ensure community safety and enable all features.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(user: user),
                ),
              );

              _loadUserData();
            },
            child: const Text(
              'Complete Now',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Later',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    bool? shouldExit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to logout and exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout & Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await _performLogout();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 20),
              Text(
                'Checking session...',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      );
    }

    if (_authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToLogin();
      });
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 20),
              Text(
                'Redirecting to login...',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Acceptor Dashboard",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: Colors.green,
          automaticallyImplyLeading: false,
          actions: [

            StreamBuilder<int>(
              stream: _getUnreadCountStream(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/notifications',
                          arguments: {
                            'userId': user.id,
                            'userType': 'Acceptor',
                          },
                        );
                      },
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(user: user),
                  ),
                );

                _loadUserData();
              },
              tooltip: 'Settings',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _logout(context),
              tooltip: 'Logout',
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_authService.needsProfileCompletion(user))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete your profile',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload CNIC, address and select location to access all features',
                              style: TextStyle(color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsPage(user: user),
                            ),
                          );
                          _loadUserData();
                        },
                        child: const Text(
                          'Complete Now',
                          style: TextStyle(color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loadingStats
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : Column(
                    children: [
                      const Text(
                        "Your Donation Statistics",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Total Donations Received: $_receivedDonationsCount",
                        style: const TextStyle(fontSize: 18, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (user.familySize != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Family Size: ${user.familySize} members",
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),


              VerificationStatusWidget(acceptorId: user.id),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ApplyForDonation(),
                              ),
                            ).then((_) => _loadReceivedDonationsCount());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            "Apply for Donation",
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReceivedDonations(),
                              ),
                            ).then((_) => _loadReceivedDonationsCount());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            "Received Donations",
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: _profileView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileView() {
    return Column(
      children: [

        CircleAvatar(
          radius: 80,
          backgroundImage: profileImage,
          backgroundColor: Colors.green[100],
          child: profileImage == null
              ? const Icon(Icons.person, size: 60, color: Colors.green)
              : null,
        ),
        const SizedBox(height: 30),


        InfoRow(label: "Name", value: user.name),
        InfoRow(label: "Email", value: user.email),
        InfoRow(label: "Phone", value: user.phone),
        InfoRow(label: "User Type", value: user.userType),
        InfoRow(label: "Sign-In Method", value: user.authProvider == 'google' ? 'Google' : 'Email'),

        if (user.familySize != null)
          InfoRow(label: "Family Size", value: user.familySize.toString()),

        if (user.monthlyIncome != null)
          InfoRow(label: "Monthly Income", value: user.monthlyIncome!),

        if (user.address != null && user.address!.isNotEmpty)
          InfoRow(label: "Address", value: user.address!),

        if (user.location != null)
          InfoRow(
            label: "Location",
            value: "Lat: ${user.location!.latitude.toStringAsFixed(5)}, Lng: ${user.location!.longitude.toStringAsFixed(5)}",
          ),

        if (user.specialNeeds != null && user.specialNeeds!.isNotEmpty)
          InfoRow(label: "Special Needs", value: user.specialNeeds!),

        InfoRow(
          label: "CNIC Status",
          value: user.cnicVerified == true
              ? "Verified ✓"
              : (user.cnicFrontUrl != null && user.cnicBackUrl != null)
              ? "Uploaded (Pending verification)"
              : "Not uploaded",
          color: user.cnicVerified == true ? Colors.green : Colors.orange,
        ),

        if (user.createdAt != null)
          InfoRow(
            label: "Member Since",
            value: DateFormat('dd/MM/yyyy').format(user.createdAt!.toLocal()),
          ),

        const SizedBox(height: 25),


        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(user: user),
                      ),
                    );
                    // Refresh data when returning
                    _loadUserData();
                  },
                  icon: const Icon(Icons.settings, size: 20),
                  label: const Text(
                    "Edit Profile",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),


              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Clear cache and reload
                    await _clearImageCache();
                    await _loadUserData();
                    await _loadReceivedDonationsCount();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Profile and statistics refreshed"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    "Refresh Stats",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}