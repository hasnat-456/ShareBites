import 'package:flutter/material.dart';
import 'package:sharebites/models/schedule_change_model.dart';

class ScheduleChangeResponseDialog extends StatefulWidget {
  final ScheduleChangeRequest changeRequest;
  final String currentUserRole;

  const ScheduleChangeResponseDialog({
    super.key,
    required this.changeRequest,
    required this.currentUserRole,
  });

  @override
  State<ScheduleChangeResponseDialog> createState() => _ScheduleChangeResponseDialogState();
}

class _ScheduleChangeResponseDialogState extends State<ScheduleChangeResponseDialog> {
  final _responseNoteController = TextEditingController();

  @override
  void dispose() {
    _responseNoteController.dispose();
    super.dispose();
  }

  void _acceptChange() {
    final result = {
      'action': 'accept',
      'responseNote': _responseNoteController.text.trim(),
    };
    Navigator.pop(context, result);
  }

  void _rejectChange() {
    if (_responseNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide a reason for rejecting the request"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = {
      'action': 'reject',
      'responseNote': _responseNoteController.text.trim(),
    };
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = widget.currentUserRole == 'donor';
    final color = isDonor ? Colors.orange : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule Change Request"),
        backgroundColor: color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Request From",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.changeRequest.requesterName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Requested on: ${widget.changeRequest.requestedAt.toLocal().toString().split('.')[0]}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: color),
                        const SizedBox(width: 8),
                        const Text(
                          "Proposed New Schedule",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.changeRequest.newScheduledDate != null)
                      _buildChangeRow(
                        Icons.calendar_today,
                        "New Date",
                        widget.changeRequest.newScheduledDate!
                            .toLocal()
                            .toString()
                            .split(' ')[0],
                      ),
                    if (widget.changeRequest.newScheduledTime != null)
                      _buildChangeRow(
                        Icons.access_time,
                        "New Time",
                        widget.changeRequest.newScheduledTime!,
                      ),
                    if (widget.changeRequest.newDeliveryMethod != null)
                      _buildChangeRow(
                        widget.changeRequest.newDeliveryMethod == 'pickup'
                            ? Icons.directions_walk
                            : Icons.local_shipping,
                        "New Method",
                        widget.changeRequest.newDeliveryMethod == 'pickup' ? 'Pickup' : 'Delivery',
                      ),
                    if (widget.changeRequest.newScheduledDate == null &&
                        widget.changeRequest.newScheduledTime == null &&
                        widget.changeRequest.newDeliveryMethod == null)
                      const Text(
                        'No specific changes proposed.',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, color: color),
                        const SizedBox(width: 8),
                        const Text(
                          "Reason for Change",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.changeRequest.changeReason,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Your Response (Optional for Accept, Required for Reject)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _responseNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Add a message to the requester...',
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "If you reject, please provide a reason. You can also suggest an alternative schedule.",
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _acceptChange,
                    icon: const Icon(Icons.check_circle, size: 24),
                    label: const Text(
                      "Accept New Schedule",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _rejectChange,
                    icon: const Icon(Icons.cancel, size: 24),
                    label: const Text(
                      "Reject Request",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}