import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/acceptor/feedback_page.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/received_donation_model.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/schedule/schedule_change_service.dart';
import 'package:sharebites/models/schedule_change_model.dart';
import 'package:sharebites/schedule/schedule_change_request_dialog.dart';
import 'package:sharebites/schedule/schedule_change_response_dialog.dart';

List<RequestDonationData> requestedDonations = [];

class ReceivedDonations extends StatefulWidget {
  const ReceivedDonations({super.key});

  @override
  State<ReceivedDonations> createState() => _ReceivedDonationsState();
}

class _ReceivedDonationsState extends State<ReceivedDonations> {
  List<ReceivedDonation> receivedDonations = [];
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final ScheduleChangeService _scheduleChangeService = ScheduleChangeService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceivedDonations();
  }

  Future<void> _loadReceivedDonations() async {
    setState(() => _isLoading = true);

    final currentUser = _authService.currentUser;
    if (currentUser != null && currentUser.userType == 'Acceptor') {
      try {
        final receivedRef = _databaseRef.child('received_donations');
        final receivedSnapshot = await receivedRef
            .orderByChild('acceptorId')
            .equalTo(currentUser.id)
            .once();

        final List<ReceivedDonation> allDonations = [];

        if (receivedSnapshot.snapshot.exists) {
          final receivedMap = Map<String, dynamic>.from(receivedSnapshot.snapshot.value as Map);
          receivedMap.forEach((key, value) {
            final donationData = Map<String, dynamic>.from(value as Map);
            allDonations.add(ReceivedDonation.fromMap(donationData));
          });
        }

        final reservedDonations = await _donationService.getDonationsByAcceptor(currentUser.id);

        for (var donation in reservedDonations) {
          if ((donation.status == 'Reserved' || donation.status == 'Pending') &&
              donation.acceptorId == currentUser.id) {

            if (!allDonations.any((rd) => rd.id == donation.id)) {
              final donorName = await _getDonorName(donation.donorId);

              final receivedDonation = ReceivedDonation(
                id: donation.id,
                title: donation.title,
                type: donation.type,
                weight: donation.weight,
                receivedDate: donation.requestedDate ?? DateTime.now(),
                donorName: donorName,
                rating: 0.0,
                feedback: null,
                acceptorId: currentUser.id,
                status: donation.status == 'Completed' ? 'Accepted' : 'Pending',
              );

              allDonations.add(receivedDonation);

              final existingSnapshot = await receivedRef.child(donation.id).once();
              if (!existingSnapshot.snapshot.exists) {
                await receivedRef.child(donation.id).set(receivedDonation.toMap());
              }
            }
          }
        }

        final requests = await _donationService.getDonationRequests(currentUser.location);
        final acceptorRequests = requests.where((r) => r.acceptorId == currentUser.id).toList();

        final uniqueDonations = <String, ReceivedDonation>{};
        for (var donation in allDonations) {
          uniqueDonations[donation.id] = donation;
        }

        final sortedDonations = uniqueDonations.values.toList()
          ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

        setState(() {
          receivedDonations = sortedDonations;
          requestedDonations = acceptorRequests.map((r) => RequestDonationData(
            title: r.itemName,
            type: r.type,
            quantity: int.tryParse(r.quantity.toString()) ?? 0,
          )).toList();
          _isLoading = false;
        });

      } catch (e, stackTrace) {
        print("Error loading donations: $e");
        print('Stack trace: $stackTrace');
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error loading donations: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReceipt(ReceivedDonation donation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Receipt"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Confirm that you have received this donation?"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(donation.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Donor: ${donation.donorName}"),
                  Text("Type: ${donation.type}"),
                  Text("Quantity: ${donation.weight}"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirm Receipt"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) return;

        final success = await _donationService.confirmReceipt(donation.id, currentUser.id);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Receipt confirmed! You can now add feedback."),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadReceivedDonations();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to confirm receipt: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getDonorName(String donorId) async {
    try {
      final userRef = _databaseRef.child('users').child(donorId);
      final userSnapshot = await userRef.once();

      if (userSnapshot.snapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
        return userData['name'] ?? 'Unknown Donor';
      }
      return 'Unknown Donor';
    } catch (e) {
      print('Error getting donor name: $e');
      return 'Unknown Donor';
    }
  }

  Future<void> _acceptDonation(ReceivedDonation donation) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Acceptance"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Are you sure you want to accept this donation?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(donation.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Donor: ${donation.donorName}'),
                  Text('Type: ${donation.type}'),
                  Text('Quantity: ${donation.weight}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Accept"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final updatedDonation = donation.copyWith(
        acceptorId: currentUser.id,
        status: 'Accepted',
      );

      await _databaseRef
          .child('received_donations')
          .child(donation.id)
          .update(updatedDonation.toMap());

      await _donationService.completeDonation(donation.id);

      final donationSnapshot = await _databaseRef
          .child('donations')
          .child(donation.id)
          .once();

      if (donationSnapshot.snapshot.exists) {
        final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
        donationData['latitude'] = donationData['latitude'] ?? 0.0;
        donationData['longitude'] = donationData['longitude'] ?? 0.0;
        final mainDonation = Donation.fromJson(donationData);

        if (mainDonation.donorId.isNotEmpty) {
          final donorDonations = await _donationService.getDonationsByDonor(mainDonation.donorId);
          final completedCount = donorDonations.where((d) => d.status == 'Completed').length;
          await _authService.updateUserStatistics(
            mainDonation.donorId,
            totalDonations: completedCount,
          );
        }
      }

      setState(() {
        final index = receivedDonations.indexWhere((d) => d.id == donation.id);
        if (index != -1) {
          receivedDonations[index] = updatedDonation;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Donation accepted successfully!"),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e, stackTrace) {
      print("Error accepting donation: $e");
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to accept donation: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openFeedbackPage(ReceivedDonation donation) async {
    if (donation.status != 'Accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Please accept the donation first before giving feedback"),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final updatedDonation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeedbackPage(donation: donation)),
    );

    if (updatedDonation != null && updatedDonation is ReceivedDonation) {
      try {
        await _databaseRef
            .child('received_donations')
            .child(updatedDonation.id)
            .update({
          'feedback': updatedDonation.feedback,
          'rating': updatedDonation.rating,
        });

        await _databaseRef
            .child('donations')
            .child(updatedDonation.id)
            .update({
          'feedback': updatedDonation.feedback,
          'rating': updatedDonation.rating,
        });

        setState(() {
          final index = receivedDonations.indexWhere((d) => d.id == updatedDonation.id);
          if (index != -1) {
            receivedDonations[index] = updatedDonation;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Feedback saved successfully"),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );

      } catch (e, stackTrace) {
        print("Error saving feedback: $e");
        print('Stack trace: $stackTrace');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save feedback: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _requestScheduleChange(ReceivedDonation receivedDonation) async {
    try {
      final donationRef = _databaseRef.child('donations').child(receivedDonation.id);
      final donationSnapshot = await donationRef.once();

      if (donationSnapshot.snapshot.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final donationData = Map<String, dynamic>.from(donationSnapshot.snapshot.value as Map);
      donationData['latitude'] = donationData['latitude'] ?? 0.0;
      donationData['longitude'] = donationData['longitude'] ?? 0.0;
      final donation = Donation.fromJson(donationData);

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ScheduleChangeRequestDialog(
          donation: donation,
          userRole: 'acceptor',
        ),
      );

      if (result != null && result.isNotEmpty) {
        final currentUser = _authService.currentUser;
        if (currentUser == null) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
        );

        try {
          final success = await _scheduleChangeService.createScheduleChangeRequest(
            donationId: receivedDonation.id,
            requestedBy: 'acceptor',
            requesterId: currentUser.id,
            requesterName: currentUser.name,
            newScheduledDate: result['newScheduledDate'],
            newScheduledTime: result['newScheduledTime'],
            newDeliveryMethod: result['newDeliveryMethod'],
            changeReason: result['changeReason'] ?? 'No reason provided',
          );

          Navigator.pop(context);

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Schedule change request sent to donor'),
                backgroundColor: Colors.green,
              ),
            );
            _loadReceivedDonations();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send schedule change request'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send request: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

  void _respondToScheduleChange(ReceivedDonation receivedDonation) async {
    try {
      final changeRequest = await _scheduleChangeService.getScheduleChangeRequest(receivedDonation.id);

      if (changeRequest == null || changeRequest.status != 'Pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending schedule change request found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ScheduleChangeResponseDialog(
          changeRequest: changeRequest,
          currentUserRole: 'acceptor',
        ),
      );

      if (result != null && result.isNotEmpty) {
        final action = result['action'];
        final responseNote = result['responseNote'] ?? '';

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
        );

        try {
          bool success;
          if (action == 'accept') {
            success = await _scheduleChangeService.acceptScheduleChange(changeRequest.id, responseNote);
          } else {
            success = await _scheduleChangeService.rejectScheduleChange(changeRequest.id, responseNote);
          }

          Navigator.pop(context);

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(action == 'accept'
                    ? 'Schedule change accepted! Donation updated.'
                    : 'Schedule change request rejected'),
                backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
              ),
            );
            _loadReceivedDonations();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to process schedule change request'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          Navigator.pop(context);
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
    } catch (e, stackTrace) {
      print('Error in _respondToScheduleChange: $e');
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

  Widget _buildDonationCard(ReceivedDonation donation) {
    final isAccepted = donation.status == 'Accepted';
    final hasFeedback = donation.feedback != null && donation.feedback!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    donation.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: donation.status == 'Accepted'
                        ? Colors.green.shade100
                        : donation.status == 'Scheduled'
                        ? Colors.blue.shade100
                        : donation.status == 'Awaiting Confirmation'
                        ? Colors.orange.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        donation.status == 'Accepted'
                            ? Icons.check_circle
                            : donation.status == 'Scheduled'
                            ? Icons.schedule
                            : donation.status == 'Awaiting Confirmation'
                            ? Icons.local_shipping
                            : Icons.pending,
                        size: 14,
                        color: donation.status == 'Accepted'
                            ? Colors.green.shade800
                            : donation.status == 'Scheduled'
                            ? Colors.blue.shade800
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        donation.status,
                        style: TextStyle(
                          color: donation.status == 'Accepted'
                              ? Colors.green.shade800
                              : donation.status == 'Scheduled'
                              ? Colors.blue.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              "${donation.type} · ${donation.weight}",
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 4),

            Text(
              "Donor: ${donation.donorName}",
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 4),

            Text(
              "Date: ${donation.receivedDate.toLocal().toString().split(' ')[0]}",
              style: TextStyle(color: Colors.grey.shade600),
            ),

            if (donation.rating > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      donation.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (donation.status == 'Pending') ...[
              if (donation.scheduledDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Scheduled Details:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (donation.scheduledDate != null)
                        Text("Date: ${donation.scheduledDate!.toLocal().toString().split(' ')[0]}"),
                      if (donation.scheduledTime != null)
                        Text("Time: ${donation.scheduledTime!}"),
                      if (donation.deliveryMethod != null)
                        Text("Method: ${donation.deliveryMethod == 'pickup' ? 'You will pickup' : 'Delivery requested'}"),
                    ],
                  ),
                ),
              ],

              Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Waiting for donor to confirm schedule",
                    style: TextStyle(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ] else if (donation.status == 'Scheduled') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Schedule Confirmed:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (donation.scheduledDate != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(donation.scheduledDate!.toLocal().toString().split(' ')[0]),
                        ],
                      ),
                    if (donation.scheduledTime != null)
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(donation.scheduledTime!),
                        ],
                      ),
                    if (donation.deliveryMethod != null)
                      Row(
                        children: [
                          Icon(
                            donation.deliveryMethod == 'pickup' ? Icons.directions_walk : Icons.local_shipping,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(donation.deliveryMethod == 'pickup' ? 'You will pickup' : 'Delivery'),
                        ],
                      ),
                  ],
                ),
              ),

              FutureBuilder<ScheduleChangeRequest?>(
                future: _scheduleChangeService.getScheduleChangeRequest(donation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final changeRequest = snapshot.data;

                  if (changeRequest != null &&
                      changeRequest.status == 'Pending' &&
                      changeRequest.requestedBy == 'donor') {
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
                                  'Donor wants to change the schedule',
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Review'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (changeRequest != null &&
                      changeRequest.status == 'Pending' &&
                      changeRequest.requestedBy == 'acceptor') {
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
                              'Waiting for donor to respond to your schedule change request',
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
            ] else if (donation.status == 'Awaiting Confirmation') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Donor marked as delivered",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (donation.markedDeliveredDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "On: ${donation.markedDeliveredDate!.toLocal().toString()}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReceipt(donation),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "Confirm Receipt",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else if (donation.status == 'Accepted') ...[
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Received",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openFeedbackPage(donation),
                          icon: Icon(
                            hasFeedback ? Icons.edit : Icons.rate_review,
                            size: 18,
                          ),
                          label: Text(
                            hasFeedback ? "Edit Feedback" : "Add Feedback",
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasFeedback ? Colors.blue : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (hasFeedback)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.comment, size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text(
                                "Your Feedback:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            donation.feedback!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalReceived = receivedDonations.where((d) => d.status == 'Accepted').length;
    int pendingAcceptance = receivedDonations.where((d) => d.status == 'Pending').length;
    int totalRequested = requestedDonations.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Received Donations"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReceivedDonations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Donation Summary",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(title: "Pending", count: pendingAcceptance, color: Colors.orange),
                    _buildStatCard(title: "Accepted", count: totalReceived, color: Colors.green),
                    _buildStatCard(title: "Requested", count: totalRequested, color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: receivedDonations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    "No donations available",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Donations reserved for you will appear here. Check back after donors have accepted your requests.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadReceivedDonations,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadReceivedDonations,
              color: Colors.green,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: receivedDonations.length,
                itemBuilder: (context, index) {
                  return _buildDonationCard(receivedDonations[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class RequestDonationData {
  final String title;
  final String type;
  final int quantity;

  RequestDonationData({
    required this.title,
    required this.type,
    required this.quantity,
  });
}