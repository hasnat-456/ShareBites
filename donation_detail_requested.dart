import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sharebites/models/donation_item.dart';

class DonationDetailRequest extends StatelessWidget {
  final DonationItem donation;
  final VoidCallback onCancel;

  const DonationDetailRequest({
    super.key,
    required this.donation,
    required this.onCancel,
  });

  void _openMapsApp(LatLng location) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint("Could not launch maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancel button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onCancel,
            ),
          ),
          const SizedBox(height: 10),

          // Title & Priority
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  donation.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: donation.priority == 'High'
                      ? Colors.red[100]
                      : donation.priority == 'Medium'
                      ? Colors.orange[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  donation.priority,
                  style: TextStyle(
                    color: donation.priority == 'High'
                        ? Colors.red[900]
                        : donation.priority == 'Medium'
                        ? Colors.orange[900]
                        : Colors.green[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Donation Info
          InfoCard(
            title: "Donation Information",
            children: [
              InfoRow(label: "Type", value: donation.type),
              InfoRow(label: "Weight/Quantity", value: donation.weight),
              if (donation.type == 'Food' && donation.foodStatus != null)
                InfoRow(label: "Food Status", value: donation.foodStatus!),
              InfoRow(
                label: "Donation Date",
                value: donation.donationDate.toLocal().toString().split(' ')[0],
              ),
              InfoRow(
                label: "Expiry Date",
                value: donation.expiryDate.toLocal().toString().split(' ')[0],
                isImportant: donation.expiryDate.difference(DateTime.now()).inDays < 2,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Donor Info
          InfoCard(
            title: "Donor Information",
            children: [
              InfoRow(label: "Donor Name", value: donation.donorName),
              InfoRow(
                  label: "Distance",
                  value: donation.distance.isNotEmpty ? donation.distance : "N/A"),
            ],
          ),

          const SizedBox(height: 20),

          // Description
          InfoCard(
            title: "Description",
            children: [
              Text(
                donation.description.isNotEmpty ? donation.description : "No description provided",
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Location
          InfoCard(
            title: "Location",
            children: [
              GestureDetector(
                onTap: () => _openMapsApp(donation.location),
                child: SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: donation.location,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(donation.id),
                          position: donation.location,
                          infoWindow: InfoWindow(title: donation.title),
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tap map to open in Google Maps",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== InfoCard & InfoRow (same as donation_detail) =====
class InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const InfoCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isImportant;

  const InfoRow({super.key, required this.label, required this.value, this.isImportant = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isImportant ? Colors.red : null, fontWeight: isImportant ? FontWeight.bold : null),
            ),
          ),
        ],
      ),
    );
  }
}