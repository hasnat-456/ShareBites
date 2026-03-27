import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/overall_files/select_location.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:firebase_database/firebase_database.dart';

class RequestDonation extends StatefulWidget {
  const RequestDonation({super.key});

  @override
  State<RequestDonation> createState() => _RequestDonationState();
}

class _RequestDonationState extends State<RequestDonation> {
  final _formKey = GlobalKey<FormState>();
  final DonationService _donationService = DonationService();

  String donationType = 'Food';
  String name = '';
  String quantity = '';
  String description = '';
  DateTime? neededBy;
  LatLng? pickupLocation;

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => neededBy = picked);
  }

  Future<void> _pickLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(initialLocation: pickupLocation),
      ),
    );
    if (location != null) setState(() => pickupLocation = location);
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (neededBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select the needed by date")),
      );
      return;
    }

    if (pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a pickup location")),
      );
      return;
    }

    _formKey.currentState!.save();

    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    final request = DonationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      acceptorId: currentUser.id,
      acceptorName: currentUser.name,
      type: donationType,
      itemName: name,
      quantity: quantity,
      description: description,
      neededBy: neededBy!,
      location: pickupLocation!,
      status: 'Pending',
      donorId: null,
      donationId: null,
      requestDate: DateTime.now(),
    );

    try {
      await _donationService.submitDonationRequest(request);

      try {
        final database = FirebaseDatabase.instance.ref();
        final usersSnapshot = await database.child('users').once();
        if (usersSnapshot.snapshot.exists) {
          final usersMap = usersSnapshot.snapshot.value as Map<dynamic, dynamic>;
          for (var entry in usersMap.entries) {
            final userId = entry.key as String;
            final userData = entry.value as Map<dynamic, dynamic>;
            if (userData['userType'] == 'Donor' &&
                userData['verificationStatus'] == 'Approved') {
              await SupabaseNotificationHelper.notifyDonorOfSpecificRequest(
                donorId: userId,
                acceptorName: currentUser.name,
                itemRequested: name,
                quantity: quantity,
              );
            }
          }
        }
      } catch (e) {
        print('Could not notify donors: $e');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Request Submitted"),
          content: Text(
            "You requested: $name ($donationType)\n"
                "Quantity: $quantity\n"
                "Pickup Location: ${pickupLocation!.latitude.toStringAsFixed(5)}, "
                "${pickupLocation!.longitude.toStringAsFixed(5)}\n"
                "Needed By: ${neededBy!.toLocal().toString().split(' ')[0]}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit request: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Donation"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: donationType,
                decoration: const InputDecoration(
                  labelText: "Type of item",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Food', child: Text('Food')),
                  DropdownMenuItem(value: 'Grocery', child: Text('Grocery')),
                ],
                onChanged: (v) => setState(() => donationType = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration: InputDecoration(
                  labelText: donationType == 'Food' ? 'Food Name' : 'Item Name',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v.trim())) {
                    return 'Only alphabets are allowed';
                  }
                  return null;
                },
                onSaved: (v) => name = v!.trim(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity Needed',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(v.trim())) {
                    return 'Only letters and numbers are allowed';
                  }
                  return null;
                },
                onSaved: (v) => quantity = v!.trim(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (v) => description = v ?? '',
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      neededBy == null
                          ? 'Needed by?'
                          : 'Needed by: ${neededBy!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  ElevatedButton(onPressed: _pickDate, child: const Text("Select Date")),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.location_on),
                label: Text(
                  pickupLocation == null ? "Select Pickup Location" : "Change Location",
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              if (pickupLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "📍 Pickup Location Selected\nLat: ${pickupLocation!.latitude.toStringAsFixed(5)}, "
                        "Lng: ${pickupLocation!.longitude.toStringAsFixed(5)}",
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Submit Request", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}