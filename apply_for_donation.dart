import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/acceptor/request_donation.dart';
import 'package:sharebites/overall_files/select_location.dart';
import 'package:sharebites/models/donation_item.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/acceptor/donation_request_dialog.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

// Page for requesting a donation from available list
class DonationRequestPage extends StatefulWidget {
  final DonationItem donation;

  const DonationRequestPage({super.key, required this.donation});

  @override
  State<DonationRequestPage> createState() => _DonationRequestPageState();
}

class _DonationRequestPageState extends State<DonationRequestPage> {
  LatLng? pickupLocation;
  String _deliveryNotes = '';

  Future<void> _pickLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(initialLocation: pickupLocation),
      ),
    );
    if (location != null) setState(() => pickupLocation = location);
  }

  void _submitRequest() {
    if (pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select pickup location")),
      );
      return;
    }

    // Return the pickup location and delivery notes
    final result = {
      'location': pickupLocation,
      'notes': _deliveryNotes,
    };
    Navigator.pop(context, result);
  }

  void _cancelRequest() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Donation"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelRequest,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donation Details
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Donation Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.donation.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(widget.donation.type),
                          backgroundColor: widget.donation.type == 'Food'
                              ? Colors.orange[100]
                              : Colors.blue[100],
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(widget.donation.weight),
                          backgroundColor: Colors.grey[100],
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(widget.donation.priority),
                          backgroundColor: widget.donation.priority == 'High'
                              ? Colors.red[100]
                              : widget.donation.priority == 'Medium'
                              ? Colors.orange[100]
                              : Colors.green[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Donor: ${widget.donation.donorName}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "Expiry: ${widget.donation.expiryDate.toLocal().toString().split(' ')[0]}",
                      style: TextStyle(
                        color: widget.donation.expiryDate.isBefore(DateTime.now().add(const Duration(days: 2)))
                            ? Colors.red
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.donation.distance.isNotEmpty && widget.donation.distance != 'N/A')
                      Text(
                        "Distance: ${widget.donation.distance}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),

            // Delivery Notes
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Delivery Information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Delivery Notes
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Delivery Notes (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Any special instructions for pickup...',
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {
                          _deliveryNotes = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Pickup Location
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pickup Location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(
                        pickupLocation == null
                            ? "Select Pickup Location"
                            : "Change Location",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    if (pickupLocation != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "📍 Selected Location:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Latitude: ${pickupLocation!.latitude.toStringAsFixed(5)}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              "Longitude: ${pickupLocation!.longitude.toStringAsFixed(5)}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Buttons Section
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cancelRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Submit Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickupLocation == null ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pickupLocation == null ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Submit Request",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            // Information Note
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Once submitted, the donor will be notified and can approve your request.",
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ApplyForDonation Page
class ApplyForDonation extends StatefulWidget {
  const ApplyForDonation({super.key});

  @override
  State<ApplyForDonation> createState() => _ApplyForDonationState();
}

class _ApplyForDonationState extends State<ApplyForDonation> {
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();

  List<DonationItem> _availableDonations = [];
  bool _loading = true;

  // Sorting and Filtering Variables
  String _sortBy = 'priority'; // 'priority', 'type', 'expiry'
  String _filterType = 'All'; // 'All', 'Food', 'Grocery'

  @override
  void initState() {
    super.initState();
    _loadAvailableDonations();
  }

  Future<void> _loadAvailableDonations() async {
    setState(() => _loading = true);

    try {
      final currentUser = _authService.currentUser;
      LatLng? userLocation;

      // In a real app, get user's current location
      if (currentUser?.location != null) {
        userLocation = currentUser!.location;
      }

      final donations = await _donationService.getAvailableDonations(userLocation);

      // Convert to DonationItem for display
      _availableDonations = donations.map((donation) {
        return DonationItem(
          id: donation.id,
          title: donation.title,
          type: donation.type,
          weight: donation.weight,
          description: donation.description,
          donationDate: donation.donationDate,
          expiryDate: donation.expiryDate,
          priority: donation.priority,
          donorName: 'Donor',
          donorId: donation.donorId,  // ADDED: Pass donorId from donation
          distance: donation.distance != null ? '${donation.distance!.toStringAsFixed(1)} km' : 'N/A',
          location: donation.location,
          foodStatus: donation.foodStatus,
        );
      }).toList();

    } catch (e) {
      // If no donations from database, show empty list
      _availableDonations = [];

    } finally {
      setState(() => _loading = false);
    }
  }

  // Method for sorting donations
  List<DonationItem> _getSortedDonations() {
    List<DonationItem> sortedList = List.from(_availableDonations);

    // Apply type filter
    if (_filterType != 'All') {
      sortedList = sortedList.where((d) => d.type == _filterType).toList();
    }

    // Apply sorting
    if (_sortBy == 'type') {
      sortedList.sort((a, b) => a.type.compareTo(b.type));
    } else if (_sortBy == 'expiry') {
      sortedList.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else if (_sortBy == 'priority') {
      final priorityOrder = {'High': 1, 'Medium': 2, 'Low': 3};
      sortedList.sort((a, b) {
        return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
      });
    }

    return sortedList;
  }

  void _requestDonation(BuildContext context, DonationItem donation) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text('Submitting request...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DonationRequestDialog(donation: donation),
        ),
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (result != null && result is Map) {
        final scheduledDate = result['scheduledDate'] as DateTime?;
        final scheduledTime = result['scheduledTime'] as String?;
        final deliveryMethod = result['deliveryMethod'] as String;
        final pickupLocation = result['pickupLocation'] as LatLng?;
        final deliveryNotes = result['deliveryNotes'] as String;

        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("User not logged in. Please login again."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        print('=== SUBMITTING DONATION REQUEST FROM UI ===');
        print('Donation: ${donation.title}');
        print('User: ${currentUser.name}');

        // Show loading dialog again during submission
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.green),
                      SizedBox(height: 16),
                      Text('Processing your request...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Request donation with scheduling details
        final success = await _donationService.requestDonationWithSchedule(
          donation.id,
          currentUser.id,
          currentUser.name,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          deliveryMethod: deliveryMethod,
          pickupLocation: pickupLocation,
          deliveryNotes: deliveryNotes,
        );

        print('Request result: ${success ? "SUCCESS" : "FAILED"}');

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "✅ Request submitted successfully!\n"
                      "${donation.title}\n"
                      "Scheduled: ${scheduledDate?.toLocal().toString().split(' ')[0]} at $scheduledTime",
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );

            // Send notifications
            try {
              // Notify donor of request
              await SupabaseNotificationHelper.notifyDonationRequested(
                donorId: donation.donorId,
                acceptorName: currentUser.name,
                donationTitle: donation.title,
              );

              // Confirm to acceptor
              await SupabaseNotificationHelper.notifyAcceptorRequestConfirmation(
                acceptorId: currentUser.id,
                donationTitle: donation.title,
              );

              print('✅ Notifications sent for donation request');
            } catch (e) {
              print('⚠️ Failed to send notifications: $e');
              // Don't show error to user as request was successful
            }

            // Reload donations to update the list
            _loadAvailableDonations();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "⚠️ Request may not have been submitted.\n"
                      "Please check 'Received Donations' to verify.",
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );

            // Still reload to check if it was saved
            _loadAvailableDonations();
          }
        }
      } else {
        // User cancelled the request dialog
        print('User cancelled donation request');
      }
    } catch (e) {
      print('❌ ERROR in _requestDonation: $e');

      // Close any open dialogs
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}\nPlease try again."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedDonations = _getSortedDonations();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Donations"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableDonations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
        children: [
          // Sorting and Filtering Controls Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sort & Filter",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sort By Row
                  Row(
                    children: [
                      const Icon(Icons.sort, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        "Sort by:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isExpanded: true,
                          underline: Container(height: 0),
                          items: const [
                            DropdownMenuItem(
                              value: 'priority',
                              child: Text('Priority (High to Low)'),
                            ),
                            DropdownMenuItem(
                              value: 'type',
                              child: Text('Food Type (Food/Grocery)'),
                            ),
                            DropdownMenuItem(
                              value: 'expiry',
                              child: Text('Expiry Date (Soonest)'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _sortBy = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter by Type Row
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        "Filter by:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _filterType,
                          isExpanded: true,
                          underline: Container(height: 0),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('All Types'),
                            ),
                            DropdownMenuItem(
                              value: 'Food',
                              child: Text('Food Only'),
                            ),
                            DropdownMenuItem(
                              value: 'Grocery',
                              child: Text('Grocery Only'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // Active Filters Display
                  if (_filterType != 'All')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Chip(
                            label: Text(_filterType),
                            backgroundColor: _filterType == 'Food'
                                ? Colors.orange[100]
                                : Colors.blue[100],
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _filterType = 'All';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Request Specific Donation Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RequestDonation(),
                    ),
                  ).then((_) => _loadAvailableDonations());
                },
                icon: const Icon(Icons.add_circle_outline),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                label: const Text(
                  "Request Specific Donation",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Donations Count and Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${sortedDonations.length} donations available",
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_sortBy != 'priority')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy == 'type' ? 'Sorted by Type' : 'Sorted by Expiry',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Available Donations List
          Expanded(
            child: sortedDonations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No donations found",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _filterType != 'All'
                        ? "Try changing your filter to 'All Types'"
                        : "Check back later or request specific donation",
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_filterType != 'All')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterType = 'All';
                        });
                      },
                      child: const Text("Clear Filter"),
                    ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadAvailableDonations,
              color: Colors.green,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedDonations.length,
                itemBuilder: (context, index) {
                  final donation = sortedDonations[index];
                  final isExpiringSoon = donation.expiryDate.isBefore(
                    DateTime.now().add(const Duration(days: 2)),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      donation.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Type and Priority Chips
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: donation.type == 'Food'
                                                ? Colors.orange[100]
                                                : Colors.blue[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            donation.type,
                                            style: TextStyle(
                                              color: donation.type == 'Food'
                                                  ? Colors.orange[800]
                                                  : Colors.blue[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: donation.priority == 'High'
                                                ? Colors.red[100]
                                                : donation.priority == 'Medium'
                                                ? Colors.orange[100]
                                                : Colors.green[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            donation.priority,
                                            style: TextStyle(
                                              color: donation.priority == 'High'
                                                  ? Colors.red[800]
                                                  : donation.priority == 'Medium'
                                                  ? Colors.orange[800]
                                                  : Colors.green[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Request Button
                              ElevatedButton(
                                onPressed: () => _requestDonation(context, donation),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text("Request"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Details
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Quantity: ${donation.weight}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: isExpiringSoon ? Colors.red : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Expires: ${donation.expiryDate.toLocal().toString().split(' ')[0]}",
                                    style: TextStyle(
                                      color: isExpiringSoon ? Colors.red : Colors.grey,
                                      fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              if (donation.distance.isNotEmpty && donation.distance != 'N/A')
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Distance: ${donation.distance}",
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              if (donation.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    donation.description,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}