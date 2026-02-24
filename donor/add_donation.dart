import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/overall_files//select_location.dart';
import 'package:sharebites/donor/donation_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/models/donation_model.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';

class AddDonation extends StatefulWidget {
  const AddDonation({super.key});

  @override
  State<AddDonation> createState() => _AddDonationState();
}

class _AddDonationState extends State<AddDonation> {
  final _formKey = GlobalKey<FormState>();
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();

  String donationType = 'Food';
  String name = '';
  String weight = '';
  DateTime? donationDate;
  DateTime? expiryDate;
  String foodStatus = 'Cooked';
  String description = '';

  LatLng? donationLocation;

  Future<void> _pickDate(bool isDonationDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isDonationDate) {
          donationDate = picked;
          if (expiryDate != null && expiryDate!.isBefore(donationDate!)) {
            expiryDate = null;
          }
        } else {
          expiryDate = picked;
        }
      });
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(
          initialLocation: donationLocation,
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        donationLocation = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (donationDate == null) {
      _showError("Please select donation date");
      return;
    }
    if (expiryDate == null) {
      _showError("Please select expiry date");
      return;
    }
    if (donationLocation == null) {
      _showError("Please pick donation location");
      return;
    }
    if (expiryDate!.isBefore(DateTime.now())) {
      _showError("Expiry date cannot be in the past");
      return;
    }
    if (expiryDate!.isBefore(donationDate!)) {
      _showError("Expiry date cannot be before donation date");
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showError("User not logged in");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final newDonation = Donation(
        id: 'donation_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}',
        title: name,
        type: donationType,
        weight: weight,
        donationDate: donationDate!,
        expiryDate: expiryDate!,
        status: 'Pending',
        foodStatus: donationType == 'Food' ? foodStatus : null,
        location: donationLocation!,
        donorId: currentUser.id,
        priority: '',
        description: description.isNotEmpty ? description : 'No description provided',
      );

      newDonation.priority = newDonation.calculatePriority();

      await _donationService.addDonation(newDonation);

      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Donation Submitted Successfully!",
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Notify all verified acceptors of new donation
      try {
        await SupabaseNotificationHelper.notifyAllAcceptorsOfNewDonation(
          donationTitle: newDonation.title,
          donorName: currentUser.name,
          donationId: newDonation.id,
        );
        print('✅ Acceptors notified of new donation');
      } catch (e) {
        print('⚠️ Failed to notify acceptors: $e');
        // Don't show error to user as donation was successful
      }

      _clearForm();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (context.mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      _showError("Failed to submit donation. Please try again.");
    }
  }

  void _clearForm() {
    setState(() {
      donationType = 'Food';
      name = '';
      weight = '';
      donationDate = null;
      expiryDate = null;
      foodStatus = 'Cooked';
      donationLocation = null;
      description = '';
    });
    _formKey.currentState?.reset();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Donation"),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                  labelText: "Select Donation Type",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'Food', child: Text('Food')),
                  DropdownMenuItem(value: 'Grocery', child: Text('Grocery')),
                ],
                onChanged: (value) => setState(() => donationType = value!),
                validator: (value) => value == null ? 'Please select donation type' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                decoration: InputDecoration(
                  labelText: donationType == 'Food' ? 'Food Name' : 'Item Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.fastfood),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final nameReg = RegExp(r"^[a-zA-Z\s]+$");
                  if (!nameReg.hasMatch(v)) return 'Only alphabets allowed';
                  return null;
                },
                onSaved: (v) => name = v!,
              ),
              const SizedBox(height: 20),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null || value <= 0) return 'Invalid weight';
                  return null;
                },
                onSaved: (v) => weight = v!,
              ),
              const SizedBox(height: 20),

              if (donationType == 'Food')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: foodStatus,
                      decoration: const InputDecoration(
                        labelText: "Food Status",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cooked', child: Text('Cooked')),
                        DropdownMenuItem(value: 'Not Cooked', child: Text('Not Cooked')),
                      ],
                      onChanged: (value) => setState(() => foodStatus = value!),
                      validator: (value) => value == null ? 'Please select food status' : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Donation Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: donationDate == null
                            ? ''
                            : '${donationDate!.toLocal().toString().split(' ')[0]}',
                      ),
                      onTap: () => _pickDate(true),
                      validator: (value) => donationDate == null ? 'Please select donation date' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _pickDate(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_busy),
                      ),
                      controller: TextEditingController(
                        text: expiryDate == null
                            ? ''
                            : '${expiryDate!.toLocal().toString().split(' ')[0]}',
                      ),
                      onTap: () => _pickDate(false),
                      validator: (value) => expiryDate == null ? 'Please select expiry date' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _pickDate(false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                onSaved: (v) => description = v ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final descReg = RegExp(r"^[a-zA-Z0-9\s.,'/\-]+$");
                  if (!descReg.hasMatch(v)) return "Invalid characters in description";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Donation Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _pickLocation,
                        icon: const Icon(Icons.location_on),
                        label: Text(donationLocation == null ? "Pick Location" : "Change Location"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      if (donationLocation != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 200,
                          child: GoogleMap(
                            key: ValueKey(donationLocation),
                            initialCameraPosition: CameraPosition(
                              target: donationLocation!,
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId("donation"),
                                position: donationLocation!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Lat: ${donationLocation!.latitude.toStringAsFixed(5)} | "
                              "Lng: ${donationLocation!.longitude.toStringAsFixed(5)}",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Submit Donation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Cancel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}