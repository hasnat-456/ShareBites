import 'package:google_maps_flutter/google_maps_flutter.dart';

class DonationItem {
  final String id;
  final String title;
  final String type;
  final String weight;
  final String description;
  final DateTime donationDate;
  final DateTime expiryDate;
  final String priority;
  final String donorName;
  final String donorId;  // ADDED: donorId field
  final String distance;
  final LatLng location;
  final String? foodStatus;

  DonationItem({
    required this.id,
    required this.title,
    required this.type,
    required this.weight,
    required this.description,
    required this.donationDate,
    required this.expiryDate,
    required this.priority,
    required this.donorName,
    required this.donorId,  // ADDED: donorId parameter
    required this.distance,
    required this.location,
    this.foodStatus,
  });
}