class ScheduleChangeRequest {
  String id;
  String donationId;
  String requestedBy; // 'donor' or 'acceptor'
  String requesterId;
  String requesterName;
  DateTime? newScheduledDate;
  String? newScheduledTime;
  String? newDeliveryMethod;
  String changeReason;
  String status; // 'Pending', 'Accepted', 'Rejected'
  DateTime requestedAt;
  DateTime? respondedAt;
  String? responseNote;

  ScheduleChangeRequest({
    required this.id,
    required this.donationId,
    required this.requestedBy,
    required this.requesterId,
    required this.requesterName,
    this.newScheduledDate,
    this.newScheduledTime,
    this.newDeliveryMethod,
    required this.changeReason,
    this.status = 'Pending',
    required this.requestedAt,
    this.respondedAt,
    this.responseNote,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'donationId': donationId,
      'requestedBy': requestedBy,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'changeReason': changeReason,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
    };

    // Firebase Realtime Database rejects null values — only include non-null optional fields
    if (newScheduledDate != null) map['newScheduledDate'] = newScheduledDate!.toIso8601String();
    if (newScheduledTime != null) map['newScheduledTime'] = newScheduledTime;
    if (newDeliveryMethod != null) map['newDeliveryMethod'] = newDeliveryMethod;
    if (respondedAt != null) map['respondedAt'] = respondedAt!.toIso8601String();
    if (responseNote != null) map['responseNote'] = responseNote;

    return map;
  }

  factory ScheduleChangeRequest.fromJson(Map<String, dynamic> json) {
    return ScheduleChangeRequest(
      id: json['id'],
      donationId: json['donationId'],
      requestedBy: json['requestedBy'],
      requesterId: json['requesterId'],
      requesterName: json['requesterName'],
      newScheduledDate: json['newScheduledDate'] != null
          ? DateTime.parse(json['newScheduledDate'])
          : null,
      newScheduledTime: json['newScheduledTime'],
      newDeliveryMethod: json['newDeliveryMethod'],
      changeReason: json['changeReason'],
      status: json['status'] ?? 'Pending',
      requestedAt: DateTime.parse(json['requestedAt']),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
      responseNote: json['responseNote'],
    );
  }
}