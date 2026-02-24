import 'package:flutter/material.dart';
import 'donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/donor/add_donation.dart';
import 'package:sharebites/acceptor/donor_request_approval_dialog.dart';

// ============================================
// DONOR SCHEDULE CHANGE INTEGRATION IMPORTS
// ============================================
import 'package:sharebites/schedule/schedule_change_service.dart';
import 'package:sharebites/models/schedule_change_model.dart';
import 'package:sharebites/schedule/schedule_change_request_dialog.dart';
import 'package:sharebites/schedule/schedule_change_response_dialog.dart';

class MyDonations extends StatefulWidget {
  const MyDonations({super.key});

  @override
  State<MyDonations> createState() => _MyDonationsState();
}

class _MyDonationsState extends State<MyDonations> {
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();
  final ScheduleChangeService _scheduleChangeService = ScheduleChangeService();

  List<Donation> _donations = [];
  bool _isLoading = true;
  String _filter = 'All'; // All, Pending, Reserved, Completed, Expired

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);

    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      try {
        final donations = await _donationService.getDonationsByDonor(currentUser.id);
        setState(() {
          _donations = donations;
          _isLoading = false;
        });
      } catch (e) {
        print("Error loading donations: $e");
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<Donation> get _filteredDonations {
    switch (_filter) {
      case 'Pending':
        return _donations.where((d) => d.status == 'Pending').toList();
      case 'Reserved':
        return _donations.where((d) => d.status == 'Reserved').toList();
      case 'Completed':
        return _donations.where((d) => d.status == 'Completed').toList();
      case 'Expired':
        return _donations.where((d) => d.isExpired && d.status != 'Completed').toList();
      default:
        return _donations;
    }
  }

  int get _pendingCount => _donations.where((d) => d.status == 'Pending').length;
  int get _reservedCount => _donations.where((d) => d.status == 'Reserved').length;
  int get _completedCount => _donations.where((d) => d.status == 'Completed').length;
  int get _expiredCount => _donations.where((d) => d.isExpired && d.status != 'Completed').length;

  void _markAsCompleted(String donationId) async {
    final success = await _donationService.completeDonation(donationId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation marked as completed'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDonations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark donation as completed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _reviewAndSchedule(Donation donation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonorRequestApprovalDialog(
          donation: donation,
          onAccept: () async {
            Navigator.pop(context);
            final success = await _donationService.acceptAndScheduleDonation(donation.id);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Schedule confirmed!"),
                  backgroundColor: Colors.green,
                ),
              );
              _loadDonations();
            }
          },
          onReject: () {
            Navigator.pop(context);
            // Could add reject functionality
          },
        ),
      ),
    );
  }

  void _markAsDelivered(Donation donation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark as Delivered"),
        content: Text(
          "Confirm that you have delivered this donation to ${donation.acceptorName ?? 'the acceptor'}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _donationService.markAsDelivered(donation.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Marked as delivered! Waiting for acceptor confirmation."),
            backgroundColor: Colors.green,
          ),
        );
        _loadDonations();
      }
    }
  }

  // ============================================
  // DONOR SCHEDULE CHANGE METHODS
  // ============================================

  void _requestScheduleChange(Donation donation) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ScheduleChangeRequestDialog(
          donation: donation,
          userRole: 'donor',
        ),
      );

      if (result != null && result.isNotEmpty) {
        final currentUser = _authService.currentUser;
        if (currentUser == null) return;

        final success = await _scheduleChangeService.createScheduleChangeRequest(
          donationId: donation.id,
          requestedBy: 'donor',
          requesterId: currentUser.id,
          requesterName: currentUser.name,
          newScheduledDate: result['newScheduledDate'],
          newScheduledTime: result['newScheduledTime'],
          newDeliveryMethod: result['newDeliveryMethod'],
          changeReason: result['changeReason'] ?? 'No reason provided',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule change request sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDonations();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send schedule change request. Check console for details.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _requestScheduleChange: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _respondToScheduleChange(Donation donation) async {
    try {
      final changeRequest = await _scheduleChangeService.getScheduleChangeRequest(donation.id);

      if (changeRequest == null || changeRequest.status != 'Pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pending schedule change request found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show response dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ScheduleChangeResponseDialog(
          changeRequest: changeRequest,
          currentUserRole: 'donor', // Added required parameter
        ),
      );

      if (result != null && result.isNotEmpty) {
        final action = result['action'];
        final responseNote = result['responseNote'] ?? '';

        if (action == 'accept') {
          await _scheduleChangeService.acceptScheduleChange(changeRequest.id, responseNote);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Schedule change accepted! Donation updated.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          await _scheduleChangeService.rejectScheduleChange(changeRequest.id, responseNote);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Schedule change request rejected'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        _loadDonations(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDonationDetails(Donation donation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(donation.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Type', donation.type),
              _detailRow('Weight', donation.weight),
              _detailRow('Donation Date', donation.donationDate.toLocal().toString().split(' ')[0]),
              _detailRow('Expiry Date', donation.expiryDate.toLocal().toString().split(' ')[0]),
              _detailRow('Status', donation.status),
              if (donation.type == 'Food' && donation.foodStatus != null)
                _detailRow('Food Status', donation.foodStatus!),
              if (donation.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(donation.description),
                    ],
                  ),
                ),
              if (donation.acceptorName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acceptor Information:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text('Name: ${donation.acceptorName!}'),
                      if (donation.requestedDate != null)
                        Text('Requested: ${donation.requestedDate!.toLocal().toString().split(' ')[0]}'),
                    ],
                  ),
                ),
              if (donation.completedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Completed:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(donation.completedDate!.toLocal().toString().split(' ')[0]),
                    ],
                  ),
                ),
              // Show Feedback & Rating if donation is completed
              if (donation.status == 'Completed' && donation.feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(donation.feedback!),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Rating: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Icon(Icons.star, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(donation.rating != null ? donation.rating!.toStringAsFixed(1) : '-'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (donation.status == 'Reserved')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsCompleted(donation.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Completed'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Donation donation) {
    Color statusColor;
    IconData statusIcon;

    switch (donation.status) {
      case 'Completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Reserved':
      case 'Scheduled':
        statusColor = Colors.orange;
        statusIcon = Icons.person;
        break;
      case 'Expired':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _viewDonationDetails(donation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      donation.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          donation.status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Type & Weight
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(donation.type, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.scale, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(donation.weight, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 8),
              // Expiry
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: donation.isExpired ? Colors.red : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Expires: ${donation.expiryDate.toLocal().toString().split(' ')[0]}',
                    style: TextStyle(
                      color: donation.isExpired ? Colors.red : Colors.grey[600],
                      fontWeight: donation.isExpired ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Acceptor Info
              if (donation.acceptorName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('Reserved by: ${donation.acceptorName!}', style: const TextStyle(color: Colors.green)),
                    ],
                  ),
                ),

              // SCHEDULE INFORMATION - Added here
              if (donation.status == 'Reserved' || donation.status == 'Scheduled') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Schedule:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (donation.scheduledDate != null)
                        Text("Date: ${donation.scheduledDate!.toLocal().toString().split(' ')[0]}"),
                      if (donation.scheduledTime != null)
                        Text("Time: ${donation.scheduledTime!}"),
                      if (donation.deliveryMethod != null)
                        Text("Method: ${donation.deliveryMethod == 'pickup' ? 'Pickup' : 'Delivery'}"),
                    ],
                  ),
                ),
              ],

              // Feedback & Rating
              if (donation.status == 'Completed' && donation.feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(donation.feedback!),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Rating: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Icon(Icons.star, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(donation.rating != null ? donation.rating!.toStringAsFixed(1) : '-'),
                        ],
                      ),
                    ],
                  ),
                ),

              // ACTION BUTTONS - Added here
              const SizedBox(height: 12),

              // Action button for Reserved status
              if (donation.status == 'Reserved')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _reviewAndSchedule(donation),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Review & Accept Schedule'),
                  ),
                ),

              // Action button for Scheduled status
              if (donation.status == 'Scheduled' &&
                  donation.scheduledDate != null &&
                  donation.scheduledDate!.isBefore(DateTime.now().add(const Duration(days: 1))))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _markAsDelivered(donation),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Mark as Delivered'),
                  ),
                ),

              // ============================================
              // SCHEDULE CHANGE INTEGRATION IN CARD
              // ============================================
              if (donation.status == 'Scheduled') ...[
                const SizedBox(height: 12),

                // Check if there's a pending change request FROM acceptor
                FutureBuilder<ScheduleChangeRequest?>(
                  future: _scheduleChangeService.getScheduleChangeRequest(donation.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final changeRequest = snapshot.data;

                    // If acceptor requested a change, show alert
                    if (changeRequest != null &&
                        changeRequest.status == 'Pending' &&
                        changeRequest.requestedBy == 'acceptor') {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_send, color: Colors.amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Schedule Change Requested',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  Text(
                                    'Acceptor wants to change the schedule',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _respondToScheduleChange(donation),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Review'),
                            ),
                          ],
                        ),
                      );
                    }

                    // If donor (you) requested a change, show pending status
                    if (changeRequest != null &&
                        changeRequest.status == 'Pending' &&
                        changeRequest.requestedBy == 'donor') {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pending, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Waiting for acceptor to respond to your schedule change request',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // No pending request - show option to request change
                    return ElevatedButton.icon(
                      onPressed: () => _requestScheduleChange(donation),
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Request Schedule Change'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Donations"),
        backgroundColor: Colors.orange,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)
        ),
      ),
      body: Column(
        children: [
          // FILTER CHIPS
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', _donations.length),
                  _buildFilterChip('Pending', _pendingCount),
                  _buildFilterChip('Reserved', _reservedCount),
                  _buildFilterChip('Completed', _completedCount),
                  _buildFilterChip('Expired', _expiredCount),
                ],
              ),
            ),
          ),
          // STATISTICS
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total', _donations.length, Colors.blue),
                  _buildStatItem('Pending', _pendingCount, Colors.orange),
                  _buildStatItem('Completed', _completedCount, Colors.green),
                ],
              ),
            ),
          ),
          // DONATIONS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredDonations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text(
                    _filter == 'All' ? 'No donations yet' : 'No ${_filter.toLowerCase()} donations',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _filter == 'All' ? 'Add your first donation!' : 'Try a different filter',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadDonations,
              color: Colors.orange,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredDonations.length,
                itemBuilder: (context, index) => _buildDonationCard(_filteredDonations[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDonation())).then((_) => _loadDonations()),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (selected) => setState(() => _filter = label),
        selectedColor: Colors.orange,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}