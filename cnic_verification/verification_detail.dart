import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sharebites/models/verification_request_model.dart';
import 'package:sharebites/verifier/ngo_service.dart';

class VerificationDetail extends StatefulWidget {
  final VerificationRequest request;
  final String ngoId;

  const VerificationDetail({
    super.key,
    required this.request,
    required this.ngoId,
  });

  @override
  State<VerificationDetail> createState() => _VerificationDetailState();
}

class _VerificationDetailState extends State<VerificationDetail> {
  final NGOService _ngoService = NGOService();
  final _notesController = TextEditingController();
  final _rejectionController = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _notesController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }


  /// Open Google Maps with directions to acceptor's location
  void _openLocationForNavigation() async {
    final location = widget.request.acceptorLocation;
    // Using Google Maps with directions mode
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar("Could not open navigation");
    }
  }

  /// Open location in Google Maps (view only)
  void _openLocationView() async {
    final location = widget.request.acceptorLocation;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar("Could not open maps");
    }
  }

  /// Make a direct phone call
  void _makePhoneCall() async {
    final url = Uri.parse('tel:${widget.request.acceptorPhone}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _logContactAction("Phone Call");
    } else {
      _showErrorSnackBar("Could not make phone call");
    }
  }

  /// Send WhatsApp message
  void _sendWhatsApp() async {
    // Remove leading zero and add country code (Pakistan: +92)
    String phone = widget.request.acceptorPhone;
    if (phone.startsWith('0')) {
      phone = '92${phone.substring(1)}';
    }

    // Pre-filled message for WhatsApp
    final message = Uri.encodeComponent(
        'Hello ${widget.request.acceptorName},\n\n'
            'This is from ${_ngoService.currentNGO?.name ?? "NGO Verification Team"}. '
            'We are contacting you regarding your verification request for ShareBites platform.\n\n'
            'Best regards'
    );

    final url = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      _logContactAction("WhatsApp");
    } else {
      _showErrorSnackBar("Could not open WhatsApp. Make sure WhatsApp is installed.");
    }
  }

  /// Send regular SMS
  void _sendSMS() async {
    // Pre-filled SMS message
    final message = Uri.encodeComponent(
        'Hello ${widget.request.acceptorName}, '
            'This is from ${_ngoService.currentNGO?.name ?? "NGO"} regarding your ShareBites verification. '
            'We will contact you soon.'
    );

    final url = Uri.parse('sms:${widget.request.acceptorPhone}?body=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _logContactAction("SMS");
    } else {
      _showErrorSnackBar("Could not open SMS app");
    }
  }

  /// Send email
  void _sendEmail() async {
    final subject = Uri.encodeComponent('ShareBites Verification - ${widget.request.acceptorName}');
    final body = Uri.encodeComponent(
        'Dear ${widget.request.acceptorName},\n\n'
            'We are contacting you from ${_ngoService.currentNGO?.name ?? "NGO"} regarding your verification request for the ShareBites platform.\n\n'
            'We will be reviewing your application and may need to contact you for additional information or a visit.\n\n'
            'Best regards,\n'
            '${_ngoService.currentNGO?.name ?? "Verification Team"}'
    );

    final url = Uri.parse('mailto:${widget.request.acceptorEmail}?subject=$subject&body=$body');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _logContactAction("Email");
    } else {
      _showErrorSnackBar("Could not open email");
    }
  }

  /// Show contact options dialog
  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_phone, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  "Contact Acceptor",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.request.acceptorName,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Divider(height: 30),

            // Phone Call Option
            _buildContactOption(
              icon: Icons.phone,
              title: "Phone Call",
              subtitle: widget.request.acceptorPhone,
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall();
              },
            ),

            // WhatsApp Option
            _buildContactOption(
              icon: Icons.chat,
              title: "WhatsApp",
              subtitle: "Send message via WhatsApp",
              color: Colors.green.shade700,
              onTap: () {
                Navigator.pop(context);
                _sendWhatsApp();
              },
            ),

            // SMS Option
            _buildContactOption(
              icon: Icons.message,
              title: "SMS",
              subtitle: "Send text message",
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _sendSMS();
              },
            ),

            // Email Option
            _buildContactOption(
              icon: Icons.email,
              title: "Email",
              subtitle: widget.request.acceptorEmail,
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _sendEmail();
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }


  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _VerificationDialog(
        request: widget.request,
        ngoId: widget.ngoId,
        onVerify: (verificationMethod, notes) {
          Navigator.pop(ctx);
          _performVerification(verificationMethod, notes);
        },
      ),
    );
  }

  Future<void> _performVerification(String verificationMethod, String notes) async {
    setState(() => _processing = true);

    try {
      print('=== STARTING VERIFICATION PROCESS ===');

      // Combine verification method and notes
      final fullNotes = 'Verification Method: $verificationMethod\n\nNotes: $notes';

      // Perform verification
      await _ngoService.verifyAcceptor(
        widget.request.id,
        widget.ngoId,
        fullNotes,
      );

      print('✅ Verification completed successfully');
      // Notifications are handled inside ngo_service.verifyAcceptor() — no duplicate call here

      if (!mounted) return;

      setState(() => _processing = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 10),
              Expanded(child: Text("Verified Successfully")),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.request.acceptorName} has been verified!",
                style: const TextStyle(fontSize: 16),
              ),
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
                    Row(
                      children: [
                        Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Verification Method:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verificationMethod,
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "They can now use the platform to receive donations.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return true to indicate verification
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error during verification: $e');

      if (!mounted) return;

      setState(() => _processing = false);

      _showErrorSnackBar('Failed to verify: ${e.toString()}');
    }
  }

  void _rejectVerification() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Verification"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason for rejection:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rejectionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g., Information mismatch, invalid documents, etc.",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionController.text.trim().isEmpty) {
                _showErrorSnackBar("Please provide a rejection reason");
                return;
              }
              Navigator.pop(ctx);
              _performRejection();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _performRejection() async {
    setState(() => _processing = true);

    try {
      await _ngoService.rejectVerification(
        widget.request.id,
        widget.ngoId,
        _rejectionController.text.trim(),
      );

      setState(() => _processing = false);

      // NOTE: notifications are sent inside ngo_service.rejectVerification() — no duplicate here
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 32),
              SizedBox(width: 10),
              Text("Verification Rejected"),
            ],
          ),
          content: const Text("The verification request has been rejected."),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _processing = false);
      _showErrorSnackBar('Error: $e');
    }
  }


  void _logContactAction(String method) {
    print("NGO contacted acceptor via $method");
    // You could save this to Firebase for tracking
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Details'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Acceptor Information Card
                _buildInfoCard(),

                const SizedBox(height: 16),

                // Location Card
                _buildLocationCard(),

                const SizedBox(height: 16),

                // Family & Income Details
                _buildDetailsCard(),

                const SizedBox(height: 16),

                // CNIC Images
                _buildCNICSection(),

                const SizedBox(height: 16),

                // Contact Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showContactOptions,
                    icon: const Icon(Icons.contact_phone),
                    label: const Text('Contact Acceptor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _rejectVerification,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _showVerificationDialog,
                        icon: const Icon(Icons.verified_user),
                        label: const Text('Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Acceptor Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow("Name", widget.request.acceptorName),
            _buildInfoRow("Email", widget.request.acceptorEmail),
            _buildInfoRow("Phone", widget.request.acceptorPhone),
            _buildInfoRow("Address", widget.request.acceptorAddress),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Location",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.request.acceptorLocation,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('acceptor'),
                  position: widget.request.acceptorLocation,
                  infoWindow: InfoWindow(
                    title: widget.request.acceptorName,
                    snippet: widget.request.acceptorAddress,
                  ),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openLocationView,
                    icon: const Icon(Icons.map),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openLocationForNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Family & Income Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow("Family Size", widget.request.familySize?.toString() ?? 'N/A'),
            _buildInfoRow("Monthly Income", widget.request.monthlyIncome != null
                ? 'PKR ${widget.request.monthlyIncome}'
                : 'N/A'),
            if (widget.request.specialNeeds != null && widget.request.specialNeeds!.isNotEmpty)
              _buildInfoRow("Special Needs", widget.request.specialNeeds!),
          ],
        ),
      ),
    );
  }

  Widget _buildCNICSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CNIC Images",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            if (widget.request.cnicFrontUrl != null) ...[
              _buildCNICImage("CNIC Front", widget.request.cnicFrontUrl!),
              const SizedBox(height: 16),
            ],
            if (widget.request.cnicBackUrl != null)
              _buildCNICImage("CNIC Back", widget.request.cnicBackUrl!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCNICImage(String label, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error, color: Colors.red),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _VerificationDialog extends StatefulWidget {
  final VerificationRequest request;
  final String ngoId;
  final Function(String method, String notes) onVerify;

  const _VerificationDialog({
    required this.request,
    required this.ngoId,
    required this.onVerify,
  });

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  final _notesController = TextEditingController();
  String _selectedMethod = 'Database Verification';

  final List<Map<String, dynamic>> _verificationMethods = [
    {
      'id': 'Database Verification',
      'title': 'Database Verification',
      'description': 'Verified through database records and uploaded documents',
      'icon': Icons.storage,
    },
    {
      'id': 'Phone Verification',
      'title': 'Phone Verification',
      'description': 'Verified via phone call conversation',
      'icon': Icons.phone,
    },
    {
      'id': 'Location Visit',
      'title': 'Location Visit',
      'description': 'Verified by visiting the acceptor\'s location',
      'icon': Icons.location_on,
    },
    {
      'id': 'Video Call',
      'title': 'Video Call',
      'description': 'Verified through video call',
      'icon': Icons.video_call,
    },
    {
      'id': 'Third Party',
      'title': 'Third Party Reference',
      'description': 'Verified through community reference',
      'icon': Icons.people,
    },
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Verify Acceptor"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Acceptor Name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.request.acceptorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Verification Method Selection
            const Text(
              "How did you verify this acceptor?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // Method Options
            ..._verificationMethods.map((method) {
              final isSelected = _selectedMethod == method['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMethod = method['id'];
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? Colors.green.shade50 : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          method['icon'],
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.green.shade900 : Colors.black,
                                ),
                              ),
                              Text(
                                method['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.green.shade700 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),

            // Verification Notes
            const Text(
              "Verification Notes:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Add any additional details about the verification...",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onVerify(_selectedMethod, _notesController.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("Verify"),
        ),
      ],
    );
  }
}