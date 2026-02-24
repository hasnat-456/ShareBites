import 'package:flutter/material.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/models/received_donation_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

class DonorRequests extends StatefulWidget {
  const DonorRequests({super.key});

  @override
  State<DonorRequests> createState() => _DonorRequestsState();
}

class _DonorRequestsState extends State<DonorRequests> {
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<DonationRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.userType == 'Donor') {
        final requests = await _donationService.getDonationRequests(currentUser.location);

        // DEBUG: Print all requests
        print('=== DEBUG: All requests from service ===');
        for (var request in requests) {
          print('Request: ${request.itemName}, Status: ${request.status}, ID: ${request.id}');
        }

        setState(() {
          // Filter by status 'Pending'
          _requests = requests.where((r) => r.status == 'Pending').toList();

          // DEBUG: Print filtered requests
          print('=== DEBUG: Filtered pending requests ===');
          for (var request in _requests) {
            print('Pending Request: ${request.itemName}');
          }
          print('Total pending: ${_requests.length}');

          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error loading requests: $e');
      setState(() => _loading = false);
    }
  }

  void _fulfillRequest(DonationRequest request) {
    final quantityController = TextEditingController();
    final _dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fulfill Request"),
        content: SingleChildScrollView(
          child: Form(
            key: _dialogFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Request Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                _requestDetailRow("Item:", request.itemName),
                _requestDetailRow("Type:", request.type),
                _requestDetailRow("Quantity Needed:", request.quantity),
                _requestDetailRow("Needed By:", request.neededBy.toLocal().toString().split(' ')[0]),
                if (request.description.isNotEmpty)
                  _requestDetailRow("Description:", request.description),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "Enter quantity you can donate:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Donation Quantity',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 5, 10',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final value = double.tryParse(v);
                    if (value == null || value <= 0) return 'Invalid quantity';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_dialogFormKey.currentState!.validate()) {
                final qty = quantityController.text.trim();
                Navigator.pop(context);
                _markAsFulfilled(request, qty);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Donate Now'),
          ),
        ],
      ),
    );
  }

  Widget _requestDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsFulfilled(DonationRequest request, String quantity) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _showErrorMessage('Error', 'User not logged in');
        return;
      }

      print('=== FULFILLING REQUEST ===');
      print('Request ID: ${request.id}');
      print('Donor ID: ${currentUser.id}');

      // Create donation ID
      final donationId = 'donation_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}';

      // 1. First, update the request status in database to 'Fulfilled'
      print('Updating request status...');
      await _donationService.updateRequestStatus(
        request.id,
        'Fulfilled',
        donationId: donationId,
        donorId: currentUser.id,
      );

      // 2. Create donation
      print('Creating donation...');
      final donation = Donation(
        id: donationId,
        title: request.itemName,
        type: request.type,
        weight: quantity,
        donationDate: DateTime.now(),
        expiryDate: request.neededBy.add(const Duration(days: 7)),
        status: 'Reserved',
        location: request.location,
        donorId: currentUser.id,
        acceptorId: request.acceptorId,
        acceptorName: request.acceptorName,
        description: "Fulfilled request: ${request.description}",
        requestedDate: DateTime.now(),
      );

      donation.priority = donation.calculatePriority();

      // 3. Add donation to service
      print('Adding donation to database...');
      await _donationService.addDonation(donation);

      // 4. Create received donation
      print('Creating received donation...');
      final receivedDonation = ReceivedDonation(
        id: donation.id,
        title: donation.title,
        type: donation.type,
        weight: donation.weight,
        receivedDate: DateTime.now(),
        donorName: currentUser.name,
        rating: 0.0,
        feedback: null,
        acceptorId: request.acceptorId,
        status: 'Pending',
      );

      // 5. Add to received donations database
      await _databaseRef.child('received_donations').child(donation.id).set(receivedDonation.toMap());

      print('=== REQUEST FULFILLMENT COMPLETE ===');

      // 6. Send notifications
      try {
        // Notify acceptor that request was approved
        await SupabaseNotificationHelper.notifyRequestApproved(
          acceptorId: request.acceptorId,
          donationTitle: request.itemName,
          pickupDate: request.neededBy.toLocal().toString().split(' ')[0],
        );

        // Confirm to donor
        await SupabaseNotificationHelper.notifyDonorApprovedRequest(
          donorId: currentUser.id,
          acceptorName: request.acceptorName,
          donationTitle: request.itemName,
        );

        print('✅ Notifications sent for request fulfillment');
      } catch (e) {
        print('⚠️ Failed to send notifications: $e');
        // Don't fail the whole operation due to notification failure
      }

      // 7. Show success message
      _showSuccessMessage("Request fulfilled successfully!");

      // 8. Reload requests (the fulfilled one will no longer appear)
      await _loadRequests();

    } catch (e) {
      print("Error fulfilling request: $e");
      _showErrorMessage('Failed to fulfill request', e.toString());
    }
  }

  Widget _buildRequestCard(DonationRequest request) {
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
                    request.itemName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.type,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "By: ${request.acceptorName}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.scale, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  request.quantity,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: request.isUrgent ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  "Needed by: ${request.neededBy.toLocal().toString().split(' ')[0]}",
                  style: TextStyle(
                    color: request.isUrgent ? Colors.red : Colors.grey,
                    fontWeight: request.isUrgent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (request.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  request.description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _fulfillRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text("Fulfill This Request"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donation Requests"),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.request_page, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Donation Requests",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      Text(
                        "${_requests.length} ${_requests.length == 1 ? 'request' : 'requests'} waiting",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadRequests,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          Expanded(
            child: _requests.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_page, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    "No donation requests",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Check back later for donation requests",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadRequests,
              color: Colors.orange,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  return _buildRequestCard(_requests[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}