import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'notification_config.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String ONESIGNAL_APP_ID = NotificationConfig.ONESIGNAL_APP_ID;
  static const String SUPABASE_URL = NotificationConfig.SUPABASE_URL;
  static const String SUPABASE_ANON_KEY = NotificationConfig.SUPABASE_ANON_KEY;

  late SupabaseClient _supabase;
  String? _currentPlayerId;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: SUPABASE_URL,
        anonKey: SUPABASE_ANON_KEY,
      );
      _supabase = Supabase.instance.client;

      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(ONESIGNAL_APP_ID);

      await OneSignal.Notifications.requestPermission(true);

      _setupNotificationHandlers();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  void _setupNotificationHandlers() {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        _handleNotificationClick(data);
      }
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    OneSignal.User.pushSubscription.addObserver((state) {
      if (state.current.id != null) {
        _currentPlayerId = state.current.id;
      }
    });
  }

  Future<void> registerUser({
    required String userId,
    required String userType,
  }) async {
    try {
      await OneSignal.login(userId);
      await Future.delayed(const Duration(seconds: 2));

      final playerId = OneSignal.User.pushSubscription.id;

      if (playerId == null) return;

      _currentPlayerId = playerId;

      await _supabase
          .from('notification_tokens')
          .upsert({
        'user_id': userId,
        'user_type': userType,
        'onesignal_player_id': playerId,
        'device_type': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error registering user for notifications: $e');
    }
  }

  Future<void> unregisterUser(String userId) async {
    try {
      await _supabase.from('notification_tokens').delete().eq('user_id', userId);
      await OneSignal.logout();
      _currentPlayerId = null;
    } catch (e) {
      print('Error unregistering user: $e');
    }
  }

  Future<bool> sendNotification({
    required List<String> userIds,
    String? userType,
    required String title,
    required String message,
    required String notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        'userIds': userIds,
        if (userType != null) 'userType': userType,
        'title': title,
        'message': message,
        'notificationType': notificationType,
        if (data != null) 'data': data,
      };

      final response = await http.post(
        Uri.parse('$SUPABASE_URL/functions/v1/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $SUPABASE_ANON_KEY',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to send notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationHistory(String userId) async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting notification history: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notification_logs')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null);

      return response.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('Handling notification click with data: $data');
  }

  bool get areNotificationsEnabled => _currentPlayerId != null;

  String? get playerId => _currentPlayerId;
}

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();

  // DONOR NOTIFICATIONS

  static Future<void> notifyDonorOfNewRequest({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String requestId,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'New Donation Request',
      message: '$acceptorName requested your "$donationTitle" donation',
      notificationType: 'donation_request_received',
      data: {
        'action': 'view_request',
        'requestId': requestId,
        'donationTitle': donationTitle,
      },
    );
  }

  static Future<void> notifyDonorOfSpecialRequest({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String requestMessage,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Special Request from Acceptor',
      message: '$acceptorName sent a special request for "$donationTitle"',
      notificationType: 'special_request_received',
      data: {
        'action': 'view_special_request',
        'donationTitle': donationTitle,
        'message': requestMessage,
      },
    );
  }

  static Future<void> notifyDonorOfScheduleChangeRequest({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required String currentSchedule,
    required String requestedSchedule,
    required String reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Schedule Change Requested',
      message: '$acceptorName wants to reschedule "$donationTitle" from $currentSchedule to $requestedSchedule',
      notificationType: 'schedule_change_request',
      data: {
        'action': 'review_schedule_change',
        'donationTitle': donationTitle,
        'currentSchedule': currentSchedule,
        'requestedSchedule': requestedSchedule,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyDonorScheduleChangeAccepted({
    required String donorId,
    required String donationTitle,
    required String newSchedule,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Schedule Change Accepted',
      message: 'Your schedule change for "$donationTitle" is now set for $newSchedule',
      notificationType: 'donor_schedule_change_accepted',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'newSchedule': newSchedule,
      },
    );
  }

  static Future<void> notifyDonorFeedbackReceived({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    required double rating,
    required String? comment,
  }) async {
    final ratingStars = '★' * rating.round();
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Feedback Received',
      message: '$acceptorName rated your "$donationTitle" donation $ratingStars',
      notificationType: 'feedback_received',
      data: {
        'action': 'view_feedback',
        'donationTitle': donationTitle,
        'rating': rating,
        'comment': comment,
      },
    );
  }

  static Future<void> notifyDonorDeliveryReminderOneDayBefore({
    required String donorId,
    required String donationTitle,
    required String scheduleDate,
    required String scheduleTime,
    required String acceptorName,
    required String location,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Delivery Tomorrow',
      message: 'Reminder: Deliver "$donationTitle" tomorrow at $scheduleTime to $acceptorName',
      notificationType: 'delivery_reminder_1day',
      data: {
        'action': 'view_donation_details',
        'donationTitle': donationTitle,
        'scheduleDate': scheduleDate,
        'scheduleTime': scheduleTime,
        'location': location,
      },
    );
  }

  static Future<void> notifyDonorDeliveryReminderSameDay({
    required String donorId,
    required String donationTitle,
    required String scheduleTime,
    required String acceptorName,
    required String location,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Delivery in 2 Hours',
      message: 'Don\'t forget: Deliver "$donationTitle" at $scheduleTime to $acceptorName',
      notificationType: 'delivery_reminder_2hours',
      data: {
        'action': 'start_delivery',
        'donationTitle': donationTitle,
        'scheduleTime': scheduleTime,
        'location': location,
      },
    );
  }

  static Future<void> notifyDonorDeliveryCompleted({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Donation Delivered',
      message: 'Your "$donationTitle" has been successfully delivered to $acceptorName',
      notificationType: 'donation_delivered',
      data: {
        'action': 'view_donation_history',
        'donationTitle': donationTitle,
      },
    );
  }

  static Future<void> notifyDonorRequestCancelled({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
    String? reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Request Cancelled',
      message: '$acceptorName cancelled request for "$donationTitle"',
      notificationType: 'request_cancelled',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyDonorVerificationApproved({
    required String donorId,
    required String ngoName,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Verification Approved',
      message: 'Your CNIC has been verified by $ngoName. You can now donate!',
      notificationType: 'donor_verification_approved',
      data: {
        'action': 'start_donating',
        'approved': true,
      },
    );
  }

  static Future<void> notifyDonorVerificationRejected({
    required String donorId,
    required String ngoName,
    required String reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Verification Rejected',
      message: 'Your CNIC verification was rejected by $ngoName. Reason: $reason',
      notificationType: 'donor_verification_rejected',
      data: {
        'action': 'resubmit_verification',
        'approved': false,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyDonationRequestAccepted({
    required String donorId,
    required String donationTitle,
    required String acceptorName,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Request Accepted',
      message: '$acceptorName has accepted your donation request for "$donationTitle"',
      notificationType: 'donation_request_accepted',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
      },
    );
  }

  static Future<void> notifyDonationDelivered({
    required String donorId,
    required String donationTitle,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Donation Delivered',
      message: 'Your donation "$donationTitle" has been marked as delivered. Awaiting confirmation.',
      notificationType: 'donation_delivered',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
      },
    );
  }

  static Future<void> notifyNewDonationNearby({
    required List<String> acceptorIds,
    required String donationTitle,
    required String location,
  }) async {
    if (acceptorIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: acceptorIds,
      userType: 'Acceptor',
      title: 'New Donation Nearby',
      message: '"$donationTitle" available at $location',
      notificationType: 'new_donation_nearby',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'location': location,
      },
    );
  }

  static Future<void> notifyDonationApproved({
    required String acceptorId,
    required String donationTitle,
    required String pickupTime,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Donation Approved',
      message: 'Your request for "$donationTitle" has been approved. Pickup time: $pickupTime',
      notificationType: 'donation_approved',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'pickupTime': pickupTime,
      },
    );
  }

  // ACCEPTOR NOTIFICATIONS

  static Future<void> notifyAcceptorNewDonation({
    required List<String> acceptorIds,
    required String donationTitle,
    required String category,
    required String location,
    required String donorName,
    required String distance,
  }) async {
    if (acceptorIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: acceptorIds,
      userType: 'Acceptor',
      title: 'New Donation Available',
      message: '"$donationTitle" ($category) - $distance away at $location',
      notificationType: 'new_donation_available',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'category': category,
        'location': location,
        'donorName': donorName,
      },
    );
  }

  static Future<void> notifyAcceptorRequestApproved({
    required String acceptorId,
    required String donationTitle,
    required String scheduleDate,
    required String scheduleTime,
    required String location,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Request Approved',
      message: 'Your request for "$donationTitle" is approved! Pickup: $scheduleDate at $scheduleTime',
      notificationType: 'acceptor_request_approved',
      data: {
        'action': 'view_approved_donation',
        'donationTitle': donationTitle,
        'scheduleDate': scheduleDate,
        'scheduleTime': scheduleTime,
        'location': location,
      },
    );
  }

  static Future<void> notifyAcceptorScheduleChangeSubmitted({
    required String acceptorId,
    required String donationTitle,
    required String requestedSchedule,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Schedule Change Requested',
      message: 'Your request to reschedule "$donationTitle" to $requestedSchedule has been sent to the donor',
      notificationType: 'acceptor_schedule_change_submitted',
      data: {
        'action': 'wait_for_approval',
        'donationTitle': donationTitle,
        'requestedSchedule': requestedSchedule,
      },
    );
  }

  static Future<void> notifyAcceptorScheduleChangeApproved({
    required String acceptorId,
    required String donationTitle,
    required String newScheduleDate,
    required String newScheduleTime,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Schedule Changed',
      message: 'Your schedule change for "$donationTitle" is approved! New time: $newScheduleDate at $newScheduleTime',
      notificationType: 'acceptor_schedule_change_approved',
      data: {
        'action': 'view_updated_schedule',
        'donationTitle': donationTitle,
        'newScheduleDate': newScheduleDate,
        'newScheduleTime': newScheduleTime,
      },
    );
  }

  static Future<void> notifyAcceptorScheduleChangeRejected({
    required String acceptorId,
    required String donationTitle,
    String? reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Schedule Change Declined',
      message: 'Your schedule change request for "$donationTitle" was not approved',
      notificationType: 'acceptor_schedule_change_rejected',
      data: {
        'action': 'view_original_schedule',
        'donationTitle': donationTitle,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyAcceptorDonorOnTheWay({
    required String acceptorId,
    required String donationTitle,
    required String donorName,
    required String estimatedArrival,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Donor On The Way',
      message: '$donorName is delivering "$donationTitle". Estimated arrival: $estimatedArrival',
      notificationType: 'donor_on_the_way',
      data: {
        'action': 'track_delivery',
        'donationTitle': donationTitle,
        'donorName': donorName,
        'estimatedArrival': estimatedArrival,
      },
    );
  }

  static Future<void> notifyAcceptorPickupReminderOneDayBefore({
    required String acceptorId,
    required String donationTitle,
    required String scheduleDate,
    required String scheduleTime,
    required String location,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Pickup Tomorrow',
      message: 'Reminder: Pickup "$donationTitle" tomorrow at $scheduleTime from $location',
      notificationType: 'pickup_reminder_1day',
      data: {
        'action': 'view_pickup_details',
        'donationTitle': donationTitle,
        'scheduleDate': scheduleDate,
        'scheduleTime': scheduleTime,
        'location': location,
      },
    );
  }

  static Future<void> notifyAcceptorPickupReminderTwoHours({
    required String acceptorId,
    required String donationTitle,
    required String scheduleTime,
    required String location,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Pickup in 2 Hours',
      message: 'Don\'t forget: Pickup "$donationTitle" at $scheduleTime from $location',
      notificationType: 'pickup_reminder_2hours',
      data: {
        'action': 'prepare_for_pickup',
        'donationTitle': donationTitle,
        'scheduleTime': scheduleTime,
        'location': location,
      },
    );
  }

  static Future<void> notifyAcceptorVerificationApproved({
    required String acceptorId,
    required String ngoName,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Verification Approved',
      message: 'Your CNIC has been verified by $ngoName. You can now request donations!',
      notificationType: 'acceptor_verification_approved',
      data: {
        'action': 'browse_donations',
        'approved': true,
      },
    );
  }

  static Future<void> notifyAcceptorVerificationRejected({
    required String acceptorId,
    required String ngoName,
    required String reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Verification Rejected',
      message: 'Your CNIC verification was rejected by $ngoName. Reason: $reason',
      notificationType: 'acceptor_verification_rejected',
      data: {
        'action': 'resubmit_verification',
        'approved': false,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyAcceptorDonationCancelled({
    required String acceptorId,
    required String donationTitle,
    String? reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Donation Cancelled',
      message: 'The donor cancelled "$donationTitle"',
      notificationType: 'donation_cancelled',
      data: {
        'action': 'browse_other_donations',
        'donationTitle': donationTitle,
        'reason': reason,
      },
    );
  }

  static Future<void> notifyAcceptorRequestRejected({
    required String acceptorId,
    required String donationTitle,
    String? reason,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Request Not Approved',
      message: 'Your request for "$donationTitle" was not approved',
      notificationType: 'acceptor_request_rejected',
      data: {
        'action': 'view_other_donations',
        'donationTitle': donationTitle,
        'reason': reason,
      },
    );
  }

  // NGO/VERIFIER NOTIFICATIONS

  static Future<void> notifyNewVerificationRequest({
    required List<String> ngoIds,
    required String userName,
    required String userType,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'New Verification Request',
      message: '$userName ($userType) submitted documents for verification',
      notificationType: 'new_verification_assigned',
      data: {
        'action': 'review_verification',
        'userName': userName,
        'userType': userType,
      },
    );
  }

  static Future<void> notifyNGOVerificationDeadlineLastDay({
    required List<String> ngoIds,
    required String userName,
    required String userType,
    required String userId,
    required String submittedDate,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'Verification Deadline Today',
      message: 'Last day to verify $userName\'s ($userType) CNIC - Submitted on $submittedDate',
      notificationType: 'verification_deadline_last_day',
      data: {
        'action': 'urgent_review_verification',
        'userId': userId,
        'userName': userName,
        'userType': userType,
        'priority': 'high',
      },
    );
  }

  static Future<void> notifyNGOVerificationOverdue({
    required List<String> ngoIds,
    required String userName,
    required String userType,
    required String userId,
    required int hoursOverdue,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'URGENT: Verification Overdue',
      message: '$userName\'s ($userType) verification is $hoursOverdue hours overdue - Please review immediately',
      notificationType: 'verification_overdue',
      data: {
        'action': 'urgent_review_verification',
        'userId': userId,
        'userName': userName,
        'userType': userType,
        'hoursOverdue': hoursOverdue,
        'priority': 'critical',
      },
    );
  }

  static Future<void> notifyNGOPendingVerificationsSummary({
    required List<String> ngoIds,
    required int pendingCount,
    required int urgentCount,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'Daily Verification Summary',
      message: 'You have $pendingCount pending verifications ($urgentCount urgent)',
      notificationType: 'verification_daily_summary',
      data: {
        'action': 'view_pending_verifications',
        'pendingCount': pendingCount,
        'urgentCount': urgentCount,
      },
    );
  }

  static Future<void> notifyNGOUserFeedback({
    required List<String> ngoIds,
    required String userName,
    required String feedbackType,
    required String feedbackSummary,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'New ${feedbackType.toUpperCase()}',
      message: '$userName submitted a $feedbackType: $feedbackSummary',
      notificationType: 'ngo_user_feedback',
      data: {
        'action': 'review_feedback',
        'userName': userName,
        'feedbackType': feedbackType,
      },
    );
  }

  static Future<void> notifyNGOSystemAlert({
    required List<String> ngoIds,
    required String alertType,
    required String alertMessage,
    required String userId,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'System Alert: $alertType',
      message: alertMessage,
      notificationType: 'ngo_system_alert',
      data: {
        'action': 'investigate_alert',
        'alertType': alertType,
        'userId': userId,
        'priority': 'high',
      },
    );
  }

  static Future<void> notifyNGOVerificationCompleted({
    required String ngoId,
    required String userName,
    required String userType,
    required bool approved,
  }) async {
    final status = approved ? 'approved' : 'rejected';
    await _notificationService.sendNotification(
      userIds: [ngoId],
      userType: 'NGO',
      title: 'Verification $status',
      message: 'You successfully $status $userName\'s ($userType) verification',
      notificationType: 'ngo_verification_completed',
      data: {
        'action': 'view_verification_history',
        'userName': userName,
        'userType': userType,
        'approved': approved,
      },
    );
  }

  static Future<void> notifyNGONewUserRegistered({
    required List<String> ngoIds,
    required String userName,
    required String userType,
    required String registrationDate,
  }) async {
    if (ngoIds.isEmpty) return;

    await _notificationService.sendNotification(
      userIds: ngoIds,
      userType: 'NGO',
      title: 'New User Registered',
      message: '$userName registered as $userType on $registrationDate',
      notificationType: 'ngo_new_user_registered',
      data: {
        'action': 'view_user_details',
        'userName': userName,
        'userType': userType,
      },
    );
  }

  static Future<void> notifyVerificationComplete({
    required String userId,
    required String userType,
    required bool approved,
    required String ngoName,
  }) async {
    await _notificationService.sendNotification(
      userIds: [userId],
      userType: userType,
      title: approved ? 'Verification Approved' : 'Verification Rejected',
      message: approved
          ? 'Your verification has been approved by $ngoName. You can now use the app.'
          : 'Your verification was rejected by $ngoName. Please contact support.',
      notificationType: 'verification_complete',
      data: {
        'action': approved ? 'proceed_to_app' : 'contact_support',
        'approved': approved,
        'ngoName': ngoName,
      },
    );
  }

  static Future<void> notifyScheduleChangeRequest({
    required String donorId,
    required String donationTitle,
    required String requestedDate,
  }) async {
    await _notificationService.sendNotification(
      userIds: [donorId],
      userType: 'Donor',
      title: 'Schedule Change Request',
      message: 'An acceptor has requested to change the schedule for "$donationTitle" to $requestedDate',
      notificationType: 'schedule_change_request',
      data: {
        'action': 'review_schedule_change',
        'donationTitle': donationTitle,
        'requestedDate': requestedDate,
      },
    );
  }

  static Future<void> notifyScheduleChangeApproved({
    required String acceptorId,
    required String donationTitle,
    required String newDate,
  }) async {
    await _notificationService.sendNotification(
      userIds: [acceptorId],
      userType: 'Acceptor',
      title: 'Schedule Change Approved',
      message: 'Your schedule change for "$donationTitle" has been approved. New pickup: $newDate',
      notificationType: 'schedule_change_approved',
      data: {
        'action': 'view_donation',
        'donationTitle': donationTitle,
        'newDate': newDate,
      },
    );
  }
}