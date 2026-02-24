import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'notification_config.dart';

/// Supabase-based Notification Service for ShareBites App
/// All notifications are stored in and retrieved from Supabase
class SupabaseNotificationService {
  static final SupabaseNotificationService _instance = SupabaseNotificationService._internal();
  factory SupabaseNotificationService() => _instance;
  SupabaseNotificationService._internal();

  static const String ONESIGNAL_APP_ID = NotificationConfig.ONESIGNAL_APP_ID;
  static const String SUPABASE_URL = NotificationConfig.SUPABASE_URL;
  static const String SUPABASE_ANON_KEY = NotificationConfig.SUPABASE_ANON_KEY;

  late SupabaseClient _supabase;
  String? _currentPlayerId;
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentUserType;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Notification service already initialized');
      return;
    }

    try {
      print('🔔 Initializing Supabase Notification Service...');

      try {
        await Supabase.initialize(
          url: SUPABASE_URL,
          anonKey: SUPABASE_ANON_KEY,
        );
        _supabase = Supabase.instance.client;
        print('✅ Supabase initialized');
      } catch (e) {
        if (e.toString().contains('already initialized')) {
          _supabase = Supabase.instance.client;
          print('✅ Supabase instance retrieved');
        } else {
          rethrow;
        }
      }

      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(ONESIGNAL_APP_ID);

      final accepted = await OneSignal.Notifications.requestPermission(true);
      print('📱 Notification permission: ${accepted ? "Granted" : "Denied"}');

      if (accepted) {
        _setupNotificationHandlers();
        _isInitialized = true;
        print('✅ Notification service initialized successfully');
      } else {
        print('⚠️ Notification permission denied');
        _isInitialized = true; // still mark initialized so we can save to DB
      }
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  void _setupNotificationHandlers() {
    OneSignal.Notifications.addClickListener((event) {
      print('🔔 Notification opened: ${event.notification.title}');
      final data = event.notification.additionalData;
      if (data != null) {
        _handleNotificationClick(data);
      }
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('🔔 Notification received in foreground: ${event.notification.title}');

      if (_currentUserId != null) {
        _saveNotificationToSupabase(
          title: event.notification.title ?? 'Notification',
          message: event.notification.body ?? '',
          data: event.notification.additionalData ?? {},
        );
      }

      event.notification.display();
    });

    OneSignal.User.pushSubscription.addObserver((state) {
      if (state.current.id != null) {
        _currentPlayerId = state.current.id;
        print('📱 OneSignal Player ID: $_currentPlayerId');

        if (_currentUserId != null && _currentUserType != null) {
          _updatePlayerIdInSupabase();
        }
      }
    });
  }

  Future<void> registerUser({
    required String userId,
    required String userType,
  }) async {
    try {
      print('📝 Registering user for notifications...');
      print('   User ID: $userId');
      print('   User Type: $userType');

      _currentUserId = userId;
      _currentUserType = userType;

      await OneSignal.login(userId);
      await Future.delayed(const Duration(seconds: 2));

      final playerId = OneSignal.User.pushSubscription.id;

      if (playerId == null) {
        print('⚠️ Warning: OneSignal player ID not available yet');
        return;
      }

      _currentPlayerId = playerId;
      print('✅ OneSignal Player ID: $playerId');

      await _supabase.from('notification_tokens').upsert({
        'user_id': userId,
        'user_type': userType,
        'onesignal_player_id': playerId,
        'device_type': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ User registered for notifications successfully');
    } catch (e) {
      print('❌ Error registering user for notifications: $e');
    }
  }

  Future<void> _updatePlayerIdInSupabase() async {
    if (_currentUserId == null || _currentPlayerId == null) return;

    try {
      await _supabase.from('notification_tokens').upsert({
        'user_id': _currentUserId,
        'user_type': _currentUserType,
        'onesignal_player_id': _currentPlayerId,
        'device_type': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ Player ID updated in Supabase');
    } catch (e) {
      print('❌ Error updating player ID: $e');
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('🎯 Notification clicked with data: $data');
  }

  Future<void> _saveNotificationToSupabase({
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    if (_currentUserId == null || _currentUserType == null) return;

    try {
      await _supabase.from('notification_logs').insert({
        'user_id': _currentUserId,
        'user_type': _currentUserType,
        'title': title,
        'message': message,
        'notification_type': data['type'] ?? 'general',
        'data': data,
        'sent_at': DateTime.now().toIso8601String(),
        'read_at': null,
      });

      print('✅ Notification saved to Supabase');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  Future<bool> sendNotification({
    required List<String> userIds,
    required String title,
    required String message,
    String? notificationType,
    Map<String, dynamic>? data,
    String? userType,
  }) async {
    try {
      print('📤 Sending notification...');
      print('   To: $userIds');
      print('   Title: $title');
      print('   Type: $notificationType');
      print('   UserType: $userType');

      if (userIds.isEmpty) {
        print('⚠️ No user IDs provided');
        return false;
      }

      int successCount = 0;
      for (final userId in userIds) {
        try {
          print('   → Sending to user: $userId (Type: $userType)');

          await _supabase.from('notification_logs').insert({
            'user_id': userId,
            'user_type': userType ?? 'Unknown',
            'title': title,
            'message': message,
            'notification_type': notificationType ?? 'general',
            'data': data ?? {},
            'sent_at': DateTime.now().toIso8601String(),
            'read_at': null,
          });

          successCount++;
          print('   ✓ Notification saved for user: $userId');
        } catch (e) {
          print('   ✗ Failed to save notification for user $userId: $e');
        }
      }

      if (successCount > 0) {
        print('✅ Notification sent successfully to $successCount/${userIds.length} users');
        return true;
      } else {
        print('❌ Failed to send notification to any users');
        return false;
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationHistory(String userId) async {
    try {
      print('🔍 Fetching notifications for user: $userId');

      final response = await _supabase
          .from('notification_logs')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .limit(50);

      print('📥 Loaded ${response.length} notifications for user: $userId');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting notification history: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notification_logs')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notification_logs')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);

      print('✅ All notifications marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null)
          .count(CountOption.exact);

      final count = response.count;
      print('📊 Unread count for $userId: $count');
      return count;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Stream<int> watchUnreadCount(String userId) {
    try {
      return _supabase
          .from('notification_logs')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((data) {
        final unreadCount = data.where((notification) {
          return notification['read_at'] == null;
        }).length;
        return unreadCount;
      });
    } catch (e) {
      print('❌ Error setting up unread count stream: $e');
      return Stream.value(0);
    }
  }

  Future<void> unregisterUser(String userId) async {
    try {
      print('📝 Unregistering user from notifications...');

      try {
        await _supabase.from('notification_tokens').delete().eq('user_id', userId);
        print('✅ User token deleted from Supabase');
      } catch (e) {
        print('⚠️ Error deleting token: $e');
      }

      await OneSignal.logout();
      _currentUserId = null;
      _currentUserType = null;
      _currentPlayerId = null;

      print('✅ User unregistered successfully');
    } catch (e) {
      print('❌ Error unregistering user: $e');
    }
  }

  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserType => _currentUserType;
  String? get playerId => _currentPlayerId;
}

// NOTIFICATION HELPER — COMPREHENSIVE NOTIFICATION SYSTEM
// Donor  : 15 types
// Acceptor: 14 types
// NGO    : 9 types
class SupabaseNotificationHelper {
  static final SupabaseNotificationService _service = SupabaseNotificationService();

  // DONOR NOTIFICATIONS (15 types)

  /// D-1. New request received against donor's donation (acceptor applies)
  static Future<void> notifyDonationRequested({
    required String donorId,
    required String acceptorName,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '📬 New Donation Request',
      message: '$acceptorName wants to receive: "$donationTitle"',
      notificationType: 'donation_requested',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'donationTitle': donationTitle,
        'action': 'view_donor_requests',
      },
    );
  }

  /// D-2. Specific / custom donation request submitted by acceptor (from donor_requests flow)
  static Future<void> notifyDonorOfSpecificRequest({
    required String donorId,
    required String acceptorName,
    required String itemRequested,
    required String quantity,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '🙏 Specific Donation Request',
      message: '$acceptorName specifically requested "$itemRequested" (Qty: $quantity)',
      notificationType: 'specific_donation_request',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'itemRequested': itemRequested,
        'quantity': quantity,
        'action': 'view_donor_requests',
      },
    );
  }

  /// D-3. Donor approved acceptor request — confirmation to donor
  static Future<void> notifyDonorApprovedRequest({
    required String donorId,
    required String acceptorName,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '✅ You Approved Request',
      message: 'You approved $acceptorName\'s request for "$donationTitle"',
      notificationType: 'donor_approved_request_confirmation',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'donationTitle': donationTitle,
        'action': 'view_my_donations',
      },
    );
  }

  /// D-4. Donor rejected acceptor request — confirmation to donor
  static Future<void> notifyDonorRejectedRequest({
    required String donorId,
    required String acceptorName,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '❌ You Declined Request',
      message: 'You declined $acceptorName\'s request for "$donationTitle"',
      notificationType: 'donor_rejected_request_confirmation',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'donationTitle': donationTitle,
        'action': 'view_my_donations',
      },
    );
  }

  /// D-5. Schedule change requested by acceptor — donor must respond
  static Future<void> notifyScheduleChangeRequest({
    required String donorId,
    required String donationTitle,
    required String requestedDate,
    required String acceptorName,
    String? reason,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '📅 Schedule Change Request',
      message: '$acceptorName wants to reschedule "$donationTitle" to $requestedDate',
      notificationType: 'schedule_change_request',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'requestedDate': requestedDate,
        'acceptorName': acceptorName,
        'reason': reason ?? '',
        'action': 'review_schedule_change',
      },
    );
  }

  /// D-6. Donor approved schedule change — confirmation to donor
  static Future<void> notifyDonorApprovedScheduleChange({
    required String donorId,
    required String donationTitle,
    required String newDate,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '✅ Schedule Updated',
      message: 'You approved schedule change for "$donationTitle" to $newDate',
      notificationType: 'donor_approved_schedule_change',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'newDate': newDate,
        'action': 'view_my_donations',
      },
    );
  }

  /// D-7. Donor rejected schedule change — confirmation to donor
  static Future<void> notifyDonorRejectedScheduleChange({
    required String donorId,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '❌ Schedule Change Declined',
      message: 'You declined schedule change for "$donationTitle"',
      notificationType: 'donor_rejected_schedule_change',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'action': 'view_my_donations',
      },
    );
  }

  /// D-8. Feedback received from acceptor
  static Future<void> notifyFeedbackReceived({
    required String donorId,
    required String acceptorName,
    required String donationTitle,
    required int rating,
    String? comment,
  }) async {
    final stars = '⭐' * rating;
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '⭐ New Feedback',
      message: '$acceptorName rated your "$donationTitle": $stars ($rating/5)',
      notificationType: 'feedback_received',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'donationTitle': donationTitle,
        'rating': rating,
        'comment': comment ?? '',
        'action': 'view_feedback',
      },
    );
  }

  /// D-9. Donation received and confirmed by acceptor
  static Future<void> notifyDonationDelivered({
    required String donorId,
    required String acceptorName,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '🎉 Donation Received!',
      message: '$acceptorName confirmed receipt of "$donationTitle". Thank you for your generosity!',
      notificationType: 'donation_delivered_confirmed',
      data: {
        'donorId': donorId,
        'acceptorName': acceptorName,
        'donationTitle': donationTitle,
        'action': 'view_donation_history',
      },
    );
  }

  /// D-10. Delivery reminder — 24 hours before scheduled time
  static Future<void> notifyDeliveryReminder24h({
    required String donorId,
    required String donationTitle,
    required String pickupTime,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '⏰ Delivery Tomorrow',
      message: 'Reminder: "$donationTitle" pickup scheduled for tomorrow at $pickupTime',
      notificationType: 'delivery_reminder_24h',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'pickupTime': pickupTime,
        'action': 'view_donation_details',
      },
    );
  }

  /// D-11. Delivery day started — sent at the start of delivery day
  static Future<void> notifyDeliveryDayStarted({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String scheduledTime,
    required String location,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '🚀 Delivery Day!',
      message: 'Today is the delivery day for "$donationTitle" to $acceptorName at $scheduledTime',
      notificationType: 'delivery_day_started',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'acceptorName': acceptorName,
        'scheduledTime': scheduledTime,
        'location': location,
        'action': 'view_donation_details',
      },
    );
  }

  /// D-12. Delivery reminder every 2 hours on delivery day (until scheduled time)
  static Future<void> notifyDeliveryReminder2hInterval({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String scheduledTime,
    required int hoursUntilDelivery,
  }) async {
    String message;
    String title;

    if (hoursUntilDelivery <= 0) {
      title = '🚨 Delivery Time Now!';
      message = 'It\'s time to deliver "$donationTitle" to $acceptorName!';
    } else if (hoursUntilDelivery == 1) {
      title = '⏰ 1 Hour Until Delivery';
      message = 'Hurry! "$donationTitle" delivery to $acceptorName in 1 hour ($scheduledTime)';
    } else {
      title = '⏰ Delivery in $hoursUntilDelivery Hours';
      message = 'Don\'t forget: "$donationTitle" delivery to $acceptorName at $scheduledTime';
    }

    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: title,
      message: message,
      notificationType: 'delivery_reminder_2h_interval',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'acceptorName': acceptorName,
        'scheduledTime': scheduledTime,
        'hoursUntilDelivery': hoursUntilDelivery,
        'action': 'view_donation_details',
      },
    );
  }

  /// D-13. Delivery reminder — 2 hours before scheduled time (legacy)
  static Future<void> notifyDeliveryReminderToday({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String pickupTime,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '📦 Delivery Today',
      message: 'Today: "$donationTitle" pickup with $acceptorName at $pickupTime',
      notificationType: 'delivery_reminder_today',
      data: {
        'donorId': donorId,
        'donationTitle': donationTitle,
        'acceptorName': acceptorName,
        'pickupTime': pickupTime,
        'action': 'view_donation_details',
      },
    );
  }

  /// D-14. CNIC verification approved
  static Future<void> notifyDonorVerificationApproved({
    required String donorId,
    required String ngoName,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '✅ Verification Approved',
      message: 'Your CNIC has been verified by $ngoName. You can now start donating!',
      notificationType: 'donor_verification_approved',
      data: {
        'donorId': donorId,
        'ngoName': ngoName,
        'approved': true,
        'action': 'start_donating',
      },
    );
  }

  /// D-15. CNIC verification rejected
  static Future<void> notifyDonorVerificationRejected({
    required String donorId,
    required String ngoName,
    required String reason,
  }) async {
    await _service.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: '❌ Verification Rejected',
      message: 'Your CNIC verification was rejected by $ngoName. Reason: $reason',
      notificationType: 'donor_verification_rejected',
      data: {
        'donorId': donorId,
        'ngoName': ngoName,
        'approved': false,
        'reason': reason,
        'action': 'resubmit_verification',
      },
    );
  }

  // ACCEPTOR NOTIFICATIONS (14 types)

  /// A-1. New donation available — broadcast to all verified acceptors
  static Future<void> notifyAllAcceptorsOfNewDonation({
    required String donationTitle,
    required String donorName,
    required String donationId,
  }) async {
    try {
      print('📢 Notifying verified acceptors of new donation...');
      print('   Donation: $donationTitle');
      print('   Donor: $donorName');

      final database = FirebaseDatabase.instance.ref();
      final usersSnapshot = await database.child('users').once();

      if (!usersSnapshot.snapshot.exists) {
        print('⚠️ No users found in database');
        return;
      }

      final usersMap = usersSnapshot.snapshot.value as Map<dynamic, dynamic>;
      List<String> verifiedAcceptorIds = [];

      for (var entry in usersMap.entries) {
        final userId = entry.key as String;
        final userData = entry.value as Map<dynamic, dynamic>;

        if (userData['userType'] == 'Acceptor' &&
            userData['verificationStatus'] == 'Approved') {
          verifiedAcceptorIds.add(userId);
        }
      }

      if (verifiedAcceptorIds.isEmpty) {
        print('ℹ️ No verified acceptors to notify');
        return;
      }

      print('📤 Sending to ${verifiedAcceptorIds.length} verified acceptors');

      int successCount = 0;
      for (String acceptorId in verifiedAcceptorIds) {
        try {
          await _service.sendNotification(
            userIds: [acceptorId],
            userType: 'Acceptor',
            title: '🎁 New Donation Available',
            message: '$donorName posted: "$donationTitle"',
            notificationType: 'new_donation',
            data: {
              'donationId': donationId,
              'donationTitle': donationTitle,
              'donorName': donorName,
              'action': 'view_donation',
            },
          );
          successCount++;
        } catch (e) {
          print('   ✗ Failed for acceptor $acceptorId: $e');
        }
      }

      print('✅ Notified $successCount/${verifiedAcceptorIds.length} acceptors');
    } catch (e) {
      print('❌ Error notifying acceptors: $e');
    }
  }

  /// A-2. Acceptor's specific donation request accepted by donor
  static Future<void> notifyAcceptorSpecificRequestAccepted({
    required String acceptorId,
    required String itemRequested,
    required String donorName,
    required String pickupDate,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '✅ Your Request Fulfilled!',
      message: '$donorName will fulfill your request for "$itemRequested". Pickup: $pickupDate',
      notificationType: 'specific_request_accepted',
      data: {
        'acceptorId': acceptorId,
        'itemRequested': itemRequested,
        'donorName': donorName,
        'pickupDate': pickupDate,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-3. Request submitted confirmation — sent to acceptor after they request a donation
  static Future<void> notifyAcceptorRequestConfirmation({
    required String acceptorId,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '📤 Request Sent',
      message: 'Your request for "$donationTitle" has been sent to the donor',
      notificationType: 'acceptor_request_confirmation',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-4. Request approved by donor
  static Future<void> notifyRequestApproved({
    required String acceptorId,
    required String donationTitle,
    required String pickupDate,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '✅ Request Approved!',
      message: 'Your request for "$donationTitle" was approved! Pickup: $pickupDate',
      notificationType: 'request_approved',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'pickupDate': pickupDate,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-5. Request rejected by donor
  static Future<void> notifyRequestRejected({
    required String acceptorId,
    required String donationTitle,
    String? reason,
  }) async {
    final reasonText = reason != null && reason.isNotEmpty ? ' Reason: $reason' : '';

    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '❌ Request Declined',
      message: 'Your request for "$donationTitle" was declined.$reasonText',
      notificationType: 'request_rejected',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'reason': reason ?? '',
        'action': 'browse_donations',
      },
    );
  }

  /// A-6. Schedule change request sent — confirmation to acceptor
  static Future<void> notifyAcceptorScheduleChangeConfirmation({
    required String acceptorId,
    required String donationTitle,
    required String requestedDate,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '📅 Schedule Change Requested',
      message: 'Your schedule change request for "$donationTitle" to $requestedDate has been sent to the donor',
      notificationType: 'acceptor_schedule_change_confirmation',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'requestedDate': requestedDate,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-7. Schedule change approved by donor
  static Future<void> notifyScheduleChangeApproved({
    required String acceptorId,
    required String donationTitle,
    required String newDate,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '✅ Schedule Change Approved',
      message: 'Your request for "$donationTitle" was approved. New pickup: $newDate',
      notificationType: 'schedule_change_approved',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'newDate': newDate,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-8. Schedule change rejected by donor
  static Future<void> notifyScheduleChangeRejected({
    required String acceptorId,
    required String donationTitle,
    String? reason,
  }) async {
    final reasonText = reason != null && reason.isNotEmpty ? ' Reason: $reason' : '';
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '❌ Schedule Change Declined',
      message: 'Your schedule change request for "$donationTitle" was declined.$reasonText',
      notificationType: 'schedule_change_rejected',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'reason': reason ?? '',
        'action': 'view_received_donations',
      },
    );
  }

  /// A-9. Donor is on the way / delivery started
  static Future<void> notifyAcceptorDonorDelivering({
    required String acceptorId,
    required String donationTitle,
    required String donorName,
    required String scheduledTime,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '🚗 Donor is Delivering!',
      message: '$donorName marked "$donationTitle" as delivered. Please confirm receipt.',
      notificationType: 'donor_delivering',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'donorName': donorName,
        'scheduledTime': scheduledTime,
        'action': 'confirm_receipt',
      },
    );
  }

  /// A-10. Pickup reminder — 24 hours before
  static Future<void> notifyPickupReminder24h({
    required String acceptorId,
    required String donationTitle,
    required String pickupTime,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '⏰ Pickup Tomorrow',
      message: 'Reminder: Pick up "$donationTitle" tomorrow at $pickupTime',
      notificationType: 'pickup_reminder_24h',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'pickupTime': pickupTime,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-11. Pickup day reminder — day of pickup
  static Future<void> notifyPickupReminderToday({
    required String acceptorId,
    required String donationTitle,
    required String donorName,
    required String pickupTime,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '📦 Pickup Today',
      message: 'Today: Pick up "$donationTitle" from $donorName at $pickupTime',
      notificationType: 'pickup_reminder_today',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'donorName': donorName,
        'pickupTime': pickupTime,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-12. Pickup reminder — 2 hours before
  static Future<void> notifyPickupReminder2h({
    required String acceptorId,
    required String donationTitle,
    required String location,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '🚨 Pickup in 2 Hours',
      message: 'Don\'t forget: "$donationTitle" pickup in 2 hours at $location',
      notificationType: 'pickup_reminder_2h',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'location': location,
        'action': 'view_received_donations',
      },
    );
  }

  /// A-13. Confirm receipt prompt — donor delivered, acceptor must confirm
  static Future<void> notifyConfirmReceiptPrompt({
    required String acceptorId,
    required String donationTitle,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '✅ Confirm Receipt',
      message: 'Did you receive "$donationTitle"? Please confirm receipt.',
      notificationType: 'confirm_receipt_prompt',
      data: {
        'acceptorId': acceptorId,
        'donationTitle': donationTitle,
        'action': 'confirm_receipt',
      },
    );
  }

  /// A-14. Verification complete — approved or rejected
  static Future<void> notifyVerificationComplete({
    required String userId,
    required bool approved,
    required String ngoName,
    String? userType,
    String? reason,
  }) async {
    final actualUserType = userType ?? 'Acceptor';

    await _service.sendNotification(
      userIds: [userId],
      userType: actualUserType,
      title: approved ? '✅ Verification Approved' : '❌ Verification Rejected',
      message: approved
          ? 'Your identity was verified by $ngoName! You can now request donations.'
          : 'Your verification was rejected by $ngoName.${reason != null ? ' Reason: $reason' : ''}',
      notificationType: 'verification_complete',
      data: {
        'userId': userId,
        'approved': approved,
        'ngoName': ngoName,
        'reason': reason ?? '',
        'action': approved ? 'browse_donations' : 'resubmit_verification',
      },
    );
  }

  /// A-15. Acceptor verification approved by NGO
  static Future<void> notifyAcceptorVerificationApproved({
    required String acceptorId,
    required String ngoName,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '✅ Verification Approved',
      message: 'Your identity has been verified by $ngoName! You can now request donations.',
      notificationType: 'verification_approved',
      data: {
        'acceptorId': acceptorId,
        'ngoName': ngoName,
        'action': 'browse_donations',
      },
    );
  }

  /// A-16. Acceptor verification rejected by NGO
  static Future<void> notifyAcceptorVerificationRejected({
    required String acceptorId,
    required String ngoName,
    required String reason,
  }) async {
    await _service.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: '❌ Verification Rejected',
      message: 'Your verification was rejected by $ngoName. Reason: $reason',
      notificationType: 'verification_rejected',
      data: {
        'acceptorId': acceptorId,
        'ngoName': ngoName,
        'reason': reason,
        'action': 'resubmit_verification',
      },
    );
  }

  // NGO / VERIFIER NOTIFICATIONS (9 types)
  // IMPORTANT: Notifications go ONLY to the ASSIGNED NGO, not all NGOs

  /// N-1. New verification request assigned to a specific NGO
  static Future<void> notifyNewVerificationRequest({
    required List<String> ngoIds,   // Should only contain the ASSIGNED NGO id
    required String userName,
    required String userType,
    String? userId,
  }) async {
    print('📤 Sending verification notification...');
    print('   To NGO(s): $ngoIds');
    print('   For user: $userName ($userType)');

    int successCount = 0;

    for (String ngoId in ngoIds) {
      try {
        await _service.sendNotification(
          userIds: [ngoId],
          userType: 'NGO',
          title: '📋 New Verification Request',
          message: '$userName ($userType) submitted documents for verification',
          notificationType: 'new_verification_assigned',
          data: {
            'userName': userName,
            'userType': userType,
            'userId': userId ?? '',
            'ngoId': ngoId,
            'action': 'review_verification',
          },
        );
        successCount++;
        print('   ✅ Notification sent to NGO: $ngoId');
      } catch (e) {
        print('   ❌ Failed to send notification to NGO $ngoId: $e');
      }
    }

    print(successCount > 0
        ? '✅ Sent to $successCount/${ngoIds.length} NGO(s)'
        : '❌ Failed to send to any NGO');
  }

  /// N-2. Reminder to NGO — last day to verify (24 hours remaining)
  static Future<void> notifyVerificationDeadline24h({
    required String ngoId,
    required String userName,
    String? userId,
  }) async {
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: '⚠️ Verification Due Tomorrow',
      message: '$userName\'s verification expires in 24 hours — please act now',
      notificationType: 'verification_deadline_24h',
      data: {
        'ngoId': ngoId,
        'userName': userName,
        'userId': userId ?? '',
        'hoursLeft': 24,
        'priority': 'high',
        'action': 'review_verification',
      },
    );
  }

  /// N-3. Reminder every 3 hours on the last verification day
  static Future<void> notifyVerificationLastDayReminder({
    required String ngoId,
    required String userName,
    required int hoursLeft,
    String? userId,
  }) async {
    String title;
    String message;
    String priority;

    if (hoursLeft <= 1) {
      title = '🔴 CRITICAL: 1 Hour Left!';
      message = '$userName\'s verification expires in 1 hour! Take action immediately.';
      priority = 'critical';
    } else if (hoursLeft <= 3) {
      title = '🚨 URGENT: $hoursLeft Hours Left';
      message = '$userName\'s verification expires in $hoursLeft hours — immediate action required';
      priority = 'urgent';
    } else if (hoursLeft <= 6) {
      title = '🚨 Urgent: $hoursLeft Hours Left';
      message = '$userName\'s verification expires in $hoursLeft hours';
      priority = 'high';
    } else {
      title = '⏰ Verification Reminder';
      message = '$userName\'s verification expires in $hoursLeft hours';
      priority = 'medium';
    }

    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: title,
      message: message,
      notificationType: 'verification_last_day_reminder',
      data: {
        'ngoId': ngoId,
        'userName': userName,
        'userId': userId ?? '',
        'hoursLeft': hoursLeft,
        'priority': priority,
        'action': 'urgent_review_verification',
      },
    );
  }

  /// N-4. Verification overdue — after deadline passed, send every 3 hours
  static Future<void> notifyVerificationOverdue({
    required String ngoId,
    required String userName,
    required int hoursOverdue,
    String? userId,
  }) async {
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: '🚨 OVERDUE: Verification Required',
      message: '$userName\'s verification is $hoursOverdue hour(s) overdue — please review immediately',
      notificationType: 'verification_overdue',
      data: {
        'ngoId': ngoId,
        'userName': userName,
        'userId': userId ?? '',
        'hoursOverdue': hoursOverdue,
        'priority': 'critical',
        'action': 'urgent_review_verification',
      },
    );
  }

  /// N-5. Verification completed successfully — confirmation to NGO
  static Future<void> notifyNGOVerificationCompleted({
    required String ngoId,
    required String userName,
    required bool approved,
  }) async {
    final status = approved ? 'approved' : 'rejected';
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: approved ? '✅ Verification Approved' : '❌ Verification Rejected',
      message: 'You successfully $status $userName\'s verification',
      notificationType: 'ngo_verification_completed',
      data: {
        'ngoId': ngoId,
        'userName': userName,
        'approved': approved,
        'action': 'view_verification_history',
      },
    );
  }

  /// N-6. Pending verifications summary (daily)
  static Future<void> notifyNGOPendingSummary({
    required String ngoId,
    required int pendingCount,
    required int urgentCount,
  }) async {
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: '📊 Verification Summary',
      message: 'You have $pendingCount pending verification(s) — $urgentCount urgent',
      notificationType: 'ngo_pending_summary',
      data: {
        'ngoId': ngoId,
        'pendingCount': pendingCount,
        'urgentCount': urgentCount,
        'action': 'view_pending_verifications',
      },
    );
  }

  /// N-7. Weekly statistics
  static Future<void> notifyNGOWeeklyStats({
    required String ngoId,
    required int verificationsCompleted,
    required int pendingVerifications,
  }) async {
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: '📊 Weekly Report',
      message: 'You verified $verificationsCompleted users this week. $pendingVerifications pending.',
      notificationType: 'ngo_weekly_stats',
      data: {
        'ngoId': ngoId,
        'verificationsCompleted': verificationsCompleted,
        'pendingVerifications': pendingVerifications,
        'action': 'view_dashboard',
      },
    );
  }

  /// N-8. New user registered — only relevant NGOs notified (e.g. assigned NGO)
  static Future<void> notifyNGONewUserRegistered({
    required List<String> ngoIds,
    required String userName,
    required String userType,
  }) async {
    for (String ngoId in ngoIds) {
      await _service.sendNotification(
        userIds: [ngoId],
        userType: 'NGO',
        title: '👤 New User Registered',
        message: '$userName registered as $userType',
        notificationType: 'ngo_new_user_registered',
        data: {
          'ngoId': ngoId,
          'userName': userName,
          'userType': userType,
          'action': 'view_dashboard',
        },
      );
    }
  }

  /// N-9. System alert (suspicious activity, policy violations)
  static Future<void> notifyNGOSystemAlert({
    required String ngoId,
    required String alertType,
    required String alertMessage,
    String? userId,
  }) async {
    await _service.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: '🚨 System Alert: $alertType',
      message: alertMessage,
      notificationType: 'ngo_system_alert',
      data: {
        'ngoId': ngoId,
        'alertType': alertType,
        'userId': userId ?? '',
        'priority': 'high',
        'action': 'investigate_alert',
      },
    );
  }

  // UTILITY METHODS

  /// Clean up old notifications (older than specified days)
  static Future<void> cleanupOldNotifications({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final supabase = Supabase.instance.client;

      await supabase
          .from('notification_logs')
          .delete()
          .lt('sent_at', cutoffDate.toIso8601String());

      print('✅ Cleaned up notifications older than $daysOld days');
    } catch (e) {
      print('❌ Error cleaning up notifications: $e');
    }
  }

  // NUCLEAR CLEAR — wipes ALL Supabase notification data for ALL users.
  // Call this when clearing all app data from Firebase.

  /// Deletes every row from notification_logs AND notification_tokens.
  /// Returns a result map with counts of deleted rows, or error messages.
  static Future<Map<String, dynamic>> clearAllNotificationData() async {
    final result = <String, dynamic>{
      'logsDeleted': false,
      'tokensDeleted': false,
      'errors': <String>[],
    };

    try {
      print('=== CLEARING ALL SUPABASE NOTIFICATION DATA ===');
      final supabase = Supabase.instance.client;

      // 1. Delete all notification logs
      try {
        // Supabase requires a filter to delete — use gte on sent_at epoch start
        await supabase
            .from('notification_logs')
            .delete()
            .gte('sent_at', '2000-01-01T00:00:00.000Z');
        result['logsDeleted'] = true;
        print('✅ notification_logs cleared');
      } catch (e) {
        final msg = 'Failed to clear notification_logs: $e';
        print('❌ $msg');
        (result['errors'] as List<String>).add(msg);
      }

      // 2. Delete all notification tokens (device registrations)
      try {
        await supabase
            .from('notification_tokens')
            .delete()
            .gte('updated_at', '2000-01-01T00:00:00.000Z');
        result['tokensDeleted'] = true;
        print('✅ notification_tokens cleared');
      } catch (e) {
        // updated_at may not exist — try a different filter
        try {
          await supabase
              .from('notification_tokens')
              .delete()
              .neq('user_id', 'IMPOSSIBLE_ID_THAT_NEVER_EXISTS');
          result['tokensDeleted'] = true;
          print('✅ notification_tokens cleared (fallback filter)');
        } catch (e2) {
          final msg = 'Failed to clear notification_tokens: $e2';
          print('❌ $msg');
          (result['errors'] as List<String>).add(msg);
        }
      }

      print('=== SUPABASE CLEAR COMPLETE ===');
      print('  Logs cleared: ${result['logsDeleted']}');
      print('  Tokens cleared: ${result['tokensDeleted']}');
      if ((result['errors'] as List).isNotEmpty) {
        print('  Errors: ${result['errors']}');
      }
    } catch (e) {
      print('❌ Unexpected error during clearAllNotificationData: $e');
      (result['errors'] as List<String>).add('Unexpected error: $e');
    }

    return result;
  }
}

// DELIVERY REMINDER SCHEDULER
// Manages 2-hour interval reminders on delivery day
class DeliveryReminderScheduler {
  static final Map<String, Timer> _activeTimers = {};

  /// Start delivery day reminders for a donor
  /// Fires immediately, then every 2 hours until scheduledTime
  static Future<void> startDeliveryDayReminders({
    required String donorId,
    required String donationId,
    required String donationTitle,
    required String acceptorName,
    required DateTime scheduledDateTime,
    required String location,
  }) async {
    // Cancel any existing timer for this donation
    cancelReminders(donationId);

    final now = DateTime.now();
    final scheduledTime = scheduledDateTime;

    // Don't schedule if already past scheduled time
    if (now.isAfter(scheduledTime)) return;

    // Fire immediately — delivery day started
    await SupabaseNotificationHelper.notifyDeliveryDayStarted(
      donorId: donorId,
      donationTitle: donationTitle,
      acceptorName: acceptorName,
      scheduledTime: '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}',
      location: location,
    );

    // Schedule 2-hourly reminders
    _schedulePeriodicReminders(
      donorId: donorId,
      donationId: donationId,
      donationTitle: donationTitle,
      acceptorName: acceptorName,
      scheduledDateTime: scheduledDateTime,
      location: location,
    );
  }

  static void _schedulePeriodicReminders({
    required String donorId,
    required String donationId,
    required String donationTitle,
    required String acceptorName,
    required DateTime scheduledDateTime,
    required String location,
  }) {
    // Check every 2 hours and fire reminder
    final timer = Timer.periodic(const Duration(hours: 2), (timer) async {
      final now = DateTime.now();

      // Stop if past scheduled time
      if (now.isAfter(scheduledDateTime)) {
        timer.cancel();
        _activeTimers.remove(donationId);
        return;
      }

      final diff = scheduledDateTime.difference(now);
      final hoursUntilDelivery = diff.inHours;

      await SupabaseNotificationHelper.notifyDeliveryReminder2hInterval(
        donorId: donorId,
        donationTitle: donationTitle,
        acceptorName: acceptorName,
        scheduledTime: '${scheduledDateTime.hour.toString().padLeft(2, '0')}:${scheduledDateTime.minute.toString().padLeft(2, '0')}',
        hoursUntilDelivery: hoursUntilDelivery,
      );
    });

    _activeTimers[donationId] = timer;
  }

  /// Cancel reminders for a specific donation (e.g., when delivered)
  static void cancelReminders(String donationId) {
    if (_activeTimers.containsKey(donationId)) {
      _activeTimers[donationId]!.cancel();
      _activeTimers.remove(donationId);
      print('🛑 Cancelled delivery reminders for donation: $donationId');
    }
  }

  /// Cancel all active reminders
  static void cancelAll() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    print('🛑 Cancelled all delivery reminders');
  }
}

// NGO VERIFICATION REMINDER SCHEDULER
// Manages 3-hour interval reminders on the last verification day
class NGOVerificationReminderScheduler {
  static final Map<String, Timer> _activeTimers = {};

  /// Start last-day verification reminders for an NGO
  /// Fires immediately when last day starts, then every 3 hours until deadline
  static Future<void> startLastDayReminders({
    required String ngoId,
    required String userName,
    required String userId,
    required DateTime deadline,
  }) async {
    // Cancel any existing timer for this verification
    cancelReminders(userId);

    final now = DateTime.now();

    // Don't schedule if already past deadline
    if (now.isAfter(deadline)) {
      // Still fire overdue notification
      final hoursOverdue = now.difference(deadline).inHours;
      await SupabaseNotificationHelper.notifyVerificationOverdue(
        ngoId: ngoId,
        userName: userName,
        hoursOverdue: hoursOverdue > 0 ? hoursOverdue : 1,
        userId: userId,
      );
      return;
    }

    final hoursLeft = deadline.difference(now).inHours;

    // Fire immediate last-day notification
    await SupabaseNotificationHelper.notifyVerificationDeadline24h(
      ngoId: ngoId,
      userName: userName,
      userId: userId,
    );

    // Schedule 3-hourly reminders
    final timer = Timer.periodic(const Duration(hours: 3), (timer) async {
      final currentNow = DateTime.now();

      if (currentNow.isAfter(deadline)) {
        // Deadline passed — send overdue notification every 3 hours
        final hoursOverdue = currentNow.difference(deadline).inHours;
        await SupabaseNotificationHelper.notifyVerificationOverdue(
          ngoId: ngoId,
          userName: userName,
          hoursOverdue: hoursOverdue > 0 ? hoursOverdue : 1,
          userId: userId,
        );
      } else {
        final remaining = deadline.difference(currentNow).inHours;
        await SupabaseNotificationHelper.notifyVerificationLastDayReminder(
          ngoId: ngoId,
          userName: userName,
          hoursLeft: remaining > 0 ? remaining : 1,
          userId: userId,
        );
      }
    });

    _activeTimers[userId] = timer;
  }

  /// Cancel reminders for a specific verification (e.g., when verified)
  static void cancelReminders(String userId) {
    if (_activeTimers.containsKey(userId)) {
      _activeTimers[userId]!.cancel();
      _activeTimers.remove(userId);
      print('🛑 Cancelled verification reminders for: $userId');
    }
  }
}