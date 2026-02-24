import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/models/schedule_change_model.dart';
import 'package:sharebites/notifications/notification_service.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

class ScheduleChangeService {
  static final ScheduleChangeService _instance = ScheduleChangeService._internal();
  factory ScheduleChangeService() => _instance;
  ScheduleChangeService._internal();

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  DatabaseReference get _scheduleChangesRef => _databaseRef.child('schedule_changes');
  DatabaseReference get _donationsRef => _databaseRef.child('donations');

  Future<bool> createScheduleChangeRequest({
    required String donationId,
    required String requestedBy,
    required String requesterId,
    required String requesterName,
    DateTime? newScheduledDate,
    String? newScheduledTime,
    String? newDeliveryMethod,
    required String changeReason,
  }) async {
    try {
      if (donationId.isEmpty || requesterId.isEmpty || changeReason.trim().isEmpty) {
        return false;
      }

      final donationSnapshot = await _donationsRef.child(donationId).once();

      if (donationSnapshot.snapshot.value == null) {
        return false;
      }

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);

      final donorId = donationData['donorId']?.toString() ?? '';
      final donationTitle = donationData['title']?.toString() ?? 'Donation';
      final acceptorId = donationData['acceptorId']?.toString() ?? '';

      final requestId = 'schedule_change_${DateTime.now().millisecondsSinceEpoch}_$donationId';

      final request = ScheduleChangeRequest(
        id: requestId,
        donationId: donationId,
        requestedBy: requestedBy,
        requesterId: requesterId,
        requesterName: requesterName,
        newScheduledDate: newScheduledDate,
        newScheduledTime: newScheduledTime,
        newDeliveryMethod: newDeliveryMethod,
        changeReason: changeReason,
        status: 'Pending',
        requestedAt: DateTime.now(),
      );

      await _scheduleChangesRef.child(requestId).set(request.toJson());

      final donationUpdate = {
        'hasScheduleChangeRequest': true,
        'pendingScheduleChangeId': requestId,
      };

      await _donationsRef.child(donationId).update(donationUpdate);

      try {
        final receivedRef = _databaseRef.child('received_donations').child(donationId);
        final receivedSnap = await receivedRef.once();
        if (receivedSnap.snapshot.value != null) {
          await receivedRef.update(donationUpdate);
        }
      } catch (e) {
        print('Warning: Could not sync to received_donations: $e');
      }

      try {
        final newSchedDisplay = newScheduledTime ??
            newScheduledDate?.toLocal().toString().split(' ')[0] ?? 'New time';

        if (requestedBy == 'acceptor') {
          await SupabaseNotificationHelper.notifyScheduleChangeRequest(
            donorId: donorId,
            donationTitle: donationTitle,
            requestedDate: newSchedDisplay,
            acceptorName: requesterName,
            reason: changeReason,
          );

          await SupabaseNotificationHelper.notifyAcceptorScheduleChangeConfirmation(
            acceptorId: requesterId,
            donationTitle: donationTitle,
            requestedDate: newSchedDisplay,
          );
        } else {
          await SupabaseNotificationHelper.notifyScheduleChangeRequest(
            donorId: acceptorId,
            donationTitle: donationTitle,
            requestedDate: newSchedDisplay,
            acceptorName: requesterName,
            reason: changeReason,
          );
        }
      } catch (e) {
        print('Warning: Notification failed (non-critical): $e');
      }

      return true;

    } catch (e, stackTrace) {
      print('Error in createScheduleChangeRequest: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<ScheduleChangeRequest?> getScheduleChangeRequest(String donationId) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (donationSnapshot.snapshot.value != null) {
        final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
        final pendingId = donationData['pendingScheduleChangeId']?.toString() ?? '';
        final hasPending = donationData['hasScheduleChangeRequest'] == true;

        if (hasPending && pendingId.isNotEmpty) {
          final requestSnapshot = await _scheduleChangesRef.child(pendingId).once();
          if (requestSnapshot.snapshot.value != null) {
            final reqData = Map<String, dynamic>.from(requestSnapshot.snapshot.value as Map);
            final req = ScheduleChangeRequest.fromJson(reqData);
            if (req.status == 'Pending') {
              return req;
            }
          }
        }
      }

      final dataSnapshot = await _scheduleChangesRef
          .orderByChild('donationId')
          .equalTo(donationId)
          .once();

      if (dataSnapshot.snapshot.value == null) return null;

      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);
      ScheduleChangeRequest? latestRequest;
      DateTime? latestDate;

      requestsMap.forEach((key, value) {
        final requestData = Map<String, dynamic>.from(value as Map);
        final request = ScheduleChangeRequest.fromJson(requestData);
        if (request.status == 'Pending') {
          if (latestDate == null || request.requestedAt.isAfter(latestDate!)) {
            latestRequest = request;
            latestDate = request.requestedAt;
          }
        }
      });

      return latestRequest;
    } catch (e, stackTrace) {
      print('Error getting schedule change request: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<ScheduleChangeRequest>> getPendingRequestsForUser(
      String userId,
      String userRole,
      ) async {
    try {
      final dataSnapshot = await _scheduleChangesRef
          .orderByChild('status')
          .equalTo('Pending')
          .once();

      if (dataSnapshot.snapshot.value == null) return [];

      List<ScheduleChangeRequest> relevantRequests = [];
      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      for (var entry in requestsMap.entries) {
        final requestData = Map<String, dynamic>.from(entry.value as Map);
        final request = ScheduleChangeRequest.fromJson(requestData);

        final donationSnapshot = await _donationsRef.child(request.donationId).once();
        if (donationSnapshot.snapshot.value != null) {
          final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
          final donorId = donationData['donorId']?.toString() ?? '';
          final acceptorId = donationData['acceptorId']?.toString() ?? '';

          if (userRole == 'donor' && request.requestedBy == 'acceptor' && donorId == userId) {
            relevantRequests.add(request);
          } else if (userRole == 'acceptor' && request.requestedBy == 'donor' && acceptorId == userId) {
            relevantRequests.add(request);
          }
        }
      }

      return relevantRequests;
    } catch (e, stackTrace) {
      print('Error getting pending requests for user: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<bool> acceptScheduleChange(String requestId, String responseNote) async {
    try {
      final requestSnapshot = await _scheduleChangesRef.child(requestId).once();
      if (requestSnapshot.snapshot.value == null) throw Exception('Request not found');
      final request = ScheduleChangeRequest.fromJson(
        Map<String, dynamic>.from(requestSnapshot.snapshot.value as Map),
      );

      final donationSnapshot = await _donationsRef.child(request.donationId).once();
      if (donationSnapshot.snapshot.value == null) throw Exception('Donation not found');
      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donationTitle = donationData['title']?.toString() ?? 'Donation';

      await _scheduleChangesRef.child(requestId).update({
        'status': 'Accepted',
        'respondedAt': DateTime.now().toIso8601String(),
        'responseNote': responseNote,
      });

      final updates = <String, dynamic>{
        'hasScheduleChangeRequest': false,
        'pendingScheduleChangeId': '',
      };
      if (request.newScheduledDate != null) {
        updates['scheduledDate'] = request.newScheduledDate!.toIso8601String();
      }
      if (request.newScheduledTime != null) {
        updates['scheduledTime'] = request.newScheduledTime;
      }
      if (request.newDeliveryMethod != null) {
        updates['deliveryMethod'] = request.newDeliveryMethod;
      }

      await _donationsRef.child(request.donationId).update(updates);

      try {
        final receivedRef = _databaseRef.child('received_donations').child(request.donationId);
        final receivedSnapshot = await receivedRef.once();
        if (receivedSnapshot.snapshot.value != null) {
          await receivedRef.update(updates);
        }
      } catch (e) {
        print('Warning: Could not sync received_donations: $e');
      }

      try {
        if (request.requestedBy == 'acceptor') {
          await NotificationHelper.notifyAcceptorScheduleChangeApproved(
            acceptorId: request.requesterId,
            donationTitle: donationTitle,
            newScheduleDate: request.newScheduledDate?.toIso8601String().split('T')[0] ?? 'New date',
            newScheduleTime: request.newScheduledTime ?? 'New time',
          );
        } else {
          await NotificationHelper.notifyDonorScheduleChangeAccepted(
            donorId: request.requesterId,
            donationTitle: donationTitle,
            newSchedule: request.newScheduledTime ?? 'New time',
          );
        }
      } catch (e) {
        print('Warning: Notification failed (non-critical): $e');
      }

      return true;
    } catch (e, stackTrace) {
      print('Error accepting schedule change: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> rejectScheduleChange(String requestId, String responseNote) async {
    try {
      final requestSnapshot = await _scheduleChangesRef.child(requestId).once();
      if (requestSnapshot.snapshot.value == null) throw Exception('Request not found');
      final request = ScheduleChangeRequest.fromJson(
        Map<String, dynamic>.from(requestSnapshot.snapshot.value as Map),
      );

      String donationTitle = 'Donation';
      try {
        final donationSnapshot = await _donationsRef.child(request.donationId).once();
        if (donationSnapshot.snapshot.value != null) {
          final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
          donationTitle = donationData['title']?.toString() ?? 'Donation';
        }
      } catch (e) {
        print('Warning: Could not load donation for title: $e');
      }

      await _scheduleChangesRef.child(requestId).update({
        'status': 'Rejected',
        'respondedAt': DateTime.now().toIso8601String(),
        'responseNote': responseNote,
      });

      await _donationsRef.child(request.donationId).update({
        'hasScheduleChangeRequest': false,
        'pendingScheduleChangeId': '',
      });

      try {
        if (request.requestedBy == 'acceptor') {
          await NotificationHelper.notifyAcceptorScheduleChangeRejected(
            acceptorId: request.requesterId,
            donationTitle: donationTitle,
            reason: responseNote,
          );
        } else {
          await NotificationService().sendNotification(
            userIds: [request.requesterId],
            userType: 'Donor',
            title: 'Schedule Change Rejected',
            message: 'Your schedule change request for "$donationTitle" was not approved',
            notificationType: 'schedule_change_rejected',
            data: {'action': 'view_donation', 'reason': responseNote},
          );
        }
      } catch (e) {
        print('Warning: Notification failed (non-critical): $e');
      }

      return true;
    } catch (e, stackTrace) {
      print('Error rejecting schedule change: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<List<ScheduleChangeRequest>> getScheduleChangeHistory(String donationId) async {
    try {
      final dataSnapshot = await _scheduleChangesRef
          .orderByChild('donationId')
          .equalTo(donationId)
          .once();

      if (dataSnapshot.snapshot.value == null) return [];

      List<ScheduleChangeRequest> requests = [];
      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);
      requestsMap.forEach((key, value) {
        try {
          final requestData = Map<String, dynamic>.from(value as Map);
          requests.add(ScheduleChangeRequest.fromJson(requestData));
        } catch (e) {
          print('Error parsing schedule change request $key: $e');
        }
      });

      requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return requests;
    } catch (e) {
      print('Error getting schedule change history: $e');
      return [];
    }
  }

  Future<bool> hasPendingScheduleChange(String donationId) async {
    try {
      final request = await getScheduleChangeRequest(donationId);
      return request != null && request.status == 'Pending';
    } catch (e) {
      return false;
    }
  }
}