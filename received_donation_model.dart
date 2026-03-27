// models/received_donation_model.dart
class ReceivedDonation {
  final String id;
  final String title;
  final String type;
  final String weight;
  final DateTime receivedDate;
  final String donorName;
  final double rating;
  final String? feedback;
  final String acceptorId;
  final String status;

  // Schedule related fields
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String? deliveryMethod;
  final DateTime? markedDeliveredDate;

  // Schedule change request fields
  final bool? hasScheduleChangeRequest;
  final String? pendingScheduleChangeId;

  ReceivedDonation({
    required this.id,
    required this.title,
    required this.type,
    required this.weight,
    required this.receivedDate,
    required this.donorName,
    required this.rating,
    this.feedback,
    required this.acceptorId,
    required this.status,

    // Schedule fields
    this.scheduledDate,
    this.scheduledTime,
    this.deliveryMethod,
    this.markedDeliveredDate,

    // Schedule change request fields
    this.hasScheduleChangeRequest,
    this.pendingScheduleChangeId,
  });

  // CopyWith method with all fields
  ReceivedDonation copyWith({
    String? id,
    String? title,
    String? type,
    String? weight,
    DateTime? receivedDate,
    String? donorName,
    double? rating,
    String? feedback,
    String? acceptorId,
    String? status,

    // Schedule fields
    DateTime? scheduledDate,
    String? scheduledTime,
    String? deliveryMethod,
    DateTime? markedDeliveredDate,

    // Schedule change request fields
    bool? hasScheduleChangeRequest,
    String? pendingScheduleChangeId,
  }) {
    return ReceivedDonation(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      receivedDate: receivedDate ?? this.receivedDate,
      donorName: donorName ?? this.donorName,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      acceptorId: acceptorId ?? this.acceptorId,
      status: status ?? this.status,

      // Schedule fields
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      markedDeliveredDate: markedDeliveredDate ?? this.markedDeliveredDate,

      // Schedule change request fields
      hasScheduleChangeRequest: hasScheduleChangeRequest ?? this.hasScheduleChangeRequest,
      pendingScheduleChangeId: pendingScheduleChangeId ?? this.pendingScheduleChangeId,
    );
  }

  // ToMap method with all fields
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'weight': weight,
      'receivedDate': receivedDate.toIso8601String(),
      'donorName': donorName,
      'rating': rating,
      'feedback': feedback,
      'acceptorId': acceptorId,
      'status': status,

      // Schedule fields
      'scheduledDate': scheduledDate?.toIso8601String(),
      'scheduledTime': scheduledTime,
      'deliveryMethod': deliveryMethod,
      'markedDeliveredDate': markedDeliveredDate?.toIso8601String(),

      // Schedule change request fields
      'hasScheduleChangeRequest': hasScheduleChangeRequest,
      'pendingScheduleChangeId': pendingScheduleChangeId,
    };
  }

  // FromMap factory constructor with all fields
  factory ReceivedDonation.fromMap(Map<String, dynamic> map) {
    return ReceivedDonation(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      weight: map['weight'] ?? '',
      receivedDate: DateTime.parse(map['receivedDate']),
      donorName: map['donorName'] ?? 'Unknown Donor',
      rating: (map['rating'] ?? 0.0).toDouble(),
      feedback: map['feedback'],
      acceptorId: map['acceptorId'] ?? '',
      status: map['status'] ?? 'Pending',

      // Schedule fields
      scheduledDate: map['scheduledDate'] != null
          ? DateTime.parse(map['scheduledDate'])
          : null,
      scheduledTime: map['scheduledTime'],
      deliveryMethod: map['deliveryMethod'],
      markedDeliveredDate: map['markedDeliveredDate'] != null
          ? DateTime.parse(map['markedDeliveredDate'])
          : null,

      // Schedule change request fields
      hasScheduleChangeRequest: map['hasScheduleChangeRequest'] ?? false,
      pendingScheduleChangeId: map['pendingScheduleChangeId'],
    );
  }

  // Optional: Override toString for debugging
  @override
  String toString() {
    return 'ReceivedDonation{id: $id, title: $title, type: $type, status: $status, scheduledDate: $scheduledDate, hasScheduleChangeRequest: $hasScheduleChangeRequest}';
  }

  // Optional: Add equality check
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReceivedDonation &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}