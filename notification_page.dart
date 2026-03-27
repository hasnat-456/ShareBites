import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'supabase_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;
  final String userType;

  const NotificationsPage({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SupabaseNotificationService _notificationService = SupabaseNotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await _notificationService.getNotificationHistory(widget.userId);

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(dynamic notificationId, int index) async {
    try {
      final idString = notificationId.toString();
      await _notificationService.markAsRead(idString);

      setState(() {
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    try {
      DateTime dateTime;

      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return 'Unknown time';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, yyyy').format(dateTime);
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type ?? 'general') {
      case 'donation_accepted':
        return Icons.check_circle;
      case 'new_donation':
        return Icons.card_giftcard;
      case 'schedule_change_request':
        return Icons.schedule;
      case 'schedule_change_approved':
        return Icons.check;
      case 'verification_complete':
        return Icons.verified_user;
      case 'new_verification_assigned':
        return Icons.assignment;
      case 'verification_deadline_warning':
        return Icons.warning;
      case 'verification_deadline_last_day':
        return Icons.error;
      case 'ngo_verification_completed':
        return Icons.done_all;
      case 'ngo_system_alert':
        return Icons.report_problem;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type ?? 'general') {
      case 'donation_accepted':
        return Colors.green;
      case 'new_donation':
        return Colors.orange;
      case 'schedule_change_request':
        return Colors.blue;
      case 'schedule_change_approved':
        return Colors.green;
      case 'verification_complete':
        return Colors.purple;
      case 'new_verification_assigned':
        return Colors.blue;
      case 'verification_deadline_warning':
        return Colors.orange;
      case 'verification_deadline_last_day':
        return Colors.red;
      case 'ngo_verification_completed':
        return Colors.green;
      case 'ngo_system_alert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color appBarColor = Colors.green;
    if (widget.userType == 'NGO') {
      appBarColor = Colors.blue;
    } else if (widget.userType == 'Acceptor') {
      appBarColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: appBarColor,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadNotifications,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when they arrive',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final isRead = notification['read_at'] != null;
          final type = notification['notification_type'] as String?;
          final notificationId = notification['id'];

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            elevation: isRead ? 0 : 2,
            color: isRead ? Colors.grey[100] : Colors.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getNotificationColor(type).withOpacity(0.2),
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
              title: Text(
                notification['title'] ?? 'Notification',
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    notification['message'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification['sent_at']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              trailing: !isRead
                  ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
                  : null,
              onTap: () {
                if (!isRead && notificationId != null) {
                  _markAsRead(notificationId, index);
                }
              },
            ),
          );
        },
      ),
    );
  }
}