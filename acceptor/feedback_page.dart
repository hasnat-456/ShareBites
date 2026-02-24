import 'package:flutter/material.dart';
import 'package:sharebites/models/received_donation_model.dart';
import 'package:sharebites/notifications/supabase_notification_service.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:firebase_database/firebase_database.dart';

class FeedbackPage extends StatefulWidget {
  final ReceivedDonation donation;

  const FeedbackPage({super.key, required this.donation});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  double rating = 0;
  late TextEditingController feedbackController;

  @override
  void initState() {
    super.initState();
    rating = widget.donation.rating;
    feedbackController =
        TextEditingController(text: widget.donation.feedback ?? '');
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  void _save() async {
    final updatedDonation = widget.donation.copyWith(
      rating: rating,
      feedback: feedbackController.text,
    );

    // Send notification to donor about feedback received
    try {
      final database = FirebaseDatabase.instance.ref();
      final donationSnapshot = await database
          .child('donations')
          .child(widget.donation.id)
          .once();

      if (donationSnapshot.snapshot.exists) {
        final donationData = donationSnapshot.snapshot.value as Map;
        final donorId = donationData['donorId']?.toString();

        if (donorId != null && donorId.isNotEmpty) {
          // Get acceptor name from current user session
          String acceptorName = 'Acceptor';
          try {
            final currentUser = AuthService().currentUser;
            if (currentUser != null) {
              acceptorName = currentUser.name;
            }
          } catch (_) {}

          await SupabaseNotificationHelper.notifyFeedbackReceived(
            donorId: donorId,
            acceptorName: acceptorName,
            donationTitle: widget.donation.title,
            rating: rating.toInt(),
            comment: feedbackController.text.isNotEmpty ? feedbackController.text : null,
          );

          print('✅ Donor notified of feedback from $acceptorName');
        }
      }
    } catch (e) {
      print('⚠️ Failed to notify donor of feedback: $e');
    }

    Navigator.pop(context, updatedDonation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Donation Feedback"),
        backgroundColor: Colors.green,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.donation.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Donor: ${widget.donation.donorName}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "Rate your experience",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() => rating = index + 1.0);
                              },
                              child: Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 36,
                              ),
                            );
                          }),
                          Text(
                            "${rating.toStringAsFixed(1)} / 5.0",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Feedback",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: feedbackController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Write your feedback here...",
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Save Feedback"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}