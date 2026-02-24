import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/overall_files/select_location.dart';
import 'package:sharebites/models/donation_item.dart';

class DonationRequestDialog extends StatefulWidget {
  final DonationItem donation;

  const DonationRequestDialog({super.key, required this.donation});

  @override
  State<DonationRequestDialog> createState() => _DonationRequestDialogState();
}

class _DonationRequestDialogState extends State<DonationRequestDialog> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String _deliveryMethod = 'pickup';
  LatLng? _pickupLocation; // For "I'll pickup" - this is where acceptor will pick up from
  LatLng? _deliveryLocation; // For "Request Delivery" - this is where acceptor wants delivery
  final TextEditingController _deliveryNotesController = TextEditingController();

  final List<String> _timeSlots = [
    '08:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '12:00 PM - 02:00 PM',
    '02:00 PM - 04:00 PM',
    '04:00 PM - 06:00 PM',
    '06:00 PM - 08:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    // Set initial date to tomorrow (or today if tomorrow is after expiry)
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final expiry = widget.donation.expiryDate;

    if (tomorrow.isBefore(expiry)) {
      _selectedDate = tomorrow;
    } else if (now.isBefore(expiry)) {
      _selectedDate = now;
    }
    // If both now and tomorrow are after expiry, leave it null
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime expiry = widget.donation.expiryDate;

    // Calculate last selectable date
    DateTime lastDate = expiry.subtract(const Duration(days: 1));

    // Ensure lastDate is not before today
    if (lastDate.isBefore(now)) {
      lastDate = now;
    }

    print('Date picker parameters:');
    print('Now: $now');
    print('Expiry: $expiry');
    print('Last selectable date: $lastDate');

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime day) {
        // Only allow dates before expiry
        return day.isBefore(expiry);
      },
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.green,
            colorScheme: const ColorScheme.light(primary: Colors.green),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      print('Selected date: $_selectedDate');
    } else {
      print('Date picker was cancelled');
    }
  }

  Future<void> _pickDeliveryLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(initialLocation: _deliveryLocation),
      ),
    );

    if (location != null) {
      setState(() => _deliveryLocation = location);
    }
  }

  void _submitRequest() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select preferred date")),
      );
      return;
    }

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select time slot")),
      );
      return;
    }

    if (_deliveryMethod == 'pickup' && _pickupLocation == null) {
      // Auto-set to donor's location if not selected
      _pickupLocation = widget.donation.location;
    }

    if (_deliveryMethod == 'delivery' && _deliveryLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select delivery location")),
      );
      return;
    }

    // Return the scheduling details
    final result = {
      'scheduledDate': _selectedDate,
      'scheduledTime': _selectedTimeSlot,
      'deliveryMethod': _deliveryMethod,
      'pickupLocation': _deliveryMethod == 'pickup' ? _pickupLocation : _deliveryLocation,
      'deliveryNotes': _deliveryNotesController.text.trim(),
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime expiry = widget.donation.expiryDate;
    final bool isExpired = expiry.isBefore(now);
    final bool expiresToday = expiry.day == now.day &&
        expiry.month == now.month &&
        expiry.year == now.year;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule Pickup/Delivery"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Donation Info Card
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.food_bank, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            "Donation Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                            backgroundColor: Colors.orange.shade100,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(widget.donation.weight),
                            backgroundColor: Colors.blue.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Donor: ${widget.donation.donorName}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        "Expires: ${widget.donation.expiryDate.toLocal().toString().split(' ')[0]}",
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Warning if expired or expiring soon
                      if (isExpired)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                "This donation has expired!",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (expiresToday)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                "Expires today!",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Date Selection
              const Text(
                "Preferred Date",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Check if donation is already expired
              if (isExpired)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Cannot schedule pickup - donation has expired on ${widget.donation.expiryDate.toLocal().toString().split(' ')[0]}",
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (expiresToday && now.hour >= 20) // If it's late evening and expires today
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Limited time available - expires today",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  child: InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _selectedDate == null ? Colors.grey : Colors.green,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDate == null
                                      ? "Select date"
                                      : _selectedDate!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                                if (_selectedDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "Must be before ${widget.donation.expiryDate.toLocal().toString().split(' ')[0]}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Time Slot Selection
              const Text(
                "Preferred Time",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (!isExpired && _selectedDate != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map((slot) {
                    final isSelected = _selectedTimeSlot == slot;
                    return ChoiceChip(
                      label: Text(slot),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTimeSlot = selected ? slot : null;
                        });
                      },
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    );
                  }).toList(),
                )
              else if (!isExpired && _selectedDate == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Please select a date first",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Time selection not available",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 24),

              // Only show rest of the form if donation is not expired and date is selected
              if (!isExpired && _selectedDate != null) ...[
                // Delivery Method
                const Text(
                  "Delivery Method",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: _deliveryMethod == 'pickup'
                            ? Colors.green.shade50
                            : null,
                        child: InkWell(
                          onTap: () => setState(() => _deliveryMethod = 'pickup'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_walk,
                                  color: _deliveryMethod == 'pickup'
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "I'll Pickup",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "You collect",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: _deliveryMethod == 'delivery'
                            ? Colors.green.shade50
                            : null,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _deliveryMethod = 'delivery'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  color: _deliveryMethod == 'delivery'
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Request Delivery",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Donor delivers",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Pickup Location (if "I'll pickup" selected) - Shows donor location
                if (_deliveryMethod == 'pickup') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                "Pickup Location (Donor's Address)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Show donor's location on map
                          SizedBox(
                            height: 200,
                            child: GoogleMap(
                              key: ValueKey(widget.donation.location),
                              initialCameraPosition: CameraPosition(
                                target: widget.donation.location,
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId("donor_location"),
                                  position: widget.donation.location,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                  infoWindow: const InfoWindow(title: "Pickup from here"),
                                ),
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "📍 You will pick up from donor's location",
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Delivery Location (if "Request Delivery" selected) - Acceptor selects their location
                if (_deliveryMethod == 'delivery') ...[
                  const Text(
                    "Delivery Location",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select where you want the donation delivered:",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickDeliveryLocation,
                            icon: const Icon(Icons.location_on),
                            label: Text(
                              _deliveryLocation == null
                                  ? "Select Delivery Location on Map"
                                  : "Change Delivery Location",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          if (_deliveryLocation != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 200,
                              child: GoogleMap(
                                key: ValueKey(_deliveryLocation),
                                initialCameraPosition: CameraPosition(
                                  target: _deliveryLocation!,
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId("delivery_location"),
                                    position: _deliveryLocation!,
                                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                    infoWindow: const InfoWindow(title: "Deliver here"),
                                  ),
                                },
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "📍 ${_deliveryLocation!.latitude.toStringAsFixed(5)}, ${_deliveryLocation!.longitude.toStringAsFixed(5)}",
                                style: TextStyle(color: Colors.green.shade800, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Delivery/Pickup Notes (always shown if not expired)
                const Text(
                  "Additional Notes (Optional)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deliveryNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _deliveryMethod == 'pickup'
                        ? 'Any special instructions for pickup...\nExample: I will come at 2 PM, please keep it ready'
                        : 'Your delivery address and any special instructions...\nExample: House #123, Street 5, near ABC Market',
                  ),
                ),

                const SizedBox(height: 24),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deliveryMethod == 'pickup'
                              ? "The donor will review your request and can accept or suggest a different time."
                              : "The donor will review your delivery request and decide whether they can deliver to your location.",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Submit Request",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isExpired) ...[
                // Show disabled button if expired
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Cannot Request - Donation Expired",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Show button that requires date selection
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Please select a date first",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}