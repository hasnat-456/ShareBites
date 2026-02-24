import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/models/donation_model.dart';

class DonorRequestApprovalDialog extends StatefulWidget {
  final Donation donation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const DonorRequestApprovalDialog({
    super.key,
    required this.donation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<DonorRequestApprovalDialog> createState() =>
      _DonorRequestApprovalDialogState();
}

class _DonorRequestApprovalDialogState
    extends State<DonorRequestApprovalDialog> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Review Request"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donation Info
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.food_bank, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Your Donation",
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
                          backgroundColor: Colors.blue.shade100,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(widget.donation.weight),
                          backgroundColor: Colors.green.shade100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Requestor Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          "Requested By",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.donation.acceptorName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.donation.requestedDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Requested on: ${widget.donation.requestedDate!.toLocal().toString().split(' ')[0]}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Schedule Details
            if (widget.donation.scheduledDate != null ||
                widget.donation.scheduledTime != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            "Schedule Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.donation.scheduledDate != null)
                        _buildDetailRow(
                          Icons.calendar_today,
                          "Date",
                          widget.donation.scheduledDate!
                              .toLocal()
                              .toString()
                              .split(' ')[0],
                        ),
                      if (widget.donation.scheduledTime != null)
                        _buildDetailRow(
                          Icons.access_time,
                          "Time",
                          widget.donation.scheduledTime!,
                        ),
                      if (widget.donation.deliveryMethod != null)
                        _buildDetailRow(
                          widget.donation.deliveryMethod == 'pickup'
                              ? Icons.directions_walk
                              : Icons.local_shipping,
                          "Method",
                          widget.donation.deliveryMethod == 'pickup'
                              ? "Acceptor will pickup"
                              : "Delivery requested",
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Pickup Location (if applicable)
            if (widget.donation.pickupLocation != null &&
                widget.donation.deliveryMethod == 'pickup')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            "Pickup Location",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: widget.donation.pickupLocation!,
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId("pickup"),
                              position: widget.donation.pickupLocation!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Delivery Notes
            if (widget.donation.deliveryNotes != null &&
                widget.donation.deliveryNotes!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.note, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            "Additional Notes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.donation.deliveryNotes!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
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
                  const Expanded(
                    child: Text(
                      "By accepting, you confirm the schedule and commit to the pickup/delivery.",
                      style: TextStyle(fontSize: 13),
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
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Reject",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Accept & Schedule",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}