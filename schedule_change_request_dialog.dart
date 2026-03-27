import 'package:flutter/material.dart';
import 'package:sharebites/models/donation_model.dart';

class ScheduleChangeRequestDialog extends StatefulWidget {
  final Donation donation;
  final String userRole;
  final Function(Map<String, dynamic>)? onSubmit;

  const ScheduleChangeRequestDialog({
    super.key,
    required this.donation,
    required this.userRole,
    this.onSubmit,
  });

  @override
  State<ScheduleChangeRequestDialog> createState() => _ScheduleChangeRequestDialogState();
}

class _ScheduleChangeRequestDialogState extends State<ScheduleChangeRequestDialog> {
  final _reasonController = TextEditingController();
  DateTime? _newScheduledDate;
  String? _newScheduledTime;
  String? _newDeliveryMethod;

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
    _newScheduledDate = widget.donation.scheduledDate;
    _newScheduledTime = widget.donation.scheduledTime;
    _newDeliveryMethod = widget.donation.deliveryMethod;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _newScheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: widget.donation.expiryDate.isAfter(DateTime.now().add(const Duration(days: 1)))
          ? widget.donation.expiryDate.subtract(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() => _newScheduledDate = picked);
    }
  }

  bool _hasChanges() {
    final origDate = widget.donation.scheduledDate?.toLocal().toString().split(' ')[0];
    final newDate = _newScheduledDate?.toLocal().toString().split(' ')[0];
    return newDate != origDate ||
        _newScheduledTime != widget.donation.scheduledTime ||
        _newDeliveryMethod != widget.donation.deliveryMethod;
  }

  void _submitRequest() async {
    if (!_hasChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please make at least one change to the schedule"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide a reason for the schedule change"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = {
      'newScheduledDate': _newScheduledDate,
      'newScheduledTime': _newScheduledTime,
      'newDeliveryMethod': _newDeliveryMethod,
      'changeReason': _reasonController.text.trim(),
    };

    if (widget.onSubmit != null) {
      widget.onSubmit!(result);
      Navigator.pop(context, result);
    } else {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = widget.userRole == 'donor';
    final color = isDonor ? Colors.orange : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Schedule Change"),
        backgroundColor: color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Current Schedule",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCurrentDetailRow(
                      Icons.calendar_today,
                      "Date",
                      widget.donation.scheduledDate?.toLocal().toString().split(' ')[0] ?? 'Not set',
                    ),
                    _buildCurrentDetailRow(
                      Icons.access_time,
                      "Time",
                      widget.donation.scheduledTime ?? 'Not set',
                    ),
                    _buildCurrentDetailRow(
                      widget.donation.deliveryMethod == 'pickup'
                          ? Icons.directions_walk
                          : Icons.local_shipping,
                      "Method",
                      widget.donation.deliveryMethod == 'pickup'
                          ? 'Acceptor will pickup'
                          : 'Delivery',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Proposed New Schedule",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: InkWell(
                onTap: _selectDate,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: color),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "New Date",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _newScheduledDate != null
                                  ? _newScheduledDate!.toLocal().toString().split(' ')[0]
                                  : "Select new date",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _newScheduledDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: color, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "New Time Slot",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((slot) {
                final isSelected = _newScheduledTime == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _newScheduledTime = selected ? slot : null;
                    });
                  },
                  selectedColor: color,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            const Text(
              "New Delivery Method",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: _newDeliveryMethod == 'pickup' ? color.withOpacity(0.1) : null,
                    child: InkWell(
                      onTap: () => setState(() => _newDeliveryMethod = 'pickup'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: _newDeliveryMethod == 'pickup' ? color : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Pickup",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _newDeliveryMethod == 'pickup' ? color : Colors.grey,
                              ),
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
                    color: _newDeliveryMethod == 'delivery' ? color.withOpacity(0.1) : null,
                    child: InkWell(
                      onTap: () => setState(() => _newDeliveryMethod = 'delivery'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: _newDeliveryMethod == 'delivery' ? color : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Delivery",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _newDeliveryMethod == 'delivery' ? color : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              "Reason for Schedule Change *",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Please explain why you need to change the schedule...\nExample: I have an emergency appointment, need to reschedule',
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 24),

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
                      isDonor
                          ? "The acceptor will be notified and can accept or decline your request."
                          : "The donor will be notified and can accept or decline your request.",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Request Change",
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

  Widget _buildCurrentDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
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