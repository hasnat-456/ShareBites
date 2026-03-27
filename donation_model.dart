import 'package:google_maps_flutter/google_maps_flutter.dart';

class Donation {
  String id;
  String title;
  String type;
  String weight;
  DateTime donationDate;
  DateTime expiryDate;
  String status; // Pending, Reserved, Scheduled, Awaiting Confirmation, Completed
  String? foodStatus;
  LatLng location;
  String donorId;
  String? acceptorId;
  String? acceptorName;
  double? distance;
  String priority;
  String description;
  String? requestId;
  DateTime? requestedDate;

  // NEW FIELDS for scheduling and delivery
  DateTime? scheduledDate;
  String? scheduledTime; // e.g., "10:00 AM - 12:00 PM"
  String? deliveryMethod; // 'pickup' or 'delivery'
  LatLng? pickupLocation;
  String? deliveryNotes;
  DateTime? markedDeliveredDate;

  DateTime? completedDate;
  String? feedback;
  double? rating;

  // Schedule change request fields
  bool? hasScheduleChangeRequest;
  String? pendingScheduleChangeId;

  Donation({
    required this.id,
    required this.title,
    required this.type,
    required this.weight,
    required this.donationDate,
    required this.expiryDate,
    this.status = 'Pending',
    this.foodStatus,
    required this.location,
    required this.donorId,
    this.acceptorId,
    this.acceptorName,
    this.distance,
    this.priority = 'Medium',
    this.description = '',
    this.requestId,
    this.requestedDate,
    this.scheduledDate,
    this.scheduledTime,
    this.deliveryMethod,
    this.pickupLocation,
    this.deliveryNotes,
    this.markedDeliveredDate,
    this.completedDate,
    this.feedback,
    this.rating,

    // Schedule change request fields
    this.hasScheduleChangeRequest,
    this.pendingScheduleChangeId,
  });

  String calculatePriority() {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    if (type == 'Food') {
      if (foodStatus == 'Cooked') {
        if (daysUntilExpiry <= 1) return 'High';
        if (daysUntilExpiry <= 3) return 'Medium';
        return 'Low';
      } else {
        if (daysUntilExpiry <= 2) return 'High';
        if (daysUntilExpiry <= 5) return 'Medium';
        return 'Low';
      }
    } else {
      if (daysUntilExpiry <= 3) return 'High';
      if (daysUntilExpiry <= 7) return 'Medium';
      return 'Low';
    }
  }

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isAvailable => status == 'Pending' && !isExpired;
  bool get isScheduled => status == 'Scheduled';
  bool get isAwaitingConfirmation => status == 'Awaiting Confirmation';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'weight': weight,
      'donationDate': donationDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'status': status,
      'foodStatus': foodStatus,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'donorId': donorId,
      'acceptorId': acceptorId,
      'acceptorName': acceptorName,
      'distance': distance,
      'priority': priority,
      'description': description,
      'requestId': requestId,
      'requestedDate': requestedDate?.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'scheduledTime': scheduledTime,
      'deliveryMethod': deliveryMethod,
      'pickupLatitude': pickupLocation?.latitude,
      'pickupLongitude': pickupLocation?.longitude,
      'deliveryNotes': deliveryNotes,
      'markedDeliveredDate': markedDeliveredDate?.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'feedback': feedback,
      'rating': rating,

      // Schedule change request fields
      'hasScheduleChangeRequest': hasScheduleChangeRequest,
      'pendingScheduleChangeId': pendingScheduleChangeId,
    };
  }

  factory Donation.fromJson(Map<String, dynamic> json) {
    LatLng? pickupLoc;
    if (json['pickupLatitude'] != null && json['pickupLongitude'] != null) {
      pickupLoc = LatLng(
        (json['pickupLatitude'] as num).toDouble(),
        (json['pickupLongitude'] as num).toDouble(),
      );
    }

    return Donation(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      weight: json['weight'],
      donationDate: DateTime.parse(json['donationDate']),
      expiryDate: DateTime.parse(json['expiryDate']),
      status: json['status'],
      foodStatus: json['foodStatus'],
      location: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      donorId: json['donorId'],
      acceptorId: json['acceptorId'],
      acceptorName: json['acceptorName'],
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      priority: json['priority'],
      description: json['description'],
      requestId: json['requestId'],
      requestedDate: json['requestedDate'] != null ? DateTime.parse(json['requestedDate']) : null,
      scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : null,
      scheduledTime: json['scheduledTime'],
      deliveryMethod: json['deliveryMethod'],
      pickupLocation: pickupLoc,
      deliveryNotes: json['deliveryNotes'],
      markedDeliveredDate: json['markedDeliveredDate'] != null ? DateTime.parse(json['markedDeliveredDate']) : null,
      completedDate: json['completedDate'] != null ? DateTime.parse(json['completedDate']) : null,
      feedback: json['feedback'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,

      // Schedule change request fields
      hasScheduleChangeRequest: json['hasScheduleChangeRequest'],
      pendingScheduleChangeId: json['pendingScheduleChangeId'],
    );
  }

  // Optional: Add a copyWith method for convenience
  Donation copyWith({
    String? id,
    String? title,
    String? type,
    String? weight,
    DateTime? donationDate,
    DateTime? expiryDate,
    String? status,
    String? foodStatus,
    LatLng? location,
    String? donorId,
    String? acceptorId,
    String? acceptorName,
    double? distance,
    String? priority,
    String? description,
    String? requestId,
    DateTime? requestedDate,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? deliveryMethod,
    LatLng? pickupLocation,
    String? deliveryNotes,
    DateTime? markedDeliveredDate,
    DateTime? completedDate,
    String? feedback,
    double? rating,
    bool? hasScheduleChangeRequest,
    String? pendingScheduleChangeId,
  }) {
    return Donation(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      donationDate: donationDate ?? this.donationDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      foodStatus: foodStatus ?? this.foodStatus,
      location: location ?? this.location,
      donorId: donorId ?? this.donorId,
      acceptorId: acceptorId ?? this.acceptorId,
      acceptorName: acceptorName ?? this.acceptorName,
      distance: distance ?? this.distance,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      requestId: requestId ?? this.requestId,
      requestedDate: requestedDate ?? this.requestedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      markedDeliveredDate: markedDeliveredDate ?? this.markedDeliveredDate,
      completedDate: completedDate ?? this.completedDate,
      feedback: feedback ?? this.feedback,
      rating: rating ?? this.rating,
      hasScheduleChangeRequest: hasScheduleChangeRequest ?? this.hasScheduleChangeRequest,
      pendingScheduleChangeId: pendingScheduleChangeId ?? this.pendingScheduleChangeId,
    );
  }
}

class DonationRequest {
  String id;
  String acceptorId;
  String acceptorName;
  String type;
  String itemName;
  String quantity;
  String description;
  DateTime neededBy;
  LatLng location;
  String status;
  String? donorId;
  String? donationId;
  DateTime requestDate;

  bool get isUrgent => neededBy.difference(DateTime.now()).inDays <= 2;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'acceptorId': acceptorId,
      'acceptorName': acceptorName,
      'type': type,
      'itemName': itemName,
      'quantity': quantity,
      'description': description,
      'neededBy': neededBy.toIso8601String(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': status,
      'donorId': donorId,
      'donationId': donationId,
      'requestDate': requestDate.toIso8601String(),
    };
  }

  factory DonationRequest.fromJson(Map<String, dynamic> json) {
    return DonationRequest(
      id: json['id'],
      acceptorId: json['acceptorId'],
      acceptorName: json['acceptorName'],
      type: json['type'],
      itemName: json['itemName'],
      quantity: json['quantity'],
      description: json['description'],
      neededBy: DateTime.parse(json['neededBy']),
      location: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      status: json['status'],
      donorId: json['donorId'],
      donationId: json['donationId'],
      requestDate: DateTime.parse(json['requestDate']),
    );
  }

  DonationRequest({
    required this.id,
    required this.acceptorId,
    required this.acceptorName,
    required this.type,
    required this.itemName,
    required this.quantity,
    required this.description,
    required this.neededBy,
    required this.location,
    this.status = 'Pending',
    this.donorId,
    this.donationId,
    required this.requestDate,
  });
}