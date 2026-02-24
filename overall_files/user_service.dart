import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/overall_files/cloudinary_service.dart';
import 'package:sharebites/notifications/notification_service.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:sharebites/verifier/ngo_service.dart';

class User {
  String id;
  String name;
  String email;
  String phone;
  String userType;
  String? accountType;
  LatLng? location;
  String? address;
  String? profileImageUrl;
  String? cnicFrontUrl;
  String? cnicBackUrl;
  DateTime createdAt;
  String? authProvider;
  int? familySize;
  String? monthlyIncome;
  String? specialNeeds;
  String? password;
  int? totalDonations;
  double? rating;
  bool? isVerified;
  bool? cnicVerified;
  String? fcmToken;
  DateTime? fcmTokenUpdatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
    this.password,
    this.accountType,
    this.location,
    this.address,
    this.profileImageUrl,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    required this.createdAt,
    this.familySize,
    this.monthlyIncome,
    this.specialNeeds,
    this.totalDonations = 0,
    this.rating = 0.0,
    this.isVerified = false,
    this.cnicVerified = false,
    this.authProvider = 'email',
    this.fcmToken,
    this.fcmTokenUpdatedAt,
  });

  bool get isProfileComplete {
    if (userType == 'Donor') {
      // For donors: CNIC + address + location are required
      return name.isNotEmpty &&
          email.isNotEmpty &&
          phone.isNotEmpty &&
          address != null &&
          address!.isNotEmpty &&
          location != null &&
          cnicFrontUrl != null &&
          cnicFrontUrl!.isNotEmpty &&
          cnicBackUrl != null &&
          cnicBackUrl!.isNotEmpty;
    } else {
      // For acceptors: CNIC + address + location + family size + monthly income
      return name.isNotEmpty &&
          email.isNotEmpty &&
          phone.isNotEmpty &&
          address != null &&
          address!.isNotEmpty &&
          familySize != null &&
          monthlyIncome != null &&
          monthlyIncome!.isNotEmpty &&
          cnicFrontUrl != null &&
          cnicFrontUrl!.isNotEmpty &&
          cnicBackUrl != null &&
          cnicBackUrl!.isNotEmpty &&
          location != null;
    }
  }

  String get verificationStatusText {
    if (userType == 'Donor') {
      if (cnicVerified == true && isVerified == true) {
        return 'Verified (CNIC uploaded) ✓';
      } else if (cnicFrontUrl != null && cnicBackUrl != null) {
        return 'CNIC uploaded - Auto-verified ✓';
      } else {
        return 'Not verified (Upload CNIC)';
      }
    } else {
      if (isVerified == true) {
        return 'Verified by NGO ✓';
      } else if (cnicFrontUrl != null && cnicBackUrl != null) {
        return 'CNIC uploaded - Pending NGO verification ⏳';
      } else {
        return 'Not verified';
      }
    }
  }

  String? getSafeProfileImageUrl() {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return null;
    }

    // Ensure Cloudinary URLs have https
    if (profileImageUrl!.contains('cloudinary.com')) {
      String url = profileImageUrl!;
      if (url.startsWith('http://')) {
        url = url.replaceFirst('http://', 'https://');
      }
      return url;
    }

    return profileImageUrl;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType,
      'password': password,
      'accountType': accountType,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'cnicFrontUrl': cnicFrontUrl,
      'cnicBackUrl': cnicBackUrl,
      'createdAt': createdAt.toIso8601String(),
      'familySize': familySize,
      'monthlyIncome': monthlyIncome,
      'specialNeeds': specialNeeds,
      'totalDonations': totalDonations,
      'rating': rating,
      'isVerified': isVerified,
      'cnicVerified': cnicVerified,
      'authProvider': authProvider,
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper functions for safe parsing
    double? toDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? toIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    String toStringNonNull(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    String? toStringNullable(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    bool toBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value == 1;
      return defaultValue;
    }

    DateTime? toDateTimeNullable(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Parse latitude and longitude
    final latValue = json['latitude'];
    final lngValue = json['longitude'];
    LatLng? location;

    if (latValue != null && lngValue != null) {
      final lat = toDoubleNullable(latValue);
      final lng = toDoubleNullable(lngValue);
      if (lat != null && lng != null) {
        location = LatLng(lat, lng);
      }
    }

    return User(
      id: toStringNonNull(json['id'], ''),
      name: toStringNonNull(json['name'], ''),
      email: toStringNonNull(json['email'], ''),
      phone: toStringNonNull(json['phone'], ''),
      userType: toStringNonNull(json['userType'], ''),
      password: toStringNullable(json['password']),
      accountType: toStringNullable(json['accountType']),
      location: location,
      address: toStringNullable(json['address']),
      profileImageUrl: toStringNullable(json['profileImageUrl']),
      cnicFrontUrl: toStringNullable(json['cnicFrontUrl']),
      cnicBackUrl: toStringNullable(json['cnicBackUrl']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      familySize: toIntNullable(json['familySize']),
      monthlyIncome: toStringNullable(json['monthlyIncome']),
      specialNeeds: toStringNullable(json['specialNeeds']),
      totalDonations: toIntNullable(json['totalDonations']) ?? 0,
      rating: toDoubleNullable(json['rating']) ?? 0.0,
      isVerified: toBool(json['isVerified'], false),
      cnicVerified: toBool(json['cnicVerified'], false),
      authProvider: toStringNullable(json['authProvider']) ?? 'email',
      fcmToken: toStringNullable(json['fcmToken']),
      fcmTokenUpdatedAt: toDateTimeNullable(json['fcmTokenUpdatedAt']),
    );
  }

  factory User.fromFirebaseUser(
      auth.UserCredential credential, String userType,
      {String? phone, String? name}) {
    final firebaseUser = credential.user!;
    return User(
      id: firebaseUser.uid,
      name: name ??
          firebaseUser.displayName ??
          (firebaseUser.email != null
              ? firebaseUser.email!.split('@')[0]
              : 'User'),
      email: firebaseUser.email ?? '',
      phone: phone ?? '',
      userType: userType,
      profileImageUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
      authProvider:
      credential.credential?.providerId == 'google.com' ? 'google' : 'email',
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '816352002695-jef42n9jil8b9ppntb0kcup27ufkk8bs.apps.googleusercontent.com',
  );
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  User? _currentUser;

  DatabaseReference get _usersRef => _databaseRef.child('users');

  bool _isValidGmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    return regex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&]).{8,}$');
    return regex.hasMatch(password);
  }

  bool _isValidPhone(String phone) {
    return phone.length == 11 && phone.startsWith('03');
  }

  // Check if donor needs CNIC verification
  bool needsCnicVerification(User user) {
    if (user.userType == 'Donor') {
      // Return false if already verified
      if (user.isVerified == true) {
        return false;
      }
      // Otherwise check if CNIC is missing
      return user.cnicFrontUrl == null ||
          user.cnicFrontUrl!.isEmpty ||
          user.cnicBackUrl == null ||
          user.cnicBackUrl!.isEmpty;
    }
    return false;
  }

  // SIGN IN METHOD (EMAIL/PASSWORD)
  Future<User> signIn(String email, String password, String userType) async {
    try {
      print('=== EMAIL SIGN IN STARTED ===');
      print('Email: $email, User Type: $userType');

      if (!_isValidGmail(email)) {
        throw Exception(
            'Please enter a valid Gmail address (example@gmail.com)');
      }

      if (password.trim().isEmpty) {
        throw Exception('Please enter your password');
      }

      final auth.UserCredential userCredential =
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user!;
      print('✓ Firebase Auth successful - UID: ${firebaseUser.uid}');

      User user;
      final userSnapshot = await _usersRef.child(firebaseUser.uid).once();

      if (!userSnapshot.snapshot.exists) {
        print('User not found by UID, searching by email...');

        final emailSnapshot = await _usersRef
            .orderByChild('email')
            .equalTo(email.trim())
            .once();

        if (!emailSnapshot.snapshot.exists) {
          await _firebaseAuth.signOut();
          throw Exception(
              'Account data not found in database. Please sign up again.');
        }

        final usersMap =
        Map<String, dynamic>.from(emailSnapshot.snapshot.value as Map);
        final entry = usersMap.entries.first;
        final userData = Map<String, dynamic>.from(entry.value as Map);
        user = User.fromJson(userData);

        print('✓ User found by email: ${user.email}');
      } else {
        final userData =
        Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
        user = User.fromJson(userData);
        print('✓ User found by UID: ${user.email}');
      }

      print('User data loaded:');
      print('- Name: ${user.name}');
      print('- Email: ${user.email}');
      print('- Profile Image URL: ${user.profileImageUrl}');
      print('- User Type: ${user.userType}');

      if (user.userType != userType) {
        await _firebaseAuth.signOut();
        throw Exception(
            "This account is registered as ${user.userType}. Please select '${user.userType}' to login.");
      }


      final freshSnapshot = await _usersRef.child(user.id).once();
      if (freshSnapshot.snapshot.exists) {
        final freshData = Map<String, dynamic>.from(freshSnapshot.snapshot.value as Map);
        user = User.fromJson(freshData);
        print('✓ Latest user data loaded');
        print('✓ Profile image URL: ${user.profileImageUrl ?? "None"}');
      }

      _currentUser = user;

      try {
        await NotificationService().registerUser(
          userId: user.id,
          userType: user.userType,
        );
      } catch (e) {
        print('Warning: Failed to register for notifications: $e');

      }

      print('=== EMAIL LOGIN SUCCESSFUL ===');
      print('Logged in as: ${user.email} (${user.userType})');
      print('Profile image: ${user.profileImageUrl ?? "No image"}');

      return _currentUser!;
    } on auth.FirebaseAuthException catch (e) {
      print('✗ FirebaseAuthException: ${e.code}');
      print('Message: ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email. Please sign up first.');
        case 'wrong-password':
          throw Exception('Incorrect password. Please try again.');
        case 'invalid-credential':
          throw Exception('Invalid email or password combination.');
        case 'invalid-email':
          throw Exception('Invalid email address format.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please wait and try again.');
        case 'network-request-failed':
          throw Exception('Network error. Check your connection.');
        case 'operation-not-allowed':
          throw Exception('Email/password login is not enabled.');
        default:
          throw Exception('Login failed: ${e.message ?? "Unknown error"}');
      }
    } catch (e) {
      print('✗ Sign In Error: $e');

      if (e.toString().contains('Exception:')) {
        rethrow;
      }

      throw Exception('Login failed. Please try again.');
    }
  }

  // SIGN UP METHOD (EMAIL/PASSWORD)
  Future<User> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
    String? accountType,
    int? familySize,
    String? monthlyIncome,
  }) async {
    try {
      print('=== EMAIL SIGN UP STARTED ===');
      print('Email: $email, User Type: $userType');

      if (!_isValidGmail(email)) {
        throw Exception(
            'Please enter a valid Gmail address (example@gmail.com)');
      }

      if (!_isValidPassword(password)) {
        throw Exception(
            'Password must be at least 8 characters with letters, numbers, and special characters (@\$!%*#?&)');
      }

      if (!_isValidPhone(phone)) {
        throw Exception(
            'Phone number must be 11 digits starting with 03 (e.g., 03123456789)');
      }

      if (name.trim().isEmpty) {
        throw Exception('Please enter your full name');
      }

      if (userType == 'Donor') {
        if (accountType == null ||
            !['Individual', 'Organization'].contains(accountType)) {
          throw Exception(
              'Donor must select either Individual or Organization account type');
        }
      } else if (userType == 'Acceptor') {
        if (familySize == null || familySize < 1) {
          throw Exception('Please enter a valid family size (minimum 1 member)');
        }
        if (monthlyIncome == null) {
          throw Exception('Please select your monthly income range');
        }
      }

      final emailExists = await userExists(email);
      if (emailExists) {
        throw Exception(
            'Email already registered. Please use a different email or log in.');
      }

      final auth.UserCredential userCredential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user!;
      print('Firebase user created: ${firebaseUser.uid}');

      await firebaseUser.updateDisplayName(name);

      final newUser = User(
        id: firebaseUser.uid,
        name: name,
        email: email,
        password: password,
        phone: phone,
        userType: userType,
        accountType: accountType,
        createdAt: DateTime.now(),
        familySize: familySize,
        monthlyIncome: monthlyIncome,
        totalDonations: 0,
        rating: 0.0,
        isVerified: false,
        cnicVerified: false,
        authProvider: 'email',
      );

      await _usersRef.child(newUser.id).set(newUser.toJson());

      _currentUser = newUser;

      try {
        await NotificationService().registerUser(
          userId: newUser.id,
          userType: newUser.userType,
        );
      } catch (e) {
        print('Warning: Failed to register for notifications: $e');

      }

      print('=== EMAIL SIGN UP SUCCESSFUL ===');
      print('New user created: ${newUser.email}, Type: ${newUser.userType}');

      return _currentUser!;
    } on auth.FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Use a stronger password.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception(
            'Email already registered. Please log in or use a different email.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address format.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email/password accounts are not enabled.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Check your internet connection.');
      }
      throw Exception('Sign up failed: ${e.message}');
    } catch (e) {
      print('Sign Up Error: $e');
      throw Exception('Sign up failed. Please try again.');
    }
  }

  // GOOGLE SIGN IN METHOD
  Future<User> signInWithGoogle(String userType) async {
    try {
      print('=== GOOGLE SIGN IN STARTED ===');
      print('User Type: $userType');

      await _googleSignIn.signOut();
      print('✓ Cleared existing Google session');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      print('✓ Google account selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens from Google');
      }

      print('✓ Authentication tokens received');

      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth.UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user!;

      print('✓ Firebase Auth successful - UID: ${firebaseUser.uid}');

      final userSnapshot = await _usersRef.child(firebaseUser.uid).once();

      User user;
      if (!userSnapshot.snapshot.exists) {
        print('User not found by UID, searching by email...');

        final emailSnapshot = await _usersRef
            .orderByChild('email')
            .equalTo(googleUser.email)
            .once();

        if (!emailSnapshot.snapshot.exists) {
          await _googleSignIn.signOut();
          await _firebaseAuth.signOut();
          throw Exception('No account found. Please sign up with Google first.');
        }

        final usersMap =
        Map<String, dynamic>.from(emailSnapshot.snapshot.value as Map);
        final entry = usersMap.entries.first;
        final userData = Map<String, dynamic>.from(entry.value as Map);
        user = User.fromJson(userData);

        print('✓ User found by email: ${user.email}');
      } else {
        final userData =
        Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
        user = User.fromJson(userData);
        print('✓ User found by UID: ${user.email}');
      }

      print('User data loaded:');
      print('- Name: ${user.name}');
      print('- Email: ${user.email}');
      print('- Profile Image URL: ${user.profileImageUrl}');
      print('- User Type: ${user.userType}');

      if (user.userType != userType) {
        await _googleSignIn.signOut();
        await _firebaseAuth.signOut();
        throw Exception(
            "This Google account is registered as ${user.userType}. Please select '${user.userType}' to login.");
      }


      print('Re-fetching latest user data from database...');
      final freshSnapshot = await _usersRef.child(user.id).once();
      if (freshSnapshot.snapshot.exists) {
        final freshData = Map<String, dynamic>.from(freshSnapshot.snapshot.value as Map);
        user = User.fromJson(freshData);
        print('✓ Latest user data loaded with profileImageUrl: ${user.profileImageUrl}');
      }

      if (firebaseUser.photoURL != null &&
          (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)) {
        user.profileImageUrl = firebaseUser.photoURL;
        await _usersRef
            .child(user.id)
            .update({'profileImageUrl': user.profileImageUrl});
        print('✓ Updated profile image from Google');
      }

      user.authProvider = 'google';
      _currentUser = user;

      try {
        await NotificationService().registerUser(
          userId: user.id,
          userType: user.userType,
        );
      } catch (e) {
        print('Warning: Failed to register for notifications: $e');
      }

      print('=== GOOGLE LOGIN SUCCESSFUL ===');
      print('Logged in as: ${user.email} (${user.userType})');
      print('Profile image: ${user.profileImageUrl ?? "No image"}');

      return _currentUser!;
    } on auth.FirebaseAuthException catch (e) {
      print('✗ FirebaseAuthException: ${e.code}');
      print('Message: ${e.message}');

      await _googleSignIn.signOut();

      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception(
              'This email is already registered with email/password. Please use email login.');
        case 'invalid-credential':
          throw Exception('Invalid Google credentials. Please try again.');
        case 'operation-not-allowed':
          throw Exception('Google Sign-In is not enabled.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'user-not-found':
          throw Exception('No account found. Please sign up first.');
        case 'network-request-failed':
          throw Exception('Network error. Check your connection.');
        default:
          throw Exception('Google Sign-In failed: ${e.message ?? "Unknown error"}');
      }
    } catch (e) {
      print('✗ Google Sign In Error: $e');

      await _googleSignIn.signOut();

      if (e.toString().contains('Exception:')) {
        rethrow;
      }

      if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      }

      throw Exception('Google Sign-In failed. Please try again.');
    }
  }

  // GOOGLE SIGN UP METHOD
  Future<User> signUpWithGoogle({
    required String userType,
    required String phone,
    String? accountType,
    int? familySize,
    String? monthlyIncome,
  }) async {
    try {
      print('=== GOOGLE SIGN UP STARTED ===');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign up cancelled');
      }

      print('Google User: ${googleUser.email}');

      final emailExists = await userExists(googleUser.email);
      if (emailExists) {
        throw Exception(
            'Account already exists with this email. Please log in instead.');
      }

      if (!_isValidPhone(phone)) {
        throw Exception(
            'Phone number must be 11 digits starting with 03 (e.g., 03123456789)');
      }

      if (userType == 'Donor') {
        if (accountType == null ||
            !['Individual', 'Organization'].contains(accountType)) {
          throw Exception(
              'Donor must select either Individual or Organization account type');
        }
      } else if (userType == 'Acceptor') {
        if (familySize == null || familySize < 1) {
          throw Exception('Please enter a valid family size (minimum 1 member)');
        }
        if (monthlyIncome == null) {
          throw Exception('Please select your monthly income range');
        }
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth.UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user!;

      final newUser = User(
        id: firebaseUser.uid,
        name: googleUser.displayName ?? firebaseUser.email!.split('@')[0],
        email: firebaseUser.email!,
        phone: phone,
        userType: userType,
        accountType: accountType,
        profileImageUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        familySize: familySize,
        monthlyIncome: monthlyIncome,
        totalDonations: 0,
        rating: 0.0,
        isVerified: false,
        cnicVerified: false,
        authProvider: 'google',
      );

      await _usersRef.child(newUser.id).set(newUser.toJson());
      _currentUser = newUser;

      try {
        await NotificationService().registerUser(
          userId: newUser.id,
          userType: newUser.userType,
        );
      } catch (e) {
        print('Warning: Failed to register for notifications: $e');
      }

      print('=== GOOGLE SIGN UP SUCCESSFUL ===');
      print('New user created: ${newUser.email}, Type: ${newUser.userType}');
      print('Profile image saved: ${newUser.profileImageUrl}');

      return _currentUser!;
    } on auth.FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
            'An account already exists with this email. Please log in instead.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email already registered. Please log in.');
      }
      throw Exception('Sign up failed: ${e.message}');
    } catch (e) {
      print('Google Sign-Up Error: $e');
      throw Exception('Google Sign-Up failed. Please try again.');
    }
  }


  // HELPER METHODS
  Future<bool> userExists(String email) async {
    try {
      final snapshot =
      await _usersRef.orderByChild('email').equalTo(email).once();
      return snapshot.snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // PROFILE UPDATE METHOD
  Future<void> updateProfile(User updatedUser) async {
    try {
      print('=== UPDATING PROFILE ===');
      print('User: ${updatedUser.name}, Type: ${updatedUser.userType}');

      // Check if CNIC was just uploaded
      final cnicJustUploaded = updatedUser.cnicFrontUrl != null &&
          updatedUser.cnicFrontUrl!.isNotEmpty &&
          updatedUser.cnicBackUrl != null &&
          updatedUser.cnicBackUrl!.isNotEmpty &&
          (updatedUser.cnicVerified == false ||
              updatedUser.cnicVerified == null);

      final fullJson = updatedUser.toJson();
      final safeUpdates = <String, dynamic>{};
      fullJson.forEach((key, value) {
        if (value != null) {
          safeUpdates[key] = value;
        }
      });

      if (cnicJustUploaded && updatedUser.userType == 'Donor') {
        safeUpdates['cnicVerified'] = true;
        safeUpdates['isVerified'] = true;
        print('🎯 Auto-verifying donor with CNIC upload');
      }

      await _usersRef.child(updatedUser.id).update(safeUpdates);
      print('✓ Profile updated in database');

      final freshSnapshot = await _usersRef.child(updatedUser.id).once();
      if (freshSnapshot.snapshot.exists) {
        final freshData = Map<String, dynamic>.from(freshSnapshot.snapshot.value as Map);
        final freshUser = User.fromJson(freshData);
        _currentUser = freshUser;

        if (cnicJustUploaded && updatedUser.userType == 'Donor') {
          print('✓ Donor verification completed automatically');
        }
      }

      // Create verification request only for acceptors with CNIC
      if (updatedUser.userType == 'Acceptor' &&
          updatedUser.cnicFrontUrl != null &&
          updatedUser.cnicBackUrl != null &&
          updatedUser.location != null) {
        await _createVerificationRequestIfNeeded(updatedUser);
      }

      print('=== PROFILE UPDATE COMPLETE ===');
    } catch (e) {
      print('✗ Error updating profile: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception("Failed to update profile: $e");
    }
  }

  // Create verification request for acceptor
  Future<void> _createVerificationRequestIfNeeded(User acceptor) async {
    try {
      print('=== CREATING VERIFICATION REQUEST ===');
      print('Acceptor: ${acceptor.name}');
      print('Acceptor ID: ${acceptor.id}');
      print('Location: ${acceptor.location?.latitude}, ${acceptor.location?.longitude}');

      // Check if verification request already exists
      final verificationsRef = _databaseRef.child('verification_requests');
      final existingRequest = await verificationsRef
          .orderByChild('acceptorId')
          .equalTo(acceptor.id)
          .once();

      if (existingRequest.snapshot.exists) {
        print('✓ Verification request already exists');
        return;
      }

      // Create verification request
      final requestId = 'ver_${DateTime.now().millisecondsSinceEpoch}_${acceptor.id}';
      print('Creating request with ID: $requestId');

      final requestData = {
        'id': requestId,
        'acceptorId': acceptor.id,
        'acceptorName': acceptor.name,
        'acceptorEmail': acceptor.email,
        'acceptorPhone': acceptor.phone,
        'acceptorAddress': acceptor.address ?? '',
        'latitude': acceptor.location!.latitude,
        'longitude': acceptor.location!.longitude,
        'cnicFrontUrl': acceptor.cnicFrontUrl,
        'cnicBackUrl': acceptor.cnicBackUrl,
        'familySize': acceptor.familySize,
        'monthlyIncome': acceptor.monthlyIncome,
        'specialNeeds': acceptor.specialNeeds,
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Save the verification request first
      await verificationsRef.child(requestId).set(requestData);
      print('✓ Verification request saved to Firebase: $requestId');

      // IMPORTANT: Wait a moment to ensure Firebase write is committed
      await Future.delayed(const Duration(milliseconds: 500));


      print('🔄 Using NGOService for assignment with verification');
      final ngoService = NGOService();
      await ngoService.assignVerificationRequestToNGO(requestId);

      // IMPORTANT: Wait again to ensure assignment is committed
      await Future.delayed(const Duration(milliseconds: 500));

      // Send notifications to NGOs via Supabase
      await _notifyNGOsOfNewVerification(acceptor, requestId);

      print('✅ Verification request creation complete');

    } catch (e) {
      print('✗ Error creating verification request: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _notifyNGOsOfNewVerification(User acceptor, String requestId) async {
    try {
      print('=== NOTIFYING NGOs OF NEW VERIFICATION VIA SUPABASE ===');
      print('Request ID: $requestId');

      final ngosRef = _databaseRef.child('ngos');
      final ngosSnapshot = await ngosRef.once();

      if (!ngosSnapshot.snapshot.exists) {
        print('⚠️ No NGOs found in database');
        return;
      }

      final ngosMap = ngosSnapshot.snapshot.value as Map<dynamic, dynamic>?;
      if (ngosMap == null || ngosMap.isEmpty) {
        print('⚠️ NGO map is empty');
        return;
      }

      List<String> ngoIds = [];
      ngosMap.forEach((ngoId, ngoData) {
        ngoIds.add(ngoId.toString());
      });

      print('Found ${ngoIds.length} NGOs to notify');

      // Use SupabaseNotificationHelper from supabase_notification_service.dart
      await SupabaseNotificationHelper.notifyNewVerificationRequest(
        ngoIds: ngoIds,
        userName: acceptor.name,
        userType: 'Acceptor',
      );

      print('✅ All NGOs notified successfully via Supabase');
    } catch (e) {
      print('✗ Error notifying NGOs: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
  // IMAGE UPLOAD METHODS
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      final imageUrl =
      await _cloudinaryService.uploadProfileImage(imageFile, _currentUser!.id);

      if (imageUrl != null) {
        await _usersRef
            .child(_currentUser!.id)
            .update({'profileImageUrl': imageUrl});

        _currentUser!.profileImageUrl = imageUrl;

        print('Profile image uploaded successfully: $imageUrl');
        return imageUrl;
      }
      return null;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<String?> pickAndUploadProfileImage() async {
    try {
      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      final imageUrl =
      await _cloudinaryService.pickAndUploadProfileImage(_currentUser!.id);

      if (imageUrl != null) {
        await _usersRef
            .child(_currentUser!.id)
            .update({'profileImageUrl': imageUrl});

        _currentUser!.profileImageUrl = imageUrl;

        print('Profile image uploaded successfully: $imageUrl');
        return imageUrl;
      }
      return null;
    } catch (e) {
      print('Error picking profile image: $e');
      return null;
    }
  }

  Future<void> updateProfileImageUrl(String userId, String imageUrl) async {
    try {
      print('=== UPDATING PROFILE IMAGE URL ===');
      print('User ID: $userId');
      print('Image URL: $imageUrl');

      // Update in Firebase
      await _databaseRef.child('users').child(userId).update({
        'profileImageUrl': imageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('✓ Profile image URL updated in database');

      // Immediately update the local user object
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser!.profileImageUrl = imageUrl;
        print('✓ Local user object updated with new image URL: $imageUrl');
      }

    } catch (e, stackTrace) {
      print('✗ Error updating profile image URL: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // CNIC UPLOAD METHODS
  Future<Map<String, String?>> uploadCnicImages(
      File frontImage, File backImage) async {
    try {
      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      print('=== UPLOADING CNIC IMAGES ===');
      print('User Type: ${_currentUser!.userType}');

      final urls = await _cloudinaryService.uploadCnicImages(
        frontImage,
        backImage,
        _currentUser!.id,
      );

      if (urls['frontUrl'] != null && urls['backUrl'] != null) {
        // Auto-verify donors immediately, keep acceptors pending
        final isDonor = _currentUser!.userType == 'Donor';
        final updates = {
          'cnicFrontUrl': urls['frontUrl'],
          'cnicBackUrl': urls['backUrl'],
          'cnicVerified': true,
        };

        // Auto-verify donors upon CNIC upload
        if (isDonor) {
          updates['isVerified'] = true;
          print('🎯 Auto-verifying donor after CNIC upload');
        }

        await _usersRef.child(_currentUser!.id).update(updates);

        _currentUser!.cnicFrontUrl = urls['frontUrl'];
        _currentUser!.cnicBackUrl = urls['backUrl'];
        _currentUser!.cnicVerified = true;

        if (isDonor) {
          _currentUser!.isVerified = true;
          print('✓ Donor verified automatically after CNIC upload');
        }

        if (!isDonor && _currentUser!.location != null) {
          await _createVerificationRequestIfNeeded(_currentUser!);
        }

        return urls;
      }
      return {};
    } catch (e) {
      print('Error uploading CNIC images: $e');
      return {};
    }
  }

  Future<Map<String, String?>> pickAndUploadCnicImages() async {
    try {
      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      final urls = await _cloudinaryService.pickAndUploadCnicImages(_currentUser!.id);

      if (urls['frontUrl'] != null && urls['backUrl'] != null) {
        final isDonor = _currentUser!.userType == 'Donor';
        final updates = {
          'cnicFrontUrl': urls['frontUrl'],
          'cnicBackUrl': urls['backUrl'],
          'cnicVerified': true,
        };

        if (isDonor) {
          updates['isVerified'] = true;
        }

        await _usersRef.child(_currentUser!.id).update(updates);

        _currentUser!.cnicFrontUrl = urls['frontUrl'];
        _currentUser!.cnicBackUrl = urls['backUrl'];
        _currentUser!.cnicVerified = true;

        if (isDonor) {
          _currentUser!.isVerified = true;
          print('✓ Donor auto-verified after CNIC upload');
        }

        if (!isDonor && _currentUser!.location != null) {
          await _createVerificationRequestIfNeeded(_currentUser!);
        }

        return urls;
      }
      return {};
    } catch (e) {
      print('Error picking CNIC images: $e');
      return {};
    }
  }

  // USER DATA REFRESH METHODS
  Future<void> refreshUserDataCompletely() async {
    print('=== COMPLETE USER DATA REFRESH ===');

    try {
      final user = _currentUser;
      if (user == null) {
        print('✗ No current user to refresh');
        return;
      }

      print('Completely refreshing data for user: ${user.id}');

      // Get fresh data from Firebase
      final userRef = _databaseRef.child('users').child(user.id);
      final userSnapshot = await userRef.once();

      if (userSnapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);

        print('Complete raw user data from Firebase:');
        print('profileImageUrl: ${userData['profileImageUrl']}');
        print('cnicFrontUrl: ${userData['cnicFrontUrl']}');
        print('cnicBackUrl: ${userData['cnicBackUrl']}');
        print('name: ${userData['name']}');
        print('email: ${userData['email']}');
        print('userType: ${userData['userType']}');

        // Create a completely new user object with all data
        final refreshedUser = User.fromJson(userData);
        _currentUser = refreshedUser;

        print('✓ Complete user data refreshed successfully');
        print('Full user object created with profileImageUrl: ${_currentUser?.profileImageUrl}');
      } else {
        print('✗ User not found in database');
      }
    } catch (e, stackTrace) {
      print('✗ Error in complete refresh: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> refreshUserData() async {
    print('=== REFRESHING USER DATA ===');

    try {
      final user = _currentUser;
      if (user == null) {
        print('✗ No current user to refresh');
        return;
      }

      print('Refreshing data for user: ${user.id}');

      // Get fresh data from Firebase
      final userRef = _databaseRef.child('users').child(user.id);
      final userSnapshot = await userRef.once();

      if (userSnapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);

        print('Raw user data from Firebase:');
        print('profileImageUrl: ${userData['profileImageUrl']}');
        print('cnicFrontUrl: ${userData['cnicFrontUrl']}');
        print('cnicBackUrl: ${userData['cnicBackUrl']}');

        // Update the current user object with fresh data
        if (userData['profileImageUrl'] != null) {
          _currentUser!.profileImageUrl = userData['profileImageUrl'] as String?;
        }
        if (userData['cnicFrontUrl'] != null) {
          _currentUser!.cnicFrontUrl = userData['cnicFrontUrl'] as String?;
        }
        if (userData['cnicBackUrl'] != null) {
          _currentUser!.cnicBackUrl = userData['cnicBackUrl'] as String?;
        }
        if (userData['name'] != null) {
          _currentUser!.name = userData['name'] as String;
        }
        if (userData['phone'] != null) {
          _currentUser!.phone = userData['phone'] as String;
        }
        if (userData['address'] != null) {
          _currentUser!.address = userData['address'] as String?;
        }
        if (userData['latitude'] != null && userData['longitude'] != null) {
          _currentUser!.location = LatLng(
            (userData['latitude'] as num).toDouble(),
            (userData['longitude'] as num).toDouble(),
          );
        }
        if (userData['isVerified'] != null) {
          _currentUser!.isVerified = userData['isVerified'] as bool?;
        }
        if (userData['cnicVerified'] != null) {
          _currentUser!.cnicVerified = userData['cnicVerified'] as bool?;
        }

        print('✓ User data refreshed successfully');
        print('Updated profileImageUrl: ${_currentUser?.profileImageUrl}');
      } else {
        print('✗ User not found in database');
      }
    } catch (e, stackTrace) {
      print('✗ Error refreshing user data: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // PASSWORD AND STATISTICS METHODS
  Future<void> updateUserPassword(String userId, String newPassword) async {
    try {
      print('=== UPDATING USER PASSWORD IN DATABASE ===');
      print('User ID: $userId');

      await _usersRef.child(userId).update({
        'password': newPassword,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update local user if it's the current user
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser!.password = newPassword;
      }

      print('✓ Password updated in database');

    } catch (e, stackTrace) {
      print('✗ Error updating password in database: $e');
      print('Stack trace: $stackTrace');

      // This is just for database record keeping
    }
  }

  Future<void> updateUserStatistics(String userId,
      {int? totalDonations, double? rating}) async {
    try {
      final updates = <String, dynamic>{};
      if (totalDonations != null) {
        updates['totalDonations'] = totalDonations;
      }
      if (rating != null) {
        updates['rating'] = rating;
      }

      await _usersRef.child(userId).update(updates);

      if (_currentUser?.id == userId) {
        if (totalDonations != null) _currentUser!.totalDonations = totalDonations;
        if (rating != null) _currentUser!.rating = rating;
      }
    } catch (e) {
      print('Error updating user statistics: $e');
    }
  }

  Future<void> verifyDonor(String userId) async {
    try {
      await _usersRef.child(userId).update({
        'isVerified': true,
      });

      if (_currentUser?.id == userId) {
        _currentUser!.isVerified = true;
      }
    } catch (e) {
      print('Error verifying donor: $e');
    }
  }

  Future<void> updateAcceptorVerificationStatus(String acceptorId, bool isVerified) async {
    try {
      await _usersRef.child(acceptorId).update({
        'isVerified': isVerified,
        'cnicVerified': isVerified,
      });

      // If this is the current user, update local state
      if (_currentUser?.id == acceptorId) {
        _currentUser!.isVerified = isVerified;
        _currentUser!.cnicVerified = isVerified;
      }

      print('✓ Acceptor verification status updated: isVerified = $isVerified');
    } catch (e) {
      print('✗ Error updating acceptor verification status: $e');
      throw Exception('Failed to update verification status');
    }
  }

  // Check if profile needs completion
  bool needsProfileCompletion(User user) {
    if (user.userType == 'Donor') {
      // Donors need CNIC for verification
      return user.cnicFrontUrl == null ||
          user.cnicFrontUrl!.isEmpty ||
          user.cnicBackUrl == null ||
          user.cnicBackUrl!.isEmpty;
    } else {
      // Acceptors need CNIC + address + location
      return !user.isProfileComplete;
    }
  }



  Future<String?> getSavedFCMToken(String userId) async {
    try {
      final snapshot = await _databaseRef.child('users').child(userId).child('fcmToken').once();
      return snapshot.snapshot.value as String?;
    } catch (e) {
      print('✗ Error getting saved FCM token: $e');
      return null;
    }
  }
  // SIGN OUT METHOD
  Future<void> signOut() async {
    try {
      // Clear FCM token and unregister from notifications if user is logged in
      if (_currentUser != null) {
        try {
          await NotificationService().unregisterUser(_currentUser!.id);
          print('✓ Unregistered from notifications');
        } catch (e) {
          print('⚠️ Error unregistering from notifications: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error clearing FCM during signout: $e');
    }

    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    _currentUser = null;
    print('✓ User signed out successfully');
  }

  // GETTERS AND DEBUG METHODS
  User? get currentUser => _currentUser;
  void setCurrentUser(User user) => _currentUser = user;
  void clearCurrentUser() => _currentUser = null;

  Future<void> debugAuthState() async {
    print('=== DEBUG AUTH STATE ===');
    print('Firebase Auth Current User: ${_firebaseAuth.currentUser?.email}');
    print('Local Current User: ${_currentUser?.email}');
    print('Local User Type: ${_currentUser?.userType}');
    print('Profile Image URL: ${_currentUser?.profileImageUrl}');
    print('Auth Provider: ${_currentUser?.authProvider}');
    print('FCM Token: ${_currentUser?.fcmToken?.substring(0, 20)}...');

    try {
      final snapshot = await _usersRef.child(_currentUser?.id ?? '').once();
      if (snapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        print('Database user data:');
        print('- Name: ${userData['name']}');
        print('- Email: ${userData['email']}');
        print('- Profile Image URL: ${userData['profileImageUrl']}');
        print('- User Type: ${userData['userType']}');
        print('- FCM Token: ${userData['fcmToken'] != null ? "${(userData['fcmToken'] as String).substring(0, 20)}..." : "None"}');
      } else {
        print('User not found in database');
      }
    } catch (e) {
      print('Database error: $e');
    }
    print('=== END DEBUG ===');
  }

  // DISTANCE CALCULATION
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _assignToNearestNGO(String requestId, LatLng acceptorLocation) async {
    try {
      print('=== ASSIGNING TO NEAREST NGO ===');
      print('Request ID: $requestId');
      print('Acceptor Location: ${acceptorLocation.latitude}, ${acceptorLocation.longitude}');

      // Get all NGOs
      final DatabaseReference ngosRef = _databaseRef.child('ngos');
      final ngosSnapshot = await ngosRef.once();

      if (!ngosSnapshot.snapshot.exists) {
        print('⚠️ No NGOs found in database');
        return;
      }

      final ngosMap = ngosSnapshot.snapshot.value as Map<dynamic, dynamic>?;

      if (ngosMap == null || ngosMap.isEmpty) {
        print('⚠️ NGO map is empty');
        return;
      }

      print('Found ${ngosMap.length} NGOs');

      // Calculate distances
      double minDistance = double.infinity;
      Map<dynamic, dynamic>? nearestNGO;
      String? nearestNGOId;

      ngosMap.forEach((ngoId, ngoData) {
        final data = ngoData as Map<dynamic, dynamic>;

        // Handle latitude/longitude safely
        final ngoLatValue = data['latitude'];
        final ngoLngValue = data['longitude'];

        if (ngoLatValue == null || ngoLngValue == null) {
          print('⚠️ NGO ${data['name']} has null coordinates, skipping');
          return;
        }

        // Convert to double safely
        double? ngoLat;
        double? ngoLng;

        if (ngoLatValue is double) {
          ngoLat = ngoLatValue;
        } else if (ngoLatValue is int) {
          ngoLat = ngoLatValue.toDouble();
        } else if (ngoLatValue is String) {
          ngoLat = double.tryParse(ngoLatValue);
        }

        if (ngoLngValue is double) {
          ngoLng = ngoLngValue;
        } else if (ngoLngValue is int) {
          ngoLng = ngoLngValue.toDouble();
        } else if (ngoLngValue is String) {
          ngoLng = double.tryParse(ngoLngValue);
        }

        if (ngoLat == null || ngoLng == null) {
          print('⚠️ NGO ${data['name']} has invalid coordinates, skipping');
          return;
        }

        final distance = _calculateDistance(
          acceptorLocation.latitude,
          acceptorLocation.longitude,
          ngoLat,
          ngoLng,
        );

        final ngoName = data['name']?.toString() ?? 'Unknown NGO';
        print('NGO: $ngoName, Distance: ${distance.toStringAsFixed(2)} km');

        if (distance < minDistance) {
          minDistance = distance;
          nearestNGO = data;
          nearestNGOId = ngoId.toString();
        }
      });

      if (nearestNGO == null || nearestNGOId == null || minDistance == double.infinity) {
        print('✗ Could not find nearest NGO');
        return;
      }


      final Map<dynamic, dynamic> selectedNGO = nearestNGO!;
      final String selectedNGOId = nearestNGOId!;

      final nearestNGOName = selectedNGO['name']?.toString() ?? 'Unknown NGO';
      print('✓ Nearest NGO: $nearestNGOName (${minDistance.toStringAsFixed(2)} km)');
      print('✓ NGO ID: $selectedNGOId');


      final expiresAt = DateTime.now().add(const Duration(days: 2));

      final DatabaseReference verificationsRef = _databaseRef.child('verification_requests');

      final assignmentData = {
        'status': 'Assigned',  // This should be exactly "Assigned" (capital A)
        'assignedNgoId': selectedNGOId,      // CORRECT - using the ID we stored separately
        'assignedNgoName': nearestNGOName,
        'assignedAt': DateTime.now().toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

      await verificationsRef.child(requestId).update(assignmentData);
      print('✓ Request assigned to $nearestNGOName');
      print('✓ Assignment data: $assignmentData');

      final pendingCountValue = selectedNGO['pendingCount'];
      int currentPendingCount = 0;

      if (pendingCountValue is int) {
        currentPendingCount = pendingCountValue;
      } else if (pendingCountValue is double) {
        currentPendingCount = pendingCountValue.toInt();
      } else if (pendingCountValue is String) {
        currentPendingCount = int.tryParse(pendingCountValue) ?? 0;
      }

      await ngosRef.child(selectedNGOId).update({
        'pendingCount': currentPendingCount + 1,
      });

      print('✓ NGO pending count updated: ${currentPendingCount + 1}');
      print('=== ASSIGNMENT COMPLETE ===');

    } catch (e) {
      print('✗ Error assigning to NGO: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

}

// LOCATION SERVICE CLASS
class LocationService {
  // Method accepts double parameters directly
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Alternative method that accepts LatLng objects
  static double calculateDistanceFromLatLng(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  static List<User> findNearbyUsers(
      List<User> users, LatLng center, double radiusKm) {
    return users.where((user) {
      if (user.location == null) return false;
      final distance = calculateDistanceFromLatLng(center, user.location!);
      return distance <= radiusKm;
    }).toList();
  }
}