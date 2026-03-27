import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/received_donation_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
// DeliveryReminderScheduler is part of supabase_notification_service.dart

class DonationService {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  final StreamController<List<Donation>> _donationStream = StreamController.broadcast();
  final StreamController<List<DonationRequest>> _requestStream = StreamController.broadcast();

  DatabaseReference get _donationsRef => _databaseRef.child('donations');
  DatabaseReference get _requestsRef => _databaseRef.child('donation_requests');
  DatabaseReference get _receivedRef => _databaseRef.child('received_donations');
  DatabaseReference get _usersRef => _databaseRef.child('users');

  // ─────────────────────────────────────────────────────────────────────────
  // GET AVAILABLE DONATIONS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<Donation>> getAvailableDonations(LatLng? userLocation) async {
    try {
      final dataSnapshot = await _donationsRef
          .orderByChild('status')
          .equalTo('Pending')
          .once();

      if (!dataSnapshot.snapshot.exists) return [];

      List<Donation> availableDonations = [];
      final donationsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      donationsMap.forEach((key, value) {
        final donationData = Map<String, dynamic>.from(value as Map);
        final donation = Donation.fromJson(donationData);

        if (!donation.isExpired) {
          if (userLocation != null) {
            donation.distance = _calculateDistance(
              userLocation.latitude,
              userLocation.longitude,
              donation.location.latitude,
              donation.location.longitude,
            );
          }
          availableDonations.add(donation);
        }
      });

      if (userLocation != null) {
        availableDonations.sort((a, b) {
          final aPriority = a.calculatePriority();
          final bPriority = b.calculatePriority();
          final priorityOrder = {'High': 1, 'Medium': 2, 'Low': 3};
          if (priorityOrder[aPriority] != priorityOrder[bPriority]) {
            return priorityOrder[aPriority]!.compareTo(priorityOrder[bPriority]!);
          }
          return (a.distance ?? 999).compareTo(b.distance ?? 999);
        });
      }

      return availableDonations;
    } catch (e) {
      print('Error getting available donations: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD DONATION — notifies all verified acceptors
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> addDonation(Donation donation) async {
    try {
      donation.priority = donation.calculatePriority();
      await _donationsRef.child(donation.id).set(donation.toJson());
      await _updateDonorTotalDonations(donation.donorId);

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      // Get donor name for notification message
      String donorName = 'A donor';
      try {
        final donorSnap = await _usersRef.child(donation.donorId).once();
        if (donorSnap.snapshot.exists) {
          final data = Map<String, dynamic>.from(donorSnap.snapshot.value as Map);
          donorName = data['name'] ?? 'A donor';
        }
      } catch (_) {}

      // NOTIFICATION: Notify all verified acceptors of new donation
      try {
        await SupabaseNotificationHelper.notifyAllAcceptorsOfNewDonation(
          donationTitle: donation.title,
          donorName: donorName,
          donationId: donation.id,
        );
        print('✅ All verified acceptors notified of new donation');
      } catch (e) {
        print('⚠️ Failed to notify acceptors of new donation: $e');
      }

      print('Donation added successfully to Firebase!');
    } catch (e) {
      print('Failed to add donation: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST DONATION WITH SCHEDULE — acceptor requests a donation
  // Notifications: donor gets "new request", acceptor gets "request sent" confirmation
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> requestDonationWithSchedule(
      String donationId,
      String acceptorId,
      String acceptorName, {
        DateTime? scheduledDate,
        String? scheduledTime,
        String? deliveryMethod,
        LatLng? pickupLocation,
        String? deliveryNotes,
      }) async {
    try {
      print('=== STARTING DONATION REQUEST ===');

      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      await _donationsRef.child(donationId).update({
        'status': 'Reserved',
        'acceptorId': acceptorId,
        'acceptorName': acceptorName,
        'requestedDate': DateTime.now().toIso8601String(),
        'scheduledDate': scheduledDate?.toIso8601String(),
        'scheduledTime': scheduledTime,
        'deliveryMethod': deliveryMethod,
        'pickupLatitude': pickupLocation?.latitude,
        'pickupLongitude': pickupLocation?.longitude,
        'deliveryNotes': deliveryNotes,
      });

      String donorName = 'Unknown Donor';
      try {
        final donorSnapshot = await _usersRef.child(donation.donorId).once();
        if (donorSnapshot.snapshot.exists) {
          final donorData = Map<String, dynamic>.from(donorSnapshot.snapshot.value as Map);
          donorName = donorData['name'] ?? 'Unknown Donor';
        }
      } catch (_) {}

      final receivedDonation = ReceivedDonation(
        id: donation.id,
        title: donation.title,
        type: donation.type,
        weight: donation.weight,
        receivedDate: DateTime.now(),
        donorName: donorName,
        rating: 0.0,
        feedback: null,
        acceptorId: acceptorId,
        status: 'Pending',
      );

      await _receivedRef.child(donation.id).set(receivedDonation.toMap());

      // NOTIFICATIONS
      try {
        final schedStr = scheduledTime ?? scheduledDate?.toLocal().toString().split(' ')[0] ?? 'TBD';

        // 1. Notify DONOR — new request received against their donation
        await SupabaseNotificationHelper.notifyDonationRequested(
          donorId: donation.donorId,
          acceptorName: acceptorName,
          donationTitle: donation.title,
        );
        print('✅ Donor notified of new request');

        // 2. Confirm to ACCEPTOR — their request was sent
        await SupabaseNotificationHelper.notifyAcceptorRequestConfirmation(
          acceptorId: acceptorId,
          donationTitle: donation.title,
        );
        print('✅ Acceptor request confirmation sent');
      } catch (e) {
        print('⚠️ Warning: Failed to send request notifications: $e');
      }

      print('=== DONATION REQUEST COMPLETED SUCCESSFULLY ===');
      return true;
    } catch (e, stackTrace) {
      print('❌ ERROR in requestDonationWithSchedule: $e');
      print('Stack trace: $stackTrace');

      try {
        final checkSnapshot = await _donationsRef.child(donationId).once();
        if (checkSnapshot.snapshot.exists) {
          final checkData = Map<String, dynamic>.from(checkSnapshot.snapshot.value as Map);
          if (checkData['status'] == 'Reserved' && checkData['acceptorId'] == acceptorId) {
            return true;
          }
        }
      } catch (_) {}
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCEPT AND SCHEDULE — donor approves acceptor's request
  // Notifications: acceptor gets "request approved" + donor gets confirmation
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> acceptAndScheduleDonation(String donationId) async {
    try {
      // Get donation data first for notification
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;
      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      await _donationsRef.child(donationId).update({'status': 'Scheduled'});
      await _receivedRef.child(donationId).update({'status': 'Scheduled'});

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      // NOTIFICATIONS
      try {
        final schedDate = donation.scheduledDate?.toLocal().toString().split(' ')[0] ?? 'Scheduled';
        final schedTime = donation.scheduledTime ?? 'Soon';

        // 1. Notify ACCEPTOR — their request was approved by donor
        if (donation.acceptorId != null && donation.acceptorId!.isNotEmpty) {
          await SupabaseNotificationHelper.notifyRequestApproved(
            acceptorId: donation.acceptorId!,
            donationTitle: donation.title,
            pickupDate: '$schedDate at $schedTime',
          );
          print('✅ Acceptor notified: request approved');
        }

        // 2. Confirm to DONOR — they approved the request
        if (donation.acceptorName != null) {
          await SupabaseNotificationHelper.notifyDonorApprovedRequest(
            donorId: donation.donorId,
            acceptorName: donation.acceptorName!,
            donationTitle: donation.title,
          );
          print('✅ Donor notified: you approved the request');
        }
      } catch (e) {
        print('⚠️ Warning: Failed to send approval notifications: $e');
      }

      return true;
    } catch (e) {
      print('Error scheduling donation: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REJECT ACCEPTOR REQUEST — donor rejects an acceptor's reservation
  // Notifications: acceptor gets "request declined"
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> rejectDonationRequest(String donationId, {String? reason}) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;
      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      // Reset donation to Pending so others can request it
      await _donationsRef.child(donationId).update({
        'status': 'Pending',
        'acceptorId': null,
        'acceptorName': null,
        'requestedDate': null,
        'scheduledDate': null,
        'scheduledTime': null,
      });

      // Remove from received_donations
      try {
        await _receivedRef.child(donationId).remove();
      } catch (_) {}

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      // NOTIFICATION: Notify ACCEPTOR — their request was declined
      try {
        if (donation.acceptorId != null && donation.acceptorId!.isNotEmpty) {
          await SupabaseNotificationHelper.notifyRequestRejected(
            acceptorId: donation.acceptorId!,
            donationTitle: donation.title,
            reason: reason,
          );
          print('✅ Acceptor notified: request declined');
        }

        // Confirm to DONOR they rejected it
        if (donation.acceptorName != null) {
          await SupabaseNotificationHelper.notifyDonorRejectedRequest(
            donorId: donation.donorId,
            acceptorName: donation.acceptorName!,
            donationTitle: donation.title,
          );
          print('✅ Donor notified: you rejected the request');
        }
      } catch (e) {
        print('⚠️ Failed to send rejection notifications: $e');
      }

      return true;
    } catch (e) {
      print('Error rejecting donation request: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MARK AS DELIVERED — donor marks delivery done
  // Notifications: acceptor gets "donor delivered, please confirm"
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> markAsDelivered(String donationId) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      await _donationsRef.child(donationId).update({
        'status': 'Awaiting Confirmation',
        'markedDeliveredDate': DateTime.now().toIso8601String(),
      });

      await _receivedRef.child(donationId).update({
        'status': 'Awaiting Confirmation',
        'markedDeliveredDate': DateTime.now().toIso8601String(),
      });

      // NOTIFICATIONS
      try {
        // 1. Notify ACCEPTOR — donor is delivering, please be ready & confirm receipt
        if (donation.acceptorId != null && donation.acceptorId!.isNotEmpty) {
          // Fetch donor name for better notification message
          String donorName = 'Donor';
          try {
            final donorSnap = await _usersRef.child(donation.donorId).once();
            if (donorSnap.snapshot.exists) {
              final dData = Map<String, dynamic>.from(donorSnap.snapshot.value as Map);
              donorName = dData['name'] ?? 'Donor';
            }
          } catch (_) {}

          await SupabaseNotificationHelper.notifyAcceptorDonorDelivering(
            acceptorId: donation.acceptorId!,
            donationTitle: donation.title,
            donorName: donorName,
            scheduledTime: donation.scheduledTime ?? 'Now',
          );
          await SupabaseNotificationHelper.notifyConfirmReceiptPrompt(
            acceptorId: donation.acceptorId!,
            donationTitle: donation.title,
          );
          print('✅ Acceptor notified: donor is delivering + confirm receipt prompt');
        }

        // 2. Confirm to DONOR — you marked as delivered
        await SupabaseNotificationHelper.notifyDeliveryReminderToday(
          donorId: donation.donorId,
          donationTitle: donation.title,
          acceptorName: donation.acceptorName ?? 'Acceptor',
          pickupTime: donation.scheduledTime ?? 'Now',
        );

        // 3. Cancel any 2-hour delivery reminder timers since delivery is done
        DeliveryReminderScheduler.cancelReminders(donationId);
        print('✅ Delivery reminders cancelled');
      } catch (e) {
        print('⚠️ Warning: Failed to send delivery notifications: $e');
      }

      return true;
    } catch (e) {
      print('Error marking as delivered: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIRM RECEIPT — acceptor confirms they received the donation
  // Notifications: donor gets "donation received by acceptor" + completion
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> confirmReceipt(String donationId, String acceptorId) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      String acceptorName = 'Acceptor';
      try {
        final acceptorSnapshot = await _usersRef.child(acceptorId).once();
        if (acceptorSnapshot.snapshot.exists) {
          final acceptorData = Map<String, dynamic>.from(acceptorSnapshot.snapshot.value as Map);
          acceptorName = acceptorData['name'] ?? 'Acceptor';
        }
      } catch (_) {}

      await _donationsRef.child(donationId).update({
        'status': 'Completed',
        'completedDate': DateTime.now().toIso8601String(),
      });

      await _receivedRef.child(donationId).update({'status': 'Accepted'});

      if (donation.donorId.isNotEmpty) {
        await _updateDonorTotalDonations(donation.donorId);
      }

      // NOTIFICATION: Notify DONOR — donation was received and confirmed
      try {
        await SupabaseNotificationHelper.notifyDonationDelivered(
          donorId: donation.donorId,
          acceptorName: acceptorName,
          donationTitle: donation.title,
        );
        print('✅ Donor notified: donation received and confirmed by acceptor');
      } catch (e) {
        print('⚠️ Failed to notify donor of delivery confirmation: $e');
      }

      return true;
    } catch (e) {
      print('Error confirming receipt: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPLETE DONATION
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> completeDonation(String donationId) async {
    try {
      final donation = await _getDonationById(donationId);
      if (donation == null) return false;

      await _donationsRef.child(donationId).update({
        'status': 'Completed',
        'completedDate': DateTime.now().toIso8601String(),
      });

      await _receivedRef.child(donationId).update({'status': 'Accepted'});

      if (donation.donorId.isNotEmpty) {
        await _updateDonorTotalDonations(donation.donorId);
      }

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      return true;
    } catch (e) {
      print('Error completing donation: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST DONATION (simple, no schedule)
  // Notifications: donor gets "new request"
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> requestDonation(String donationId, String acceptorId, String acceptorName) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (!donationSnapshot.snapshot.exists) return false;

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      final donation = Donation.fromJson(donationData);

      await _donationsRef.child(donationId).update({
        'status': 'Reserved',
        'acceptorId': acceptorId,
        'acceptorName': acceptorName,
        'requestedDate': DateTime.now().toIso8601String(),
      });

      String donorName = 'Unknown Donor';
      if (donation.donorId.isNotEmpty) {
        final donorSnapshot = await _usersRef.child(donation.donorId).once();
        if (donorSnapshot.snapshot.exists) {
          final donorData = Map<String, dynamic>.from(donorSnapshot.snapshot.value as Map);
          donorName = donorData['name'] ?? 'Unknown Donor';
        }
      }

      final receivedDonation = ReceivedDonation(
        id: donation.id,
        title: donation.title,
        type: donation.type,
        weight: donation.weight,
        receivedDate: DateTime.now(),
        donorName: donorName,
        rating: 0.0,
        feedback: null,
        acceptorId: acceptorId,
        status: 'Pending',
      );

      await _receivedRef.child(donation.id).set(receivedDonation.toMap());

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      // NOTIFICATION: Notify DONOR of new request
      try {
        await SupabaseNotificationHelper.notifyDonationRequested(
          donorId: donation.donorId,
          acceptorName: acceptorName,
          donationTitle: donation.title,
        );

        await SupabaseNotificationHelper.notifyAcceptorRequestConfirmation(
          acceptorId: acceptorId,
          donationTitle: donation.title,
        );
        print('✅ Request notifications sent');
      } catch (e) {
        print('⚠️ Warning: Failed to send request notification: $e');
      }

      return true;
    } catch (e) {
      print("Error requesting donation: $e");
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE DONATION — notifies acceptor if reservation existed
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> deleteDonation(String donationId, String donorId) async {
    try {
      // Get donation data before deleting to notify acceptor if needed
      String? acceptorId;
      String donationTitle = 'Donation';
      try {
        final snap = await _donationsRef.child(donationId).once();
        if (snap.snapshot.exists) {
          final data = Map<String, dynamic>.from(snap.snapshot.value as Map);
          acceptorId = data['acceptorId']?.toString();
          donationTitle = data['title']?.toString() ?? 'Donation';
        }
      } catch (_) {}

      // Delete related requests
      final requestsQuery = await _requestsRef
          .orderByChild('donationId')
          .equalTo(donationId)
          .once();
      if (requestsQuery.snapshot.exists) {
        final requestsMap = requestsQuery.snapshot.value as Map<dynamic, dynamic>?;
        if (requestsMap != null) {
          for (final requestId in requestsMap.keys) {
            await _requestsRef.child(requestId.toString()).remove();
          }
        }
      }

      final receivedSnapshot = await _receivedRef.child(donationId).once();
      if (receivedSnapshot.snapshot.exists) {
        await _receivedRef.child(donationId).remove();
      }

      await _donationsRef.child(donationId).remove();
      await _updateDonorTotalDonations(donorId);

      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);

      // NOTIFICATION: Notify ACCEPTOR if donation was reserved and now cancelled
      if (acceptorId != null && acceptorId.isNotEmpty) {
        try {
          await SupabaseNotificationHelper.notifyRequestRejected(
            acceptorId: acceptorId,
            donationTitle: donationTitle,
            reason: 'The donor has removed this donation',
          );
          print('✅ Acceptor notified of donation cancellation');
        } catch (e) {
          print('⚠️ Failed to notify acceptor of cancellation: $e');
        }
      }
    } catch (e, stackTrace) {
      print('✗ Error deleting donation: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to delete donation: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER METHODS (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _updateDonorTotalDonations(String donorId) async {
    try {
      final donations = await getDonationsByDonor(donorId);
      final totalCount = donations.length;

      await _usersRef.child(donorId).update({
        'totalDonations': totalCount,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final authService = AuthService();
      if (authService.currentUser?.id == donorId) {
        authService.currentUser?.totalDonations = totalCount;
        await authService.refreshUserData();
      }
    } catch (e) {
      print('✗ Error updating donor total donations: $e');
    }
  }

  Future<List<Donation>> getDonationsByDonor(String donorId) async {
    try {
      final dataSnapshot = await _donationsRef
          .orderByChild('donorId')
          .equalTo(donorId)
          .once();

      if (!dataSnapshot.snapshot.exists) return [];

      List<Donation> donations = [];
      final donationsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      donationsMap.forEach((key, value) {
        try {
          final donationData = Map<String, dynamic>.from(value as Map);
          final donation = Donation.fromJson(donationData);
          if (donation.id.isNotEmpty && donation.donorId == donorId) {
            donations.add(donation);
          }
        } catch (e) {
          print('Error parsing donation $key: $e');
        }
      });

      return donations;
    } catch (e) {
      print('Error getting donations by donor: $e');
      return [];
    }
  }

  Future<List<Donation>> getDonationsByAcceptor(String acceptorId) async {
    try {
      final dataSnapshot = await _donationsRef
          .orderByChild('acceptorId')
          .equalTo(acceptorId)
          .once();

      if (!dataSnapshot.snapshot.exists) return [];

      List<Donation> donations = [];
      final donationsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);
      donationsMap.forEach((key, value) {
        final donationData = Map<String, dynamic>.from(value as Map);
        donations.add(Donation.fromJson(donationData));
      });

      return donations;
    } catch (e) {
      print('Error getting donations by acceptor: $e');
      return [];
    }
  }

  Future<void> fixAllDonorStatistics() async {
    try {
      final usersSnapshot = await _usersRef.once();
      if (usersSnapshot.snapshot.exists) {
        final usersMap = usersSnapshot.snapshot.value as Map<dynamic, dynamic>;
        for (final entry in usersMap.entries) {
          final userId = entry.key.toString();
          final userData = entry.value as Map<dynamic, dynamic>;
          if (userData['userType'] == 'Donor') {
            final donations = await getDonationsByDonor(userId);
            await _usersRef.child(userId).update({'totalDonations': donations.length});
          }
        }
      }
    } catch (e) {
      print('✗ Error fixing donor statistics: $e');
    }
  }

  Future<List<DonationRequest>> getDonationRequests(LatLng? userLocation) async {
    try {
      final dataSnapshot = await _requestsRef.once();
      if (!dataSnapshot.snapshot.exists) return [];

      List<DonationRequest> requests = [];
      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      requestsMap.forEach((key, value) {
        try {
          final requestData = Map<String, dynamic>.from(value as Map);
          final request = DonationRequest.fromJson(requestData);
          if (request.status == 'Pending') requests.add(request);
        } catch (e) {
          print('Error parsing request $key: $e');
        }
      });

      if (userLocation != null) {
        requests.sort((a, b) {
          if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
          final aDist = _calculateDistance(userLocation.latitude, userLocation.longitude, a.location.latitude, a.location.longitude);
          final bDist = _calculateDistance(userLocation.latitude, userLocation.longitude, b.location.latitude, b.location.longitude);
          return aDist.compareTo(bDist);
        });
      }

      return requests;
    } catch (e) {
      print('Error getting donation requests: $e');
      return [];
    }
  }

  Future<void> updateRequestStatus(String requestId, String status, {String? donationId, String? donorId}) async {
    try {
      final updates = {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (donationId != null) updates['donationId'] = donationId;
      if (donorId != null) updates['donorId'] = donorId;
      if (status == 'Fulfilled') updates['fulfilledDate'] = DateTime.now().toIso8601String();

      await _requestsRef.child(requestId).update(updates);
      final allRequests = await getDonationRequests(null);
      _requestStream.add(allRequests);
    } catch (e) {
      print('✗ Error updating request status: $e');
      throw Exception('Failed to update request status');
    }
  }

  Future<void> submitDonationRequest(DonationRequest request) async {
    try {
      await _requestsRef.child(request.id).set(request.toJson());
      final allRequests = await getDonationRequests(null);
      _requestStream.add(allRequests);
    } catch (e) {
      print('Error submitting donation request: $e');
      throw Exception("Failed to submit request");
    }
  }

  Future<List<ReceivedDonation>> getReceivedDonations(String acceptorId) async {
    try {
      final dataSnapshot = await _receivedRef.orderByChild('acceptorId').equalTo(acceptorId).once();
      if (!dataSnapshot.snapshot.exists) return [];

      List<ReceivedDonation> receivedDonations = [];
      final donationsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);
      donationsMap.forEach((key, value) {
        final donationData = Map<String, dynamic>.from(value as Map);
        receivedDonations.add(ReceivedDonation.fromMap(donationData));
      });

      return receivedDonations;
    } catch (e) {
      print('Error getting received donations: $e');
      return [];
    }
  }

  Future<bool> acceptAndScheduleDonationSimple(String donationId) async {
    try {
      await _donationsRef.child(donationId).update({'status': 'Scheduled'});
      await _receivedRef.child(donationId).update({'status': 'Scheduled'});
      final allDonations = await getAvailableDonations(null);
      _donationStream.add(allDonations);
      return true;
    } catch (e) {
      print('Error scheduling donation: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getUserById(String userId) async {
    try {
      final userSnapshot = await _usersRef.child(userId).once();
      if (userSnapshot.snapshot.exists) {
        return Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<Donation?> _getDonationById(String donationId) async {
    try {
      final donationSnapshot = await _donationsRef.child(donationId).once();
      if (donationSnapshot.snapshot.exists) {
        final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
        return Donation.fromJson(donationData);
      }
      return null;
    } catch (e) {
      print('Error getting donation by ID: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<Map<String, int>> getDonationStatistics(String userId, String userType) async {
    try {
      List<Donation> donations;
      if (userType == 'Donor') {
        donations = await getDonationsByDonor(userId);
      } else {
        donations = await getDonationsByAcceptor(userId);
      }
      return {
        'total': donations.length,
        'pending': donations.where((d) => d.status == 'Pending').length,
        'reserved': donations.where((d) => d.status == 'Reserved').length,
        'completed': donations.where((d) => d.status == 'Completed').length,
        'expired': donations.where((d) => d.isExpired && d.status != 'Completed').length,
      };
    } catch (e) {
      print('Error getting donation statistics: $e');
      return {'total': 0, 'pending': 0, 'reserved': 0, 'completed': 0, 'expired': 0};
    }
  }

  Stream<List<Donation>> get donationStream => _donationStream.stream;
  Stream<List<DonationRequest>> get requestStream => _requestStream.stream;

  void dispose() {
    _donationStream.close();
    _requestStream.close();
  }
}