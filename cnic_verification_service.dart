import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ================= CNIC VERIFICATION RESULT MODEL =================

/// Result of CNIC verification
class CNICVerificationResult {
  final bool isValid;
  final String status; // 'valid', 'invalid', 'error'
  final List<String> foundKeywords;
  final List<String> missingKeywords;
  final String? cnicNumber;
  final double confidenceScore; // 0.0 to 1.0
  final String message;
  final Map<String, dynamic> details;

  CNICVerificationResult({
    required this.isValid,
    required this.status,
    required this.foundKeywords,
    required this.missingKeywords,
    this.cnicNumber,
    required this.confidenceScore,
    required this.message,
    required this.details,
  });

  @override
  String toString() {
    return 'CNICVerificationResult(isValid: $isValid, status: $status, '
        'confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%, '
        'cnicNumber: $cnicNumber, message: $message)';
  }
}

/// Result for both sides verification including CNIC match check
class CNICBothSidesResult {
  final CNICVerificationResult frontResult;
  final CNICVerificationResult backResult;
  final bool bothSidesValid;
  final bool cnicNumbersMatch;
  final String? frontCNIC;
  final String? backCNIC;
  final double overallConfidence;
  final String overallStatus; // 'valid', 'mismatch', 'partial', 'error'
  final String message;

  CNICBothSidesResult({
    required this.frontResult,
    required this.backResult,
    required this.bothSidesValid,
    required this.cnicNumbersMatch,
    this.frontCNIC,
    this.backCNIC,
    required this.overallConfidence,
    required this.overallStatus,
    required this.message,
  });

  @override
  String toString() {
    return 'CNICBothSidesResult('
        'overallStatus: $overallStatus, '
        'bothSidesValid: $bothSidesValid, '
        'cnicMatch: $cnicNumbersMatch, '
        'confidence: ${(overallConfidence * 100).toStringAsFixed(1)}%, '
        'message: $message)';
  }
}

class CNICVerificationService {
  static final CNICVerificationService _instance = CNICVerificationService._internal();
  factory CNICVerificationService() => _instance;
  CNICVerificationService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer();

  // ================= REQUIRED KEYWORDS =================

  /// ULTRA SIMPLIFIED Keywords for front side
  static const List<String> _frontKeywords = [
    'PAKISTAN',
    'NAME',
    'FATHER',
    'DATE',
    'BIRTH',
    'IDENTITY',
    'NUMBER',
  ];

  /// ULTRA SIMPLIFIED Keywords for back side
  static const List<String> _backKeywords = [
    'PAKISTAN',
    'ADDRESS',
    'REGISTRAR',
  ];

  /// ULTRA SIMPLIFIED Urdu keywords for front side
  static const List<String> _frontUrduKeywords = [
    'پاکستان',
    'نام',
    'والد',
    'تاریخ',
    'پیدائش',
    'شناختی',
    'نمبر',
  ];

  /// ULTRA SIMPLIFIED Urdu keywords for back side
  static const List<String> _backUrduKeywords = [
    'پاکستان',
    'پتہ',
    'رجسٹرار',
  ];

  // ================= REGEX PATTERNS =================

  /// CNIC number pattern: xxxxx-xxxxxxx-x
  static final RegExp _cnicPattern = RegExp(r'\d{5}[-\s]?\d{7}[-\s]?\d{1}');

  /// Date pattern: DD-MM-YYYY or DD/MM/YYYY
  static final RegExp _datePattern = RegExp(r'\d{2}[-/]\d{2}[-/]\d{4}');

  // ================= MAIN VERIFICATION METHODS =================

  /// Verify CNIC front side
  Future<CNICVerificationResult> verifyCNICFront(File imageFile) async {
    try {
      print('=== CNIC FRONT VERIFICATION STARTED ===');
      print('Image path: ${imageFile.path}');

      // Extract text from image
      final extractedText = await _extractTextFromImage(imageFile);

      if (extractedText.isEmpty) {
        return CNICVerificationResult(
          isValid: false,
          status: 'invalid',
          foundKeywords: [],
          missingKeywords: _frontKeywords,
          confidenceScore: 0.0,
          message: 'No text detected. Please ensure the CNIC is clearly visible.',
          details: {'error': 'No text detected'},
        );
      }

      print('Extracted text length: ${extractedText.length} characters');
      print('Extracted text: $extractedText');

      // Perform validation
      final result = _validateFrontSide(extractedText);

      print('=== VERIFICATION COMPLETE ===');
      print(result.toString());

      return result;

    } catch (e, stackTrace) {
      print('[ERROR] Error during CNIC front verification: $e');
      print('Stack trace: $stackTrace');

      return CNICVerificationResult(
        isValid: false,
        status: 'error',
        foundKeywords: [],
        missingKeywords: _frontKeywords,
        confidenceScore: 0.0,
        message: 'Error processing image: ${e.toString()}',
        details: {'error': e.toString()},
      );
    }
  }

  /// Verify CNIC back side
  Future<CNICVerificationResult> verifyCNICBack(File imageFile) async {
    try {
      print('=== CNIC BACK VERIFICATION STARTED ===');
      print('Image path: ${imageFile.path}');

      // Extract text from image
      final extractedText = await _extractTextFromImage(imageFile);

      if (extractedText.isEmpty) {
        return CNICVerificationResult(
          isValid: false,
          status: 'invalid',
          foundKeywords: [],
          missingKeywords: _backKeywords,
          confidenceScore: 0.0,
          message: 'No text detected. Please ensure the CNIC back is clearly visible.',
          details: {'error': 'No text detected'},
        );
      }

      print('Extracted text length: ${extractedText.length} characters');
      print('Extracted text: $extractedText');

      // Perform validation
      final result = _validateBackSide(extractedText);

      print('=== VERIFICATION COMPLETE ===');
      print(result.toString());

      return result;

    } catch (e, stackTrace) {
      print('[ERROR] Error during CNIC back verification: $e');
      print('Stack trace: $stackTrace');

      return CNICVerificationResult(
        isValid: false,
        status: 'error',
        foundKeywords: [],
        missingKeywords: _backKeywords,
        confidenceScore: 0.0,
        message: 'Error processing image: ${e.toString()}',
        details: {'error': e.toString()},
      );
    }
  }

  /// Verify both CNIC sides and check if they belong to the same card
  Future<CNICBothSidesResult> verifyBothSides({
    required File frontImage,
    required File backImage,
    bool requireCNICMatch = true, // Set to false if you want to allow verification without CNIC match
  }) async {
    print('=== VERIFYING BOTH CNIC SIDES ===');
    print('Require CNIC match: $requireCNICMatch');

    final frontResult = await verifyCNICFront(frontImage);
    final backResult = await verifyCNICBack(backImage);

    print('Front valid: ${frontResult.isValid}');
    print('Back valid: ${backResult.isValid}');
    print('Front CNIC: ${frontResult.cnicNumber}');
    print('Back CNIC: ${backResult.cnicNumber}');

    // Check if CNIC numbers match
    final cnicMatchResult = _checkCNICNumbersMatch(
      frontResult.cnicNumber,
      backResult.cnicNumber,
    );

    // Calculate overall confidence
    final overallConfidence = _calculateOverallConfidence(
      frontResult.confidenceScore,
      backResult.confidenceScore,
    );

    // Determine overall status
    final bothValid = frontResult.isValid && backResult.isValid;
    final overallStatus = _determineOverallStatus(
      bothValid: bothValid,
      cnicMatch: cnicMatchResult.match,
      frontHasCNIC: frontResult.cnicNumber != null,
      backHasCNIC: backResult.cnicNumber != null,
      requireCNICMatch: requireCNICMatch,
    );

    // Generate message
    final message = _generateOverallMessage(
      overallStatus: overallStatus,
      frontValid: frontResult.isValid,
      backValid: backResult.isValid,
      cnicMatchResult: cnicMatchResult,
      frontCNIC: frontResult.cnicNumber,
      backCNIC: backResult.cnicNumber,
    );

    return CNICBothSidesResult(
      frontResult: frontResult,
      backResult: backResult,
      bothSidesValid: bothValid,
      cnicNumbersMatch: cnicMatchResult.match,
      frontCNIC: frontResult.cnicNumber,
      backCNIC: backResult.cnicNumber,
      overallConfidence: overallConfidence,
      overallStatus: overallStatus,
      message: message,
    );
  }

  // ================= CNIC NUMBER MATCHING =================

  /// Check if CNIC numbers from both sides match
  CNICMatchResult _checkCNICNumbersMatch(String? frontCNIC, String? backCNIC) {
    print('=== CHECKING CNIC NUMBER MATCH ===');
    print('Front CNIC: $frontCNIC');
    print('Back CNIC: $backCNIC');

    // If either is null, can't compare
    if (frontCNIC == null || backCNIC == null) {
      return CNICMatchResult(
        match: false,
        reason: frontCNIC == null && backCNIC == null
            ? 'No CNIC numbers found on either side'
            : 'CNIC number missing on ${frontCNIC == null ? 'front' : 'back'} side',
        details: {
          'frontCNIC': frontCNIC,
          'backCNIC': backCNIC,
        },
      );
    }

    // Normalize CNIC numbers (remove dashes, spaces)
    final normalizedFront = _normalizeCNICNumber(frontCNIC);
    final normalizedBack = _normalizeCNICNumber(backCNIC);

    print('Normalized Front: $normalizedFront');
    print('Normalized Back: $normalizedBack');

    // Check if they match
    if (normalizedFront == normalizedBack) {
      return CNICMatchResult(
        match: true,
        reason: 'CNIC numbers match exactly',
        details: {
          'frontCNIC': frontCNIC,
          'backCNIC': backCNIC,
          'normalizedFront': normalizedFront,
          'normalizedBack': normalizedBack,
        },
      );
    }

    // Check partial matches (maybe OCR misread a character)
    final similarity = _calculateCNICSimilarity(normalizedFront, normalizedBack);
    print('CNIC similarity: ${(similarity * 100).toStringAsFixed(1)}%');

    if (similarity >= 0.85) { // 85% similar
      return CNICMatchResult(
        match: true,
        reason: 'CNIC numbers are highly similar (${(similarity * 100).toStringAsFixed(1)}%)',
        details: {
          'frontCNIC': frontCNIC,
          'backCNIC': backCNIC,
          'normalizedFront': normalizedFront,
          'normalizedBack': normalizedBack,
          'similarity': similarity,
        },
      );
    }

    return CNICMatchResult(
      match: false,
      reason: 'CNIC numbers do not match (similarity: ${(similarity * 100).toStringAsFixed(1)}%)',
      details: {
        'frontCNIC': frontCNIC,
        'backCNIC': backCNIC,
        'normalizedFront': normalizedFront,
        'normalizedBack': normalizedBack,
        'similarity': similarity,
      },
    );
  }

  /// Normalize CNIC number (remove all non-digits)
  String _normalizeCNICNumber(String cnic) {
    return cnic.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Calculate similarity between two CNIC numbers (0.0 to 1.0)
  double _calculateCNICSimilarity(String cnic1, String cnic2) {
    if (cnic1.length != cnic2.length) {
      return 0.0;
    }

    int matchingDigits = 0;
    for (int i = 0; i < cnic1.length; i++) {
      if (cnic1[i] == cnic2[i]) {
        matchingDigits++;
      }
    }

    return matchingDigits / cnic1.length;
  }

  // ================= OVERALL VERIFICATION LOGIC =================

  /// Calculate overall confidence score
  double _calculateOverallConfidence(double frontConfidence, double backConfidence) {
    // Weight front side slightly more important (60/40 split)
    return (frontConfidence * 0.6 + backConfidence * 0.4);
  }

  /// Determine overall status
  String _determineOverallStatus({
    required bool bothValid,
    required bool cnicMatch,
    required bool frontHasCNIC,
    required bool backHasCNIC,
    required bool requireCNICMatch,
  }) {
    if (!bothValid) {
      return 'partial';
    }

    if (requireCNICMatch) {
      if (!frontHasCNIC || !backHasCNIC) {
        return 'partial';
      }
      if (!cnicMatch) {
        return 'mismatch';
      }
      return 'valid';
    } else {
      // If CNIC match is not required, just check if both sides are valid
      return bothValid ? 'valid' : 'partial';
    }
  }

  /// Generate overall message
  String _generateOverallMessage({
    required String overallStatus,
    required bool frontValid,
    required bool backValid,
    required CNICMatchResult cnicMatchResult,
    String? frontCNIC,
    String? backCNIC,
  }) {
    switch (overallStatus) {
      case 'valid':
        if (frontCNIC != null && backCNIC != null && cnicMatchResult.match) {
          return '[SUCCESS]: Both CNIC sides are valid and belong to the same card.\n'
              'CNIC Number: $frontCNIC';
        } else {
          return '[SUCCESS]: Both CNIC sides are valid.';
        }

      case 'mismatch':
        return '[WARNING]: Both sides appear valid but CNIC numbers do not match.\n'
            'Front CNIC: ${frontCNIC ?? "Not found"}\n'
            'Back CNIC: ${backCNIC ?? "Not found"}\n'
            'Reason: ${cnicMatchResult.reason}\n'
            '[WARNING] These may be images of different CNIC cards.';

      case 'partial':
        final messages = <String>[];
        if (!frontValid) messages.add('Front side verification failed');
        if (!backValid) messages.add('Back side verification failed');
        if (frontCNIC == null) messages.add('No CNIC number found on front');
        if (backCNIC == null) messages.add('No CNIC number found on back');

        return '[PARTIAL] ${messages.join(", ")}. Please retake clear images.';

      case 'error':
        return '[ERROR]: Unable to process one or both images. Please try again.';

      default:
        return 'Unknown status: $overallStatus';
    }
  }

  // ================= TEXT EXTRACTION =================

  /// Extract text from image using ML Kit
  Future<String> _extractTextFromImage(File imageFile) async {
    try {
      print('[INFO] Processing image with ML Kit...');

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Combine all text blocks
      final StringBuffer textBuffer = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        textBuffer.writeln(block.text);
      }

      final extractedText = textBuffer.toString().trim();

      print('[SUCCESS] Text extraction complete');
      print('Blocks found: ${recognizedText.blocks.length}');

      return extractedText;

    } catch (e) {
      print('[ERROR] Error extracting text: $e');
      rethrow;
    }
  }

  // ================= VALIDATION LOGIC =================

  /// Validate front side text - ULTRA SIMPLIFIED
  CNICVerificationResult _validateFrontSide(String text) {
    final textUpper = text.toUpperCase();

    // Track found keywords
    final foundKeywords = <String>[];
    final missingKeywords = <String>[];

    // Check for required English keywords
    for (String keyword in _frontKeywords) {
      if (_containsKeyword(textUpper, keyword)) {
        foundKeywords.add(keyword);
        print('[SUCCESS] Found (EN): $keyword');
      } else {
        missingKeywords.add(keyword);
        print('[MISSING] Missing (EN): $keyword');
      }
    }

    // Check for Urdu keywords
    final urduFound = <String>[];
    for (String keyword in _frontUrduKeywords) {
      if (_containsKeyword(text, keyword)) {
        urduFound.add(keyword);
        foundKeywords.add('URDU:$keyword');
        print('[SUCCESS] Found (UR): $keyword');
      }
    }

    // Extract CNIC number
    final cnicNumber = _extractCNICNumber(text);

    // Calculate confidence score for front side - ULTRA SIMPLIFIED
    final totalFound = foundKeywords.length;
    final score = _calculateConfidenceScore(
      totalFound: totalFound,
      possibleKeywords: _frontKeywords.length + _frontUrduKeywords.length,
      hasCNICNumber: cnicNumber != null,
      isFront: true,
    );

    // Determine validity - VERY SIMPLE
    // Front needs CNIC + at least 3 keywords
    final isValid = cnicNumber != null && totalFound >= 3 && score >= 0.50;

    // Generate message
    final message = isValid
        ? '[SUCCESS] Valid CNIC front: CNIC number + $totalFound keywords found'
        : '[ERROR] CNIC front verification failed: ${cnicNumber == null ? 'CNIC number not found' : 'Only $totalFound keywords found (need 3)'}';

    return CNICVerificationResult(
      isValid: isValid,
      status: isValid ? 'valid' : 'invalid',
      foundKeywords: foundKeywords,
      missingKeywords: missingKeywords,
      cnicNumber: cnicNumber,
      confidenceScore: score,
      message: message,
      details: {
        'totalKeywordsFound': totalFound,
        'hasCNICNumber': cnicNumber != null,
        'extractedCNIC': cnicNumber,
      },
    );
  }

  /// Validate back side text - ULTRA SIMPLIFIED
  CNICVerificationResult _validateBackSide(String text) {
    final textUpper = text.toUpperCase();

    // Track found keywords
    final foundKeywords = <String>[];
    final missingKeywords = <String>[];

    // Check for required English keywords
    for (String keyword in _backKeywords) {
      if (_containsKeyword(textUpper, keyword)) {
        foundKeywords.add(keyword);
        print('[SUCCESS] Found (EN): $keyword');
      } else {
        missingKeywords.add(keyword);
        print('[MISSING] Missing (EN): $keyword');
      }
    }

    // Check for Urdu keywords
    final urduFound = <String>[];
    for (String keyword in _backUrduKeywords) {
      if (_containsKeyword(text, keyword)) {
        urduFound.add(keyword);
        foundKeywords.add('URDU:$keyword');
        print('[SUCCESS] Found (UR): $keyword');
      }
    }

    // Extract CNIC number - VERY IMPORTANT FOR BACK
    final cnicNumber = _extractCNICNumber(text);

    // Check for QR code indicator
    final hasQR = textUpper.contains('QR') ||
        text.contains('کیو آر') ||
        textUpper.contains('CODE');

    // Calculate confidence score for back side - ULTRA SIMPLIFIED
    final totalFound = foundKeywords.length;
    final score = _calculateConfidenceScore(
      totalFound: totalFound,
      possibleKeywords: _backKeywords.length + _backUrduKeywords.length,
      hasCNICNumber: cnicNumber != null,
      hasQRCode: hasQR,
      isFront: false,
    );

    // Determine validity - BACK SIDE IS VERY LENIENT
    // Back needs: EITHER CNIC number OR (2 keywords + QR code) OR 3 keywords
    final hasEnoughKeywords = totalFound >= 2;
    final isValid =
        (cnicNumber != null && score >= 0.40) ||  // CNIC alone can pass
            (hasEnoughKeywords && hasQR && score >= 0.40) ||  // 2 keywords + QR
            (totalFound >= 3 && score >= 0.40);  // 3 keywords

    // Generate message
    String message;
    if (isValid) {
      if (cnicNumber != null) {
        message = '[SUCCESS] Valid CNIC back: CNIC number verified';
      } else if (hasQR) {
        message = '[SUCCESS] Valid CNIC back: QR code + $totalFound keywords found';
      } else {
        message = '[SUCCESS] Valid CNIC back: $totalFound keywords found';
      }
    } else {
      message = '[ERROR] CNIC back verification failed: Only $totalFound keywords found';
      if (cnicNumber == null) {
        message += ', no CNIC number';
      }
      if (!hasQR) {
        message += ', no QR code';
      }
    }

    return CNICVerificationResult(
      isValid: isValid,
      status: isValid ? 'valid' : 'invalid',
      foundKeywords: foundKeywords,
      missingKeywords: missingKeywords,
      cnicNumber: cnicNumber,
      confidenceScore: score,
      message: message,
      details: {
        'totalKeywordsFound': totalFound,
        'hasCNICNumber': cnicNumber != null,
        'hasQRCode': hasQR,
        'extractedCNIC': cnicNumber,
      },
    );
  }

  // ================= HELPER METHODS =================

  /// Check if text contains keyword (with variations) - ULTRA SIMPLIFIED
  bool _containsKeyword(String text, String keyword) {
    // For English keywords
    if (!_isUrduKeyword(keyword)) {
      final textUpper = text.toUpperCase();
      final keywordUpper = keyword.toUpperCase();

      // SIMPLE: Just check if it's contained
      if (textUpper.contains(keywordUpper)) {
        return true;
      }

      // Also check for partial matches for short words
      if (keywordUpper.length <= 4) {
        final words = textUpper.split(RegExp(r'[^A-Z0-9]'));
        for (String word in words) {
          if (word.contains(keywordUpper)) {
            return true;
          }
        }
      }
    } else {
      // For Urdu keywords - just check if contained
      if (text.contains(keyword)) {
        return true;
      }

      // Try partial matches (2+ characters)
      if (keyword.length >= 2) {
        for (int i = 0; i <= keyword.length - 2; i++) {
          final substring = keyword.substring(i, i + 2);
          if (text.contains(substring)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if keyword is Urdu
  bool _isUrduKeyword(String keyword) {
    final urduRange = RegExp(r'[\u0600-\u06FF]');
    return urduRange.hasMatch(keyword);
  }

  /// Extract CNIC number from text - IMPROVED AND SIMPLIFIED
  String? _extractCNICNumber(String text) {
    // First, clean the text
    final cleanText = text.replaceAll('\n', ' ').replaceAll('\r', ' ');

    // Try multiple patterns in order
    final patterns = [
      // Standard format: 12345-1234567-1
      r'\d{5}[-\s_]\d{7}[-\s_]\d{1}',
      // 13 digits without separators
      r'\d{13}',
      // Any sequence of 13 digits
      r'\b\d{13}\b',
      // With spaces: 12345 1234567 1
      r'\d{5}\s\d{7}\s\d{1}',
    ];

    for (String pattern in patterns) {
      final matches = RegExp(pattern).allMatches(cleanText);
      for (final match in matches) {
        String cnic = match.group(0)!;

        // Format it properly
        if (!cnic.contains('-') && !cnic.contains('_') && cnic.length == 13) {
          // Format: 12345-1234567-1
          cnic = '${cnic.substring(0, 5)}-${cnic.substring(5, 12)}-${cnic.substring(12)}';
        } else {
          // Replace spaces/underscores with dashes
          cnic = cnic.replaceAll(' ', '-').replaceAll('_', '-');
        }

        print('[FOUND] CNIC Number found: $cnic');
        return cnic;
      }
    }

    // Also try to find CNIC near common labels
    final labelPatterns = [
      r'(?:CNIC|NIC|ID|NUMBER|NO)[:\s]*(\d{5}[-\s_]\d{7}[-\s_]\d{1}|\d{13})',
      r'(\d{5}[-\s_]\d{7}[-\s_]\d{1})\s*(?:CNIC|NIC|ID|NUMBER)',
    ];

    for (String pattern in labelPatterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(cleanText);
      if (match != null && match.group(1) != null) {
        String cnic = match.group(1)!;
        if (!cnic.contains('-') && !cnic.contains('_') && cnic.length == 13) {
          cnic = '${cnic.substring(0, 5)}-${cnic.substring(5, 12)}-${cnic.substring(12)}';
        } else {
          cnic = cnic.replaceAll(' ', '-').replaceAll('_', '-');
        }
        print('[FOUND] CNIC Number found (with label): $cnic');
        return cnic;
      }
    }

    print('[INFO] No CNIC number pattern found');
    return null;
  }

  /// Calculate confidence score - ULTRA SIMPLIFIED
  double _calculateConfidenceScore({
    required int totalFound,
    required int possibleKeywords,
    required bool hasCNICNumber,
    bool hasQRCode = false,
    required bool isFront,
  }) {
    double score = 0.0;

    if (isFront) {
      // Front side scoring
      // Keywords: 50% weight
      final keywordRatio = totalFound / possibleKeywords;
      score += keywordRatio * 0.5;

      // CNIC number: 50% weight (REQUIRED)
      if (hasCNICNumber) {
        score += 0.5;
      }
    } else {
      // Back side scoring - CNIC NUMBER IS KING
      // CNIC number: 70% weight (can pass alone)
      if (hasCNICNumber) {
        score += 0.7;
      }

      // Keywords: 20% weight
      final keywordRatio = totalFound / possibleKeywords;
      score += keywordRatio * 0.2;

      // QR code: 10% weight
      if (hasQRCode) {
        score += 0.1;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  // ================= UTILITY METHODS =================

  /// Get validation requirements for front side
  static Map<String, dynamic> getFrontRequirements() {
    return {
      'englishKeywords': _frontKeywords,
      'urduKeywords': _frontUrduKeywords,
      'mustHaveCNIC': true,
      'minimumKeywords': 3,
      'minimumConfidence': 50,
      'description': 'CNIC front: CNIC number + 3+ keywords',
    };
  }

  /// Get validation requirements for back side
  static Map<String, dynamic> getBackRequirements() {
    return {
      'englishKeywords': _backKeywords,
      'urduKeywords': _backUrduKeywords,
      'mustHaveCNIC': false,
      'minimumKeywords': 2,
      'minimumConfidence': 40,
      'description': 'CNIC back: CNIC number (70%) OR 2 keywords + QR OR 3 keywords',
    };
  }

  /// Get CNIC matching requirements
  static Map<String, dynamic> getCNICMatchingRequirements() {
    return {
      'requireExactMatch': false,
      'minimumSimilarity': 85,
      'description': 'CNIC numbers should match or be at least 85% similar',
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

// ================= HELPER CLASSES =================

/// Result of CNIC number matching
class CNICMatchResult {
  final bool match;
  final String reason;
  final Map<String, dynamic> details;

  CNICMatchResult({
    required this.match,
    required this.reason,
    required this.details,
  });
}