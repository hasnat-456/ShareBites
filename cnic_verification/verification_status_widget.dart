import 'package:flutter/material.dart';
import 'package:sharebites/models/verification_request_model.dart';
import 'package:sharebites/verifier/ngo_service.dart';

class VerificationStatusWidget extends StatefulWidget {
  final String acceptorId;

  const VerificationStatusWidget({super.key, required this.acceptorId});

  @override
  State<VerificationStatusWidget> createState() => _VerificationStatusWidgetState();
}

class _VerificationStatusWidgetState extends State<VerificationStatusWidget> {
  final NGOService _ngoService = NGOService();
  VerificationRequest? _verificationRequest;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final request = await _ngoService.getAcceptorVerificationStatus(widget.acceptorId);

      if (mounted) {
        setState(() {
          _verificationRequest = request;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading verification status: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildCompactView() {
    if (_verificationRequest == null) {
      return ListTile(
        leading: Icon(
          Icons.info_outline,
          color: Colors.blue[700],
        ),
        title: const Text(
          "Verification",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          "Not Started",
          style: TextStyle(fontSize: 13),
        ),
        trailing: Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey,
          size: 20,
        ),
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    }

    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusText = _getCompactStatusText();

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        "Verification",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      subtitle: Text(
        statusText,
        style: TextStyle(
          fontSize: 13,
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_verificationRequest!.status == 'Assigned' && _verificationRequest!.assignedNgoName != null)
            Icon(
              Icons.business,
              size: 16,
              color: Colors.blue[700],
            ),
          const SizedBox(width: 8),
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildExpandedView() {
    if (_verificationRequest == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Complete Your Profile",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            const Text(
              "To start the verification process, please:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(Icons.person_add, "Complete your profile"),
            _buildInstructionItem(Icons.upload_file, "Upload CNIC (front & back)"),
            _buildInstructionItem(Icons.location_on, "Add your address"),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please go to Edit Profile to complete your information"),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text(
                  "Go to Edit Profile",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = _getStatusColor();
    final statusText = _getStatusText();
    final detailedText = _getDetailedStatusText();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: statusColor.withOpacity(0.2)),
          bottom: BorderSide(color: statusColor.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status overview
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      detailedText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Additional information
          if (_verificationRequest!.status == 'Assigned' &&
              _verificationRequest!.assignedNgoName != null)
            _buildInfoCard(
              icon: Icons.business,
              iconColor: Colors.blue,
              title: "Assigned NGO",
              content: _verificationRequest!.assignedNgoName!,
            ),

          if (_verificationRequest!.status == 'Assigned' &&
              _verificationRequest!.expiresAt != null)
            _buildInfoCard(
              icon: Icons.timer,
              iconColor: Colors.orange,
              title: "Expected Completion",
              content: _formatDate(_verificationRequest!.expiresAt!),
            ),

          if (_verificationRequest!.status == 'Verified' &&
              _verificationRequest!.verifiedAt != null)
            _buildInfoCard(
              icon: Icons.calendar_today,
              iconColor: Colors.green,
              title: "Verified On",
              content: _formatDate(_verificationRequest!.verifiedAt!),
            ),

          // Notes and reasons
          if (_verificationRequest!.status == 'Verified' &&
              _verificationRequest!.verifierNotes != null &&
              _verificationRequest!.verifierNotes!.isNotEmpty)
            _buildInfoCard(
              icon: Icons.note,
              iconColor: Colors.green,
              title: "Verifier Notes",
              content: _verificationRequest!.verifierNotes!,
            ),

          if (_verificationRequest!.status == 'Rejected' &&
              _verificationRequest!.rejectionReason != null)
            _buildInfoCard(
              icon: Icons.warning,
              iconColor: Colors.red,
              title: "Rejection Reason",
              content: _verificationRequest!.rejectionReason!,
            ),

          // Action buttons
          if (_verificationRequest!.status == 'Rejected') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please update your profile and try again"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  "Reapply for Verification",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],

          // Help text
          if (_verificationRequest!.status == 'Assigned')
            const SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "The assigned NGO may contact you for verification. Please keep your phone nearby.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _getCompactStatusText() {
    final status = _verificationRequest?.status;
    switch (status) {
      case 'Pending':
        return 'In Queue';
      case 'Assigned':
        return 'Under Review';
      case 'Verified':
        return 'Verified ✔';
      case 'Rejected':
        return 'Rejected ✗';
      default:
        return 'Not Started';
    }
  }

  String _getStatusText() {
    final status = _verificationRequest?.status;
    switch (status) {
      case 'Pending':
        return 'Pending Assignment';
      case 'Assigned':
        return 'Under Review';
      case 'Verified':
        return 'Verified Successfully!';
      case 'Rejected':
        return 'Verification Rejected';
      default:
        return 'Not Started';
    }
  }

  String _getDetailedStatusText() {
    final status = _verificationRequest?.status;
    switch (status) {
      case 'Pending':
        return 'Waiting for NGO assignment';
      case 'Assigned':
        return 'An NGO is reviewing your information';
      case 'Verified':
        return 'You can now receive donations';
      case 'Rejected':
        return 'Please check reason below';
      default:
        return 'Complete your profile to start';
    }
  }

  IconData _getStatusIcon() {
    final status = _verificationRequest?.status;
    switch (status) {
      case 'Pending':
        return Icons.pending_actions;
      case 'Assigned':
        return Icons.assignment_ind;
      case 'Verified':
        return Icons.verified_user;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor() {
    final status = _verificationRequest?.status;
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Assigned':
        return Colors.blue;
      case 'Verified':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green[700],
            ),
          ),
          title: const Text(
            "Verification",
            style: TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: const Text(
            "Checking status...",
            style: TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Compact view (always visible)
          _buildCompactView(),

          // Expanded view (only visible when expanded)
          if (_expanded) _buildExpandedView(),
        ],
      ),
    );
  }
}