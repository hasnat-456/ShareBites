import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/models/ngo_model.dart';
import 'package:sharebites/models/verification_request_model.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

class NGOService {
  static final NGOService _instance = NGOService._internal();
  factory NGOService() => _instance;
  NGOService._internal();

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  NGO? _currentNGO;

  DatabaseReference get _ngosRef => _databaseRef.child('ngos');
  DatabaseReference get _verificationsRef => _databaseRef.child('verification_requests');
  DatabaseReference get _usersRef => _databaseRef.child('users');

  NGO? get currentNGO => _currentNGO;

  Future<List<NGO>> getAllNGOs() async {
    try {
      final dataSnapshot = await _ngosRef.once();


      if (dataSnapshot.snapshot.value == null) return [];

      List<NGO> ngos = [];
      final ngosMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      ngosMap.forEach((key, value) {
        final ngoData = Map<String, dynamic>.from(value as Map);
        ngos.add(NGO.fromJson(ngoData));
      });

      ngos.sort((a, b) => a.name.compareTo(b.name));

      return ngos;
    } catch (e) {
      print('Error getting NGOs: $e');
      return [];
    }
  }

  Future<NGO> ngoLogin(String ngoId, String password) async {
    try {
      final ngoSnapshot = await _ngosRef.child(ngoId).once();


      if (ngoSnapshot.snapshot.value == null) {
        throw Exception('NGO not found');
      }

      final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);
      final ngo = NGO.fromJson(ngoData);

      final correctPassword = ngo.currentPassword ?? ngo.defaultPassword;
      if (password != correctPassword) {
        throw Exception('Incorrect password');
      }

      _currentNGO = ngo;

      try {
        await SupabaseNotificationService().registerUser(
          userId: ngo.id,
          userType: 'NGO',
        );
        print('✅ NGO registered for notifications');
      } catch (e) {
        print('⚠️ Warning: Failed to register NGO for notifications: $e');
      }

      return ngo;
    } catch (e) {
      print('NGO login error: $e');
      rethrow;
    }
  }

  Future<void> changePassword(String ngoId, String oldPassword, String newPassword) async {
    try {
      final ngoSnapshot = await _ngosRef.child(ngoId).once();


      if (ngoSnapshot.snapshot.value == null) {
        throw Exception('NGO not found');
      }

      final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);
      final ngo = NGO.fromJson(ngoData);

      final correctPassword = ngo.currentPassword ?? ngo.defaultPassword;
      if (oldPassword != correctPassword) {
        throw Exception('Current password is incorrect');
      }

      if (newPassword.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      await _ngosRef.child(ngoId).update({
        'currentPassword': newPassword,
        'isPasswordChanged': true,
      });

      if (_currentNGO?.id == ngoId) {
        _currentNGO!.currentPassword = newPassword;
        _currentNGO!.isPasswordChanged = true;
      }

      print('Password changed successfully');
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  Future<void> createVerificationRequest(User acceptor) async {
    try {
      print('=== CREATING VERIFICATION REQUEST IN NGO SERVICE ===');
      print('Acceptor ID: ${acceptor.id}');
      print('Acceptor Name: ${acceptor.name}');

      final existingRequestSnapshot = await _verificationsRef
          .orderByChild('acceptorId')
          .equalTo(acceptor.id)
          .once();


      if (existingRequestSnapshot.snapshot.value != null) {
        print('⚠️ Verification request already exists for acceptor: ${acceptor.id}');
        return;
      }

      final requestId = 'ver_${DateTime.now().millisecondsSinceEpoch}_${acceptor.id}';

      final request = VerificationRequest(
        id: requestId,
        acceptorId: acceptor.id,
        acceptorName: acceptor.name,
        acceptorEmail: acceptor.email,
        acceptorPhone: acceptor.phone,
        acceptorAddress: acceptor.address ?? '',
        acceptorLocation: acceptor.location!,
        cnicFrontUrl: acceptor.cnicFrontUrl,
        cnicBackUrl: acceptor.cnicBackUrl,
        familySize: acceptor.familySize,
        monthlyIncome: acceptor.monthlyIncome,
        specialNeeds: acceptor.specialNeeds,
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      await _verificationsRef.child(requestId).set(request.toJson());
      print('✓ Verification request saved to Firebase: $requestId');

      await Future.delayed(const Duration(milliseconds: 500));
      await _assignToNearestNGO(request);
      await Future.delayed(const Duration(milliseconds: 500));
      await _notifyAllNGOsOfNewRequest(acceptor);

      print('✅ Verification request created successfully');
    } catch (e) {
      print('✗ Error creating verification request: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> _notifyAllNGOsOfNewRequest(User acceptor) async {
    try {
      print('=== NOTIFYING ALL NGOs VIA SUPABASE ===');

      final ngosSnapshot = await _ngosRef.once();


      if (ngosSnapshot.snapshot.value == null) {
        print('⚠️ No NGOs found');
        return;
      }

      final ngosMap = Map<String, dynamic>.from(ngosSnapshot.snapshot.value as Map);
      List<String> ngoIds = ngosMap.keys.toList();

      print('Found ${ngoIds.length} NGOs to notify');

      await SupabaseNotificationHelper.notifyNewVerificationRequest(
        ngoIds: ngoIds,
        userName: acceptor.name,
        userType: 'Acceptor',
      );

      print('✅ All NGOs notified successfully via Supabase');
    } catch (e) {
      print('✗ Error in _notifyAllNGOsOfNewRequest: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _assignToNearestNGO(VerificationRequest request) async {
    try {
      print('╚═════════════════════════════════════════════════════════════');
      print('📋 Request ID: ${request.id}');
      print('👤 Acceptor: ${request.acceptorName}');
      print('📍 Location: ${request.acceptorLocation.latitude}, ${request.acceptorLocation.longitude}');

      final allNGOs = await getAllNGOs();

      if (allNGOs.isEmpty) {
        print('❌ CRITICAL: No NGOs available for assignment');
        throw Exception('No NGOs available for assignment');
      }

      print('✅ Found ${allNGOs.length} NGO(s)');

      final ngosWithDistance = allNGOs.map((ngo) {
        final distance = _calculateDistance(
          request.acceptorLocation,
          ngo.location,
        );
        print('  - ${ngo.name}: ${distance.toStringAsFixed(2)} km');
        return MapEntry(ngo, distance);
      }).toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final nearestNGO = ngosWithDistance.first.key;
      final distance = ngosWithDistance.first.value;

      print('\n🎯 Nearest NGO Selected:');
      print('  Name: ${nearestNGO.name}');
      print('  ID: ${nearestNGO.id}');
      print('  Distance: ${distance.toStringAsFixed(2)} km');
      print('  Current Pending: ${nearestNGO.pendingCount}');

      final expiresAt = DateTime.now().add(const Duration(hours: 48));
      final assignedAt = DateTime.now();

      final assignmentData = {
        'status': 'Assigned',
        'assignedNgoId': nearestNGO.id,
        'assignedNgoName': nearestNGO.name,
        'assignedAt': assignedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

      await _verificationsRef.child(request.id).update(assignmentData);
      print('✅ Firebase write completed');

      await Future.delayed(const Duration(milliseconds: 1000));

      print('─' * 60);

      final verifySnapshot = await _verificationsRef.child(request.id).once();


      if (verifySnapshot.snapshot.value == null) {
        throw Exception('❌ CRITICAL: Request disappeared after assignment!');
      }

      final verifyData = Map<String, dynamic>.from(verifySnapshot.snapshot.value as Map);

      print('Checking Status:');
      final actualStatus = verifyData['status']?.toString() ?? '';
      print('  Expected: "Assigned"');
      print('  Actual: "$actualStatus"');
      print('  Result: ${actualStatus == 'Assigned' ? '✅ MATCH' : '❌ MISMATCH'}');

      print('\nChecking assignedNgoId:');
      final actualAssignedNgoId = verifyData['assignedNgoId']?.toString() ?? '';
      print('  Expected: "${nearestNGO.id}"');
      print('  Actual: "$actualAssignedNgoId"');
      print('  Result: ${actualAssignedNgoId == nearestNGO.id ? '✅ MATCH' : '❌ MISMATCH'}');

      if (actualStatus != 'Assigned' || actualAssignedNgoId != nearestNGO.id) {
        throw Exception('❌ Assignment verification failed - data mismatch!');
      }

      print('\n✅ Direct read verification PASSED');

      final newPendingCount = nearestNGO.pendingCount + 1;

      await _ngosRef.child(nearestNGO.id).update({
        'pendingCount': newPendingCount,
      });

      print('✅ NGO pending count updated');
      print('  Old count: ${nearestNGO.pendingCount}');
      print('  New count: $newPendingCount');

      print('╚═════════════════════════════════════════════════════════════');
      print('Request: ${request.id}');
      print('Assigned to: ${nearestNGO.name} (${nearestNGO.id})');
      print('Status: Assigned');
      print('Expires: ${expiresAt.toString()}');
      print('\n');

    } catch (e, stackTrace) {
      print('╚═════════════════════════════════════════════════════════════');
      print('Error: $e');
      print('\nStack trace:');
      print(stackTrace);
      print('\n');
      rethrow;
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((point2.latitude - point1.latitude) * p) / 2 +
        cos(point1.latitude * p) *
            cos(point2.latitude * p) *
            (1 - cos((point2.longitude - point1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // PUBLIC METHOD: Assign verification request to NGO
  // This can be called from user_service.dart
  Future<void> assignVerificationRequestToNGO(String requestId) async {
    try {
      print('=== PUBLIC ASSIGNMENT METHOD CALLED ===');
      print('Request ID: $requestId');


      final snapshot = await _verificationsRef.child(requestId).once();

      if (snapshot.snapshot.value == null) {
        throw Exception('Verification request not found: $requestId');
      }

      final requestData = Map<String, dynamic>.from(
          snapshot.snapshot.value as Map
      );


      final verificationRequest = VerificationRequest.fromJson(requestData);


      await _assignToNearestNGO(verificationRequest);

      print('=== PUBLIC ASSIGNMENT METHOD COMPLETE ===');
    } catch (e) {
      print('❌ ERROR in assignVerificationRequestToNGO: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Add this method to force rebuild index if needed
  Future<void> forceRebuildIndex() async {
    try {
      print('=== FORCING INDEX REBUILD ===');


      final snapshot = await _verificationsRef.once();

      if (snapshot.snapshot.value == null) {
        print('No requests to rebuild');
        return;
      }

      final requestsMap = Map<String, dynamic>.from(snapshot.snapshot.value as Map);


      for (var entry in requestsMap.entries) {
        await _verificationsRef.child(entry.key).update({
          '_lastModified': DateTime.now().toIso8601String(),
        });

        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Index rebuild complete');
    } catch (e) {
      print('❌ Error rebuilding index: $e');
    }
  }

  Future<List<VerificationRequest>> getNGORequests(String ngoId) async {
    try {
      print('\n=== GETTING NGO REQUESTS ===');
      print('NGO ID: "$ngoId"');

      // Get all requests from database
      final allSnapshot = await _verificationsRef.once();


      if (allSnapshot.snapshot.value == null) {
        print('ℹï¸ No verification requests in database');
        return [];
      }

      final allRequestsMap = Map<String, dynamic>.from(allSnapshot.snapshot.value as Map);
      List<VerificationRequest> requests = [];
      int matchedCount = 0;
      int excludedCount = 0;

      print('\n📦 Processing ${allRequestsMap.length} total requests...');

      allRequestsMap.forEach((key, value) {
        try {
          final requestData = Map<String, dynamic>.from(value as Map);
          final assignedNgoId = requestData['assignedNgoId']?.toString() ?? '';
          final status = requestData['status']?.toString() ?? '';
          final requestId = requestData['id'] ?? key;

          if (assignedNgoId == ngoId) {
            matchedCount++;

            if (status != 'Verified' && status != 'Rejected') {
              final request = VerificationRequest.fromJson(requestData);
              requests.add(request);
              print('  ✅ Added: $requestId (Status: $status)');
            } else {
              print('  ⭐ Skipped: $requestId (Status: $status - final state)');
              excludedCount++;
            }
          }
        } catch (e) {
          print('  ❌ Error parsing request: $e');
        }
      });

      requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      print('\n────────────────────────────────────────────────────');
      print('📈 SUMMARY:');
      print('  Total processed: ${allRequestsMap.length}');
      print('  Matched NGO: $matchedCount');
      print('  Active requests: ${requests.length}');
      print('  Excluded (completed): $excludedCount');
      print('────────────────────────────────────────────────────\n');

      return requests;

    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in getNGORequests: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> checkAndReassignExpiredRequests() async {
    try {
      print('=== CHECKING FOR EXPIRED REQUESTS ===');

      final dataSnapshot = await _verificationsRef
          .orderByChild('status')
          .equalTo('Assigned')
          .once();


      if (dataSnapshot.snapshot.value == null) {
        print('No assigned requests found');
        return;
      }

      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);
      final now = DateTime.now();
      int expiredCount = 0;

      for (var entry in requestsMap.entries) {
        try {
          final requestData = Map<String, dynamic>.from(entry.value as Map);
          final request = VerificationRequest.fromJson(requestData);

          if (request.expiresAt != null && now.isAfter(request.expiresAt!)) {
            print('Found expired request: ${request.id}');

            if (request.assignedNgoId != null) {
              final oldNGOSnapshot = await _ngosRef.child(request.assignedNgoId!).once();

              if (oldNGOSnapshot.snapshot.value != null) {
                final oldNGOData = Map<String, dynamic>.from(oldNGOSnapshot.snapshot.value as Map);
                final oldNGO = NGO.fromJson(oldNGOData);
                await _ngosRef.child(request.assignedNgoId!).update({
                  'pendingCount': max(0, oldNGO.pendingCount - 1),
                });
              }
            }

            await _verificationsRef.child(request.id).update({
              'status': 'Pending',
              'assignedNgoId': null,
              'assignedNgoName': null,
              'assignedAt': null,
              'expiresAt': null,
            });

            final updatedRequest = VerificationRequest(
              id: request.id,
              acceptorId: request.acceptorId,
              acceptorName: request.acceptorName,
              acceptorEmail: request.acceptorEmail,
              acceptorPhone: request.acceptorPhone,
              acceptorAddress: request.acceptorAddress,
              acceptorLocation: request.acceptorLocation,
              cnicFrontUrl: request.cnicFrontUrl,
              cnicBackUrl: request.cnicBackUrl,
              familySize: request.familySize,
              monthlyIncome: request.monthlyIncome,
              specialNeeds: request.specialNeeds,
              status: 'Pending',
              createdAt: request.createdAt,
            );

            await _assignToNearestNGO(updatedRequest);
            expiredCount++;
          }
        } catch (e) {
          print('Error processing request: $e');
        }
      }

      if (expiredCount > 0) {
        print('✅ Reassigned $expiredCount expired requests');
      } else {
        print('No expired requests found');
      }
    } catch (e) {
      print('Error checking expired requests: $e');
    }
  }

  Future<void> verifyAcceptor(
      String requestId,
      String ngoId,
      String verifierNotes,
      ) async {
    try {
      print('=== VERIFYING ACCEPTOR ===');

      final requestSnapshot = await _verificationsRef.child(requestId).once();


      if (requestSnapshot.snapshot.value == null) {
        throw Exception('Verification request not found');
      }

      final requestData = Map<String, dynamic>.from(requestSnapshot.snapshot.value as Map);
      final request = VerificationRequest.fromJson(requestData);

      String ngoName = 'NGO';
      final ngoSnapshot = await _ngosRef.child(ngoId).once();

      if (ngoSnapshot.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);
        final ngo = NGO.fromJson(ngoData);
        ngoName = ngo.name;
      }

      await _verificationsRef.child(requestId).update({
        'status': 'Verified',
        'verifiedAt': DateTime.now().toIso8601String(),
        'verifierNotes': verifierNotes,
      });

      print('✓ Verification request updated');

      await _usersRef.child(request.acceptorId).update({
        'isVerified': true,
        'cnicVerified': true,
      });

      print('✓ User verification status updated');

      final ngoSnapshot2 = await _ngosRef.child(ngoId).once();

      if (ngoSnapshot2.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot2.snapshot.value as Map);
        final ngo = NGO.fromJson(ngoData);

        await _ngosRef.child(ngoId).update({
          'verifiedCount': ngo.verifiedCount + 1,
          'pendingCount': max(0, ngo.pendingCount - 1),
        });

        print('✓ NGO counts updated');
      }

      try {
        // 1. Notify the ACCEPTOR they are now verified
        await SupabaseNotificationHelper.notifyAcceptorVerificationApproved(
          acceptorId: request.acceptorId,
          ngoName: ngoName,
        );
        // 2. Confirm to the NGO that they completed the verification
        await SupabaseNotificationHelper.notifyNGOVerificationCompleted(
          ngoId: ngoId,
          userName: request.acceptorName,
          approved: true,
        );
        print('Acceptor and NGO notified of verification approval');
      } catch (e) {
        print('Warning: Failed to notify parties: $e');
      }

      // Recompute accurate stats from real Firebase data to prevent drift
      await _recomputeNGOStats(ngoId);

      print('=== ACCEPTOR VERIFIED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ Error verifying acceptor: $e');
      rethrow;
    }
  }

  Future<void> rejectVerification(
      String requestId,
      String ngoId,
      String rejectionReason,
      ) async {
    try {
      print('=== REJECTING VERIFICATION ===');

      final requestSnapshot = await _verificationsRef.child(requestId).once();


      if (requestSnapshot.snapshot.value == null) {
        throw Exception('Verification request not found');
      }

      final requestData = Map<String, dynamic>.from(requestSnapshot.snapshot.value as Map);
      final request = VerificationRequest.fromJson(requestData);

      String ngoName = 'NGO';
      final ngoSnapshot = await _ngosRef.child(ngoId).once();

      if (ngoSnapshot.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);
        final ngo = NGO.fromJson(ngoData);
        ngoName = ngo.name;
      }

      await _verificationsRef.child(requestId).update({
        'status': 'Rejected',
        'verifiedAt': DateTime.now().toIso8601String(),
        'rejectionReason': rejectionReason,
      });

      final ngoSnapshot2 = await _ngosRef.child(ngoId).once();

      if (ngoSnapshot2.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot2.snapshot.value as Map);
        final ngo = NGO.fromJson(ngoData);

        await _ngosRef.child(ngoId).update({
          'pendingCount': max(0, ngo.pendingCount - 1),
        });
      }

      try {
        // 1. Notify the ACCEPTOR their verification was rejected
        await SupabaseNotificationHelper.notifyAcceptorVerificationRejected(
          acceptorId: request.acceptorId,
          ngoName: ngoName,
          reason: rejectionReason,
        );
        // 2. Confirm to the NGO that rejection was done
        await SupabaseNotificationHelper.notifyNGOVerificationCompleted(
          ngoId: ngoId,
          userName: request.acceptorName,
          approved: false,
        );
        print('Acceptor and NGO notified of verification rejection');
      } catch (e) {
        print('Warning: Failed to notify parties: $e');
      }

      // Recompute accurate stats from real Firebase data to prevent drift
      await _recomputeNGOStats(ngoId);

      print('=== VERIFICATION REJECTED ===');
    } catch (e) {
      print('❌ Error rejecting verification: $e');
      rethrow;
    }
  }

  Future<VerificationRequest?> getAcceptorVerificationStatus(String acceptorId) async {
    try {
      print('=== GETTING VERIFICATION STATUS ===');
      print('Acceptor ID: $acceptorId');

      final dataSnapshot = await _verificationsRef
          .orderByChild('acceptorId')
          .equalTo(acceptorId)
          .once();


      if (dataSnapshot.snapshot.value == null) {
        print('⚠️ No verification request found');
        return null;
      }

      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      print('Found ${requestsMap.length} verification request(s)');

      VerificationRequest? latestRequest;
      DateTime? latestDate;

      for (var entry in requestsMap.entries) {
        try {
          final requestData = Map<String, dynamic>.from(entry.value as Map);
          final request = VerificationRequest.fromJson(requestData);

          print('Request ${request.id}: Status = ${request.status}');

          if (latestDate == null || request.createdAt.isAfter(latestDate)) {
            latestRequest = request;
            latestDate = request.createdAt;
          }
        } catch (e) {
          print('❌ Error parsing request: $e');
        }
      }

      if (latestRequest != null) {
        print('✅ Latest request: ${latestRequest.id} - Status: ${latestRequest.status}');
      }

      return latestRequest;
    } catch (e) {
      print('❌ Error getting verification status: $e');
      return null;
    }
  }

  /// Recompute NGO statistics directly from Firebase data to avoid drift.
  /// Called after every verify/reject action to keep counts accurate.
  Future<void> _recomputeNGOStats(String ngoId) async {
    try {
      print('=== RECOMPUTING NGO STATS FOR: $ngoId ===');

      final allSnapshot = await _verificationsRef.once();
      if (allSnapshot.snapshot.value == null) {
        await _ngosRef.child(ngoId).update({
          'verifiedCount': 0,
          'pendingCount': 0,
          'rejectedCount': 0,
        });
        return;
      }

      final allMap = Map<String, dynamic>.from(allSnapshot.snapshot.value as Map);
      int verified = 0;
      int pending = 0;
      int rejected = 0;

      allMap.forEach((key, value) {
        try {
          final req = Map<String, dynamic>.from(value as Map);
          if (req['assignedNgoId']?.toString() == ngoId) {
            final status = req['status']?.toString() ?? '';
            if (status == 'Verified') verified++;
            else if (status == 'Rejected') rejected++;
            else pending++; // Pending or Assigned
          }
        } catch (_) {}
      });

      await _ngosRef.child(ngoId).update({
        'verifiedCount': verified,
        'pendingCount': pending,
        'rejectedCount': rejected,
      });

      print('✅ Stats recomputed — Verified: $verified, Pending: $pending, Rejected: $rejected');
    } catch (e) {
      print('⚠️ Error recomputing NGO stats: $e');
    }
  }

  // CLEAR ALL APP DATA — Firebase + Supabase notifications

  /// Wipes every node in Firebase AND all Supabase notification data.
  /// Used by the NGO admin when resetting the app for a fresh start.
  /// Returns a summary of what was deleted.
  Future<Map<String, dynamic>> clearAllAppData() async {
    final result = <String, dynamic>{
      'firebase': <String, dynamic>{},
      'supabase': <String, dynamic>{},
      'errors': <String>[],
    };

    print('=== CLEARING ALL APP DATA ===');

    // ── 1. Firebase nodes ────────────────────────────────────────────
    final firebaseNodes = [
      'users',
      'verification_requests',
      'donations',
      'donation_requests',
      'received_donations',
      'schedule_changes',
      'notification_settings',
    ];

    for (final node in firebaseNodes) {
      try {
        await _databaseRef.child(node).remove();
        result['firebase'][node] = 'cleared';
        print('  ✅ Firebase /$node cleared');
      } catch (e) {
        final msg = 'Failed to clear /$node: $e';
        result['firebase'][node] = 'error: $e';
        (result['errors'] as List<String>).add(msg);
        print('  ❌ $msg');
      }
    }

    // Reset NGO stats to zero (keep NGO accounts, just zero their counts)
    try {
      final ngosSnapshot = await _ngosRef.once();
      if (ngosSnapshot.snapshot.value != null) {
        final ngosMap = Map<String, dynamic>.from(ngosSnapshot.snapshot.value as Map);
        for (final ngoId in ngosMap.keys) {
          await _ngosRef.child(ngoId).update({
            'verifiedCount': 0,
            'pendingCount': 0,
            'rejectedCount': 0,
          });
        }
        print('  ✅ NGO statistics reset to zero');
        result['firebase']['ngo_stats'] = 'reset to zero';
      }
    } catch (e) {
      final msg = 'Failed to reset NGO stats: $e';
      (result['errors'] as List<String>).add(msg);
      print('  ❌ $msg');
    }

    // ── 2. Supabase notification data ────────────────────────────────
    try {
      final supabaseResult = await SupabaseNotificationHelper.clearAllNotificationData();
      result['supabase'] = supabaseResult;
    } catch (e) {
      final msg = 'Supabase clear failed: $e';
      (result['errors'] as List<String>).add(msg);
      print('  ❌ $msg');
    }

    print('=== CLEAR ALL DATA COMPLETE ===');
    print('  Errors: ${(result['errors'] as List).length}');
    return result;
  }

  void signOut() {
    if (_currentNGO != null) {
      try {
        SupabaseNotificationService().unregisterUser(_currentNGO!.id);
        print('✅ NGO unregistered from notifications');
      } catch (e) {
        print('⚠️ Error unregistering NGO from notifications: $e');
      }
    }

    _currentNGO = null;
    print('NGO signed out');
  }

  Future<List<VerificationRequest>> getAllVerificationRequestsForAcceptor(String acceptorId) async {
    try {
      final dataSnapshot = await _verificationsRef
          .orderByChild('acceptorId')
          .equalTo(acceptorId)
          .once();


      if (dataSnapshot.snapshot.value == null) return [];

      List<VerificationRequest> requests = [];
      final requestsMap = Map<String, dynamic>.from(dataSnapshot.snapshot.value as Map);

      requestsMap.forEach((key, value) {
        try {
          final requestData = Map<String, dynamic>.from(value as Map);
          final request = VerificationRequest.fromJson(requestData);
          requests.add(request);
        } catch (e) {
          print('Error parsing request: $e');
        }
      });

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return requests;
    } catch (e) {
      print('Error getting all verification requests: $e');
      return [];
    }
  }
}