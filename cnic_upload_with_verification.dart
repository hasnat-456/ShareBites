import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'cnic_verification_service.dart';

class CNICUploadWithVerificationWidget extends StatefulWidget {
  final String? frontImageUrl;
  final String? backImageUrl;
  final Function(File, String) onImageSelected;
  final bool uploading;
  final String? verificationNote;

  const CNICUploadWithVerificationWidget({
    super.key,
    this.frontImageUrl,
    this.backImageUrl,
    required this.onImageSelected,
    this.uploading = false,
    this.verificationNote,
  });

  @override
  State<CNICUploadWithVerificationWidget> createState() =>
      _CNICUploadWithVerificationWidgetState();
}

class _CNICUploadWithVerificationWidgetState
    extends State<CNICUploadWithVerificationWidget> {
  final ImagePicker _picker = ImagePicker();
  final CNICVerificationService _verificationService = CNICVerificationService();

  File? _frontImageFile;
  File? _backImageFile;

  CNICVerificationResult? _frontVerificationResult;
  CNICVerificationResult? _backVerificationResult;

  bool _verifyingFront = false;
  bool _verifyingBack = false;

  @override
  void dispose() {
    _verificationService.dispose();
    super.dispose();
  }

  Future<void> _pickAndVerifyImage(String side) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);


        setState(() {
          if (side == 'front') {
            _frontImageFile = imageFile;
            _verifyingFront = true;
            _frontVerificationResult = null;
          } else {
            _backImageFile = imageFile;
            _verifyingBack = true;
            _backVerificationResult = null;
          }
        });


        await _verifyImage(imageFile, side);
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog('Failed to pick image: ${e.toString()}');

      setState(() {
        if (side == 'front') {
          _verifyingFront = false;
        } else {
          _verifyingBack = false;
        }
      });
    }
  }

  Future<void> _verifyImage(File imageFile, String side) async {
    try {
      print('=== Starting verification for $side side ===');

      CNICVerificationResult result;

      if (side == 'front') {
        result = await _verificationService.verifyCNICFront(imageFile);
      } else {
        result = await _verificationService.verifyCNICBack(imageFile);
      }

      setState(() {
        if (side == 'front') {
          _frontVerificationResult = result;
          _verifyingFront = false;
        } else {
          _backVerificationResult = result;
          _verifyingBack = false;
        }
      });


      _showVerificationResultDialog(result, side);


      if (result.isValid) {
        widget.onImageSelected(imageFile, side);
      }

    } catch (e) {
      print('Error verifying image: $e');

      setState(() {
        if (side == 'front') {
          _verifyingFront = false;
        } else {
          _verifyingBack = false;
        }
      });

      _showErrorDialog('Verification failed: ${e.toString()}');
    }
  }

  void _showVerificationResultDialog(
      CNICVerificationResult result,
      String side,
      ) {
    final isValid = result.isValid;
    final color = isValid ? Colors.green : Colors.red;
    final icon = isValid ? Icons.check_circle : Icons.error;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isValid ? 'CNIC Verified ✓' : 'Verification Failed',
                style: TextStyle(color: color),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  result.message,
                  style: TextStyle(
                    color: color.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),


              _buildInfoRow(
                'Confidence Score',
                '${(result.confidenceScore * 100).toStringAsFixed(1)}%',
                color: _getConfidenceColor(result.confidenceScore),
              ),

              const SizedBox(height: 12),


              if (result.cnicNumber != null) ...[
                _buildInfoRow(
                  'CNIC Number',
                  result.cnicNumber!,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
              ],


              if (result.foundKeywords.isNotEmpty) ...[
                const Text(
                  'Detected Keywords:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.foundKeywords.map((keyword) {
                    return Chip(
                      label: Text(
                        keyword,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade200),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],


              if (!isValid && result.missingKeywords.isNotEmpty) ...[
                const Text(
                  'Missing Keywords:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.missingKeywords.map((keyword) {
                    return Chip(
                      label: Text(
                        keyword,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade200),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],


              if (!isValid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tips for better results:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTipItem('Ensure CNIC is fully visible'),
                      _buildTipItem('Use good lighting'),
                      _buildTipItem('Avoid shadows and glare'),
                      _buildTipItem('Hold camera steady'),
                      _buildTipItem('Use original CNIC (not photocopy)'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!isValid)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _pickAndVerifyImage(side);
              },
              child: const Text('Retake Photo'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.green : Colors.grey,
            ),
            child: Text(isValid ? 'OK' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CNIC Verification',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),

        if (widget.verificationNote != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              widget.verificationNote!,
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        const Text(
          'Upload both sides of your CNIC. Images will be verified automatically using AI.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildCNICCard(
                'Front Side',
                widget.frontImageUrl,
                _frontImageFile,
                'front',
                _frontVerificationResult,
                _verifyingFront,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCNICCard(
                'Back Side',
                widget.backImageUrl,
                _backImageFile,
                'back',
                _backVerificationResult,
                _verifyingBack,
              ),
            ),
          ],
        ),

        if (widget.uploading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 8),
                  Text(
                    'Uploading to cloud...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),


        if (_frontVerificationResult != null || _backVerificationResult != null)
          _buildOverallStatus(),
      ],
    );
  }

  Widget _buildCNICCard(
      String title,
      String? imageUrl,
      File? imageFile,
      String side,
      CNICVerificationResult? verificationResult,
      bool verifying,
      ) {
    final hasImage = imageUrl != null || imageFile != null;
    final isVerified = verificationResult?.isValid ?? false;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (verificationResult != null)
                  Icon(
                    isVerified ? Icons.verified : Icons.warning,
                    color: isVerified ? Colors.green : Colors.orange,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),


            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: verifying
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 10),
                    Text(
                      'Verifying...',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  : hasImage
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageFile != null
                    ? Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
                    : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      side == 'front'
                          ? Icons.credit_card
                          : Icons.credit_card_outlined,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to upload',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),


            if (verificationResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: isVerified
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isVerified
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle : Icons.info,
                      size: 14,
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isVerified
                            ? 'Verified ✓'
                            : '${(verificationResult.confidenceScore * 100).toStringAsFixed(0)}% match',
                        style: TextStyle(
                          fontSize: 11,
                          color: isVerified
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),


            ElevatedButton.icon(
              onPressed: widget.uploading || verifying
                  ? null
                  : () => _pickAndVerifyImage(side),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 40),
                disabledBackgroundColor: Colors.grey,
              ),
              icon: Icon(
                hasImage ? Icons.refresh : Icons.cloud_upload,
                size: 18,
              ),
              label: Text(hasImage ? 'Change' : 'Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatus() {
    final frontValid = _frontVerificationResult?.isValid ?? false;
    final backValid = _backVerificationResult?.isValid ?? false;
    final bothValid = frontValid && backValid;

    if (!frontValid && !backValid &&
        _frontVerificationResult == null && _backVerificationResult == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bothValid
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bothValid
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            bothValid ? Icons.verified_user : Icons.pending,
            color: bothValid ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bothValid
                      ? 'CNIC Verification Complete ✓'
                      : 'CNIC Verification In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: bothValid
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bothValid
                      ? 'Both sides verified successfully'
                      : frontValid
                      ? 'Front verified. Please upload back side.'
                      : backValid
                      ? 'Back verified. Please upload front side.'
                      : 'Please upload both sides for verification',
                  style: TextStyle(
                    fontSize: 12,
                    color: bothValid
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}