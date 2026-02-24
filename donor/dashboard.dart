import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'add_donation.dart';
import 'my_donations.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/acceptor/donor_requests.dart';
import 'package:sharebites/overall_files/settings_page.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:intl/intl.dart';

class Dashboard extends StatefulWidget {
  final User user;

  const Dashboard({super.key, required this.user});

  @override
  State<Dashboard> createState() => _DashboardState();

}

class _DashboardState extends State<Dashboard> {
  final AuthService _authService = AuthService();
  final DonationService _donationService = DonationService();
  final SupabaseNotificationService _notificationService = SupabaseNotificationService();
  late final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  late User user;
  ImageProvider? profileImage;
  bool _sessionChecking = false;

  int pendingDonations = 0;
  int completedDonations = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    print('Dashboard initialized for user: ${widget.user.email}');
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
        userType: 'Donor',
      );
      print('[SUCCESS] User registered for notifications');
    } catch (e) {
      print('[WARNING] Failed to register for notifications: $e');
    }
  }

  void _initializeData() async {
    await _loadUserData();
    await _loadDonationStats();


    if (mounted && user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _forceLoadImageWithCacheBusting(user.profileImageUrl!);
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    print('=== LOADING USER DATA (DONOR) ===');
    setState(() => _sessionChecking = true);

    try {

      await _authService.refreshUserDataCompletely();

      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        print('[SUCCESS] User loaded: ${currentUser.name}');
        print('Profile image URL from database: ${currentUser.profileImageUrl}');


        if (currentUser.profileImageUrl != null && currentUser.profileImageUrl!.isNotEmpty) {
          await _clearImageCache();
        }

        setState(() {
          user = currentUser;
          profileImage = null;
        });


        if (currentUser.profileImageUrl != null && currentUser.profileImageUrl!.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _forceLoadImageWithCacheBusting(currentUser.profileImageUrl!);
            }
          });
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

      final imageProvider = NetworkImage(
        cacheBustedUrl,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      if (mounted) {
        setState(() {
          profileImage = imageProvider;
        });
        print('[SUCCESS] Image provider set');
      }

      // Pre-cache the image
      precacheImage(imageProvider, context).then((_) {
        print('[SUCCESS] Image pre-cached successfully');
      }).catchError((e) {
        print('[WARNING] Pre-cache warning: $e');

        if (mounted) {
          setState(() {
            profileImage = NetworkImage(imageUrl);
          });
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


      final oldMaxSize = imageCache.maximumSize;
      final oldMaxSizeBytes = imageCache.maximumSizeBytes;

      imageCache.maximumSize = 0;
      imageCache.maximumSizeBytes = 0;
      PaintingBinding.instance.imageCache.maximumSize = 0;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 0;


      await Future.delayed(const Duration(milliseconds: 100));


      imageCache.maximumSize = oldMaxSize;
      imageCache.maximumSizeBytes = oldMaxSizeBytes;
      PaintingBinding.instance.imageCache.maximumSize = 1000;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

      print('[SUCCESS] Image cache cleared and reset');
    } catch (e) {
      print('[ERROR] Error clearing cache: $e');
    }
  }

  Future<void> _loadDonationStats() async {
    setState(() => _loadingStats = true);
    try {
      await _authService.refreshUserData();

      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        setState(() {
          user = currentUser;
        });
      }

      final donations = await _donationService.getDonationsByDonor(user.id);
      setState(() {
        pendingDonations = donations.where((d) =>
        d.status == 'Pending' || d.status == 'Reserved').length;
        completedDonations = donations.where((d) =>
        d.status == 'Completed').length;
        _loadingStats = false;
      });

      print('=== DASHBOARD STATS LOADED ===');
      print('Total Donations (from user): ${user.totalDonations ?? 0}');
      print('Pending: $pendingDonations');
      print('Completed: $completedDonations');

    } catch (e) {
      print('Error loading donation stats: $e');
      setState(() => _loadingStats = false);
      _showErrorMessage('Statistics Error', 'Unable to load donation statistics');
    }
  }


  Stream<int> _getUnreadCountStream() {
    return _notificationService.watchUnreadCount(user.id);
  }

  void _debugUserData() async {
    print('=== DEBUG USER DATA ===');
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
      print('=== LOGGING OUT (DONOR) ===');


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

  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
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
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                'Checking session...',
                style: TextStyle(
                  color: Colors.orange[700],
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
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                'Redirecting to login...',
                style: TextStyle(
                  color: Colors.orange[700],
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
            "Donor Dashboard",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: Colors.orange,
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
                            'userType': 'Donor',
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

              if (user.isVerified == true)
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
                      const Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Verified ✓',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your account is verified. You can now use all features.',
                              style: TextStyle(color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_authService.needsCnicVerification(user))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verify Your Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload CNIC to verify your account. Auto-verified upon upload.',
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
                          'Upload CNIC',
                          style: TextStyle(color: Colors.orange),
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
                      ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            "$completedDonations",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const Text(
                            "Completed",
                            style: TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            "$pendingDonations",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const Text(
                            "Pending",
                            style: TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            "${user.totalDonations ?? 0}",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const Text(
                            "Total",
                            style: TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddDonation()),
                              ).then((_) => _loadDonationStats());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text(
                              "Add Donation",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MyDonations()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text(
                              "My Donations",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DonorRequests()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        "View Donation Requests",
                        style: TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
          backgroundColor: Colors.orange[100],
          child: profileImage == null
              ? const Icon(Icons.person, size: 60, color: Colors.orange)
              : null,
        ),
        const SizedBox(height: 30),


        InfoRow(label: "Name", value: user.name),
        InfoRow(label: "Email", value: user.email),
        InfoRow(label: "Phone", value: user.phone),
        InfoRow(label: "User Type", value: user.userType),
        InfoRow(label: "Sign-In Method", value: user.authProvider == 'google' ? 'Google' : 'Email'),
        InfoRow(label: "Total Donations", value: "${user.totalDonations ?? 0}"),

        if (user.accountType != null && user.accountType!.isNotEmpty)
          InfoRow(label: "Account Type", value: user.accountType!),

        if (user.address != null && user.address!.isNotEmpty)
          InfoRow(label: "Address", value: user.address!),

        if (user.location != null)
          InfoRow(
            label: "Location",
            value: "Lat: ${user.location!.latitude.toStringAsFixed(5)}, Lng: ${user.location!.longitude.toStringAsFixed(5)}",
          ),


        InfoRow(
          label: "CNIC Status",
          value: user.isVerified == true
              ? "Verified ✓"
              : (user.cnicFrontUrl != null && user.cnicBackUrl != null)
              ? "Uploaded (Auto-verified)"
              : "Not uploaded",
          color: user.isVerified == true ? Colors.green : Colors.orange,
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

                    _loadUserData();
                  },
                  icon: const Icon(Icons.settings, size: 20),
                  label: const Text(
                    "Edit Profile",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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

                    await _clearImageCache();
                    await _loadUserData();
                    await _loadDonationStats();
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
                color: Colors.orange,
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