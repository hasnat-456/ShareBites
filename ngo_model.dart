import 'package:google_maps_flutter/google_maps_flutter.dart';

class NGO {
  String id;
  String name;
  String email;
  String phone;
  String address;
  LatLng location;
  String defaultPassword;
  String? currentPassword;
  bool isPasswordChanged;
  DateTime createdAt;
  int verifiedCount;
  int pendingCount;
  int rejectedCount;

  NGO({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.location,
    required this.defaultPassword,
    this.currentPassword,
    this.isPasswordChanged = false,
    required this.createdAt,
    this.verifiedCount = 0,
    this.pendingCount = 0,
    this.rejectedCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'defaultPassword': defaultPassword,
      'currentPassword': currentPassword ?? defaultPassword,
      'isPasswordChanged': isPasswordChanged,
      'createdAt': createdAt.toIso8601String(),
      'verifiedCount': verifiedCount,
      'pendingCount': pendingCount,
      'rejectedCount': rejectedCount,
    };
  }

  factory NGO.fromJson(Map<String, dynamic> json) {
    return NGO(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      defaultPassword: json['defaultPassword'],
      currentPassword: json['currentPassword'],
      isPasswordChanged: json['isPasswordChanged'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      // Firebase returns num, not int — use (as num).toInt() for safety
      verifiedCount: (json['verifiedCount'] as num? ?? 0).toInt(),
      pendingCount: (json['pendingCount'] as num? ?? 0).toInt(),
      rejectedCount: (json['rejectedCount'] as num? ?? 0).toInt(),
    );
  }

  static String validateName(String name) {
    if (name.isEmpty) return 'Name is required';
    if (name.length > 100) return 'Name too long (max 100 characters)';
    return '';
  }

  static String validateAddress(String address) {
    if (address.isEmpty) return 'Address is required';
    if (address.length > 200) return 'Address too long (max 200 characters)';
    return '';
  }

  static String validatePhone(String phone) {
    if (phone.isEmpty) return 'Phone is required';
    if (phone.length > 15) return 'Phone number too long';
    return '';
  }

  static String validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (email.length > 100) return 'Email too long';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    return '';
  }
}