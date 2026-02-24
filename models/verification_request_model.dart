import 'package:google_maps_flutter/google_maps_flutter.dart';

class VerificationRequest {
  String id;
  String acceptorId;
  String acceptorName;
  String acceptorEmail;
  String acceptorPhone;
  String acceptorAddress;
  LatLng acceptorLocation;
  String? cnicFrontUrl;
  String? cnicBackUrl;
  int? familySize;
  String? monthlyIncome;
  String? specialNeeds;
  String status; // 'Pending', 'Assigned', 'Verified', 'Rejected'
  String? assignedNgoId;
  String? assignedNgoName;
  DateTime createdAt;
  DateTime? assignedAt;
  DateTime? verifiedAt;
  DateTime? expiresAt;
  String? verifierNotes;
  String? rejectionReason;

  VerificationRequest({
    required this.id,
    required this.acceptorId,
    required this.acceptorName,
    required this.acceptorEmail,
    required this.acceptorPhone,
    required this.acceptorAddress,
    required this.acceptorLocation,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.familySize,
    this.monthlyIncome,
    this.specialNeeds,
    this.status = 'Pending',
    this.assignedNgoId,
    this.assignedNgoName,
    required this.createdAt,
    this.assignedAt,
    this.verifiedAt,
    this.expiresAt,
    this.verifierNotes,
    this.rejectionReason,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isPending => status == 'Pending';
  bool get isAssigned => status == 'Assigned';
  bool get isVerified => status == 'Verified';
  bool get isRejected => status == 'Rejected';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'acceptorId': acceptorId,
      'acceptorName': acceptorName,
      'acceptorEmail': acceptorEmail,
      'acceptorPhone': acceptorPhone,
      'acceptorAddress': acceptorAddress,
      'latitude': acceptorLocation.latitude,
      'longitude': acceptorLocation.longitude,
      'cnicFrontUrl': cnicFrontUrl,
      'cnicBackUrl': cnicBackUrl,
      'familySize': familySize,
      'monthlyIncome': monthlyIncome,
      'specialNeeds': specialNeeds,
      'status': status,
      'assignedNgoId': assignedNgoId,
      'assignedNgoName': assignedNgoName,
      'createdAt': createdAt.toIso8601String(),
      'assignedAt': assignedAt?.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'verifierNotes': verifierNotes,
      'rejectionReason': rejectionReason,
    };
  }

  factory VerificationRequest.fromJson(Map<String, dynamic> json) {
    return VerificationRequest(
      id: json['id'],
      acceptorId: json['acceptorId'],
      acceptorName: json['acceptorName'],
      acceptorEmail: json['acceptorEmail'],
      acceptorPhone: json['acceptorPhone'],
      acceptorAddress: json['acceptorAddress'],
      acceptorLocation: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      cnicFrontUrl: json['cnicFrontUrl'],
      cnicBackUrl: json['cnicBackUrl'],
      familySize: json['familySize'],
      monthlyIncome: json['monthlyIncome'],
      specialNeeds: json['specialNeeds'],
      status: json['status'] ?? 'Pending',
      assignedNgoId: json['assignedNgoId'],
      assignedNgoName: json['assignedNgoName'],
      createdAt: DateTime.parse(json['createdAt']),
      assignedAt: json['assignedAt'] != null ? DateTime.parse(json['assignedAt']) : null,
      verifiedAt: json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt']) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      verifierNotes: json['verifierNotes'],
      rejectionReason: json['rejectionReason'],
    );
  }
}