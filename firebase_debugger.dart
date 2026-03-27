import 'package:firebase_database/firebase_database.dart';

class FirebaseDebugger {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  /// Check Firebase connection and NGO data
  static Future<Map<String, dynamic>> checkNGODatabase() async {
    final result = <String, dynamic>{
      'connected': false,
      'ngoCount': 0,
      'ngos': <String>[],
      'error': null,
    };

    try {
      print('=== FIREBASE NGO DATABASE CHECK ===');

      // Check connection by reading root
      print('Step 1: Checking Firebase connection...');
      final rootSnapshot = await _databaseRef.child('.info/connected').once();
      result['connected'] = rootSnapshot.snapshot.value == true;
      print('Connected: ${result['connected']}');

      // Check NGO data - FIXED
      print('Step 2: Checking NGO data...');
      final ngoSnapshot = await _databaseRef.child('ngos').once();

      if (ngoSnapshot.snapshot.value != null) {
        final ngosData = ngoSnapshot.snapshot.value as Map<dynamic, dynamic>;
        result['ngoCount'] = ngosData.length;

        print('NGO Count: ${result['ngoCount']}');
        print('NGOs found:');

        ngosData.forEach((key, value) {
          final ngoData = value as Map<dynamic, dynamic>;
          final ngoName = ngoData['name'] as String;
          result['ngos'].add(ngoName);
          print('  - $ngoName');
        });
      } else {
        print('WARNING: No NGO node found in database!');
      }

      // Check database rules - FIXED
      print('Step 3: Checking database structure...');
      final allData = await _databaseRef.once();
      if (allData.snapshot.value != null) {
        final data = allData.snapshot.value as Map<dynamic, dynamic>;
        print('Root nodes: ${data.keys.join(', ')}');
      }

      print('=== END DATABASE CHECK ===');

    } catch (e) {
      print('ERROR during database check: $e');
      result['error'] = e.toString();
    }

    return result;
  }

  /// CRITICAL: Check verification requests for specific NGO
  static Future<Map<String, dynamic>> checkVerificationRequests(String ngoId) async {
    final result = <String, dynamic>{
      'totalRequests': 0,
      'matchingRequests': 0,
      'queryResults': 0,
      'requests': <Map<String, dynamic>>[],
      'ngoDetails': null,
      'issue': null,
      'solution': null,
    };

    try {
      print('\n' + '=' * 70);
      print('VERIFICATION REQUESTS DEBUG FOR NGO: $ngoId');
      print('=' * 70);

      // Step 1: Get NGO details - FIXED
      print('\n[INFO] STEP 1: Fetching NGO Details');
      print('-' * 70);
      final ngoSnapshot = await _databaseRef.child('ngos').child(ngoId).once();

      if (ngoSnapshot.snapshot.value != null) {
        final ngoData = Map<String, dynamic>.from(ngoSnapshot.snapshot.value as Map);
        result['ngoDetails'] = {
          'name': ngoData['name'],
          'pendingCount': ngoData['pendingCount'] ?? 0,
          'verifiedCount': ngoData['verifiedCount'] ?? 0,
        };
        print('[SUCCESS] NGO Found: ${ngoData['name']}');
        print('  Pending Count: ${ngoData['pendingCount'] ?? 0}');
        print('  Verified Count: ${ngoData['verifiedCount'] ?? 0}');
      } else {
        print('[ERROR] NGO NOT FOUND with ID: $ngoId');
        result['issue'] = 'NGO not found in database';
        return result;
      }

      // Step 2: Get ALL verification requests - FIXED
      print('\n[INFO] STEP 2: Fetching ALL Verification Requests');
      print('-' * 70);
      final allRequestsSnapshot = await _databaseRef.child('verification_requests').once();

      if (allRequestsSnapshot.snapshot.value == null) {
        print('[WARNING]  verification_requests node does NOT exist');
        print('   This means NO verification requests have been created yet.');
        result['issue'] = 'No verification requests in database';
        result['solution'] = 'Create a new acceptor account and upload CNIC to generate a request';
        return result;
      }

      final allRequestsMap = Map<String, dynamic>.from(allRequestsSnapshot.snapshot.value as Map);
      result['totalRequests'] = allRequestsMap.length;
      print('[SUCCESS] Total verification requests in database: ${allRequestsMap.length}');

      // Step 3: Analyze each request
      print('\n[INFO] STEP 3: Analyzing Each Request');
      print('-' * 70);

      int index = 1;
      allRequestsMap.forEach((key, value) {
        final requestData = Map<String, dynamic>.from(value as Map);

        print('\nRequest #$index:');
        print('  ID: ${requestData['id']}');
        print('  Acceptor: ${requestData['acceptorName']}');
        print('  Status: ${requestData['status']}');
        print('  AssignedNgoId: "${requestData['assignedNgoId']}"');
        print('  Your NGO ID: "$ngoId"');

        // Check if this matches our NGO
        final assignedNgoId = requestData['assignedNgoId']?.toString() ?? '';
        final status = requestData['status']?.toString() ?? '';

        if (assignedNgoId == ngoId) {
          print('  [SUCCESS] MATCH! This request IS assigned to your NGO');
          result['matchingRequests'] = (result['matchingRequests'] as int) + 1;

          if (status == 'Assigned' || status == 'Pending') {
            print('  [SUCCESS] Status is valid: $status');
            result['requests'].add({
              'id': requestData['id'],
              'acceptorName': requestData['acceptorName'],
              'status': status,
              'createdAt': requestData['createdAt'],
            });
          } else {
            print('  [ERROR] Status is invalid for display: $status (needs Assigned or Pending)');
          }
        } else {
          print('  [ERROR] No match - assigned to: "$assignedNgoId"');
          if (assignedNgoId.isEmpty) {
            print('     (assignedNgoId is empty/null)');
          }
        }

        index++;
      });

      // Step 4: Try Firebase Query - FIXED
      print('\n[INFO] STEP 4: Testing Firebase Query');
      print('-' * 70);
      print('Running: orderByChild("assignedNgoId").equalTo("$ngoId")');

      try {
        final querySnapshot = await _databaseRef
            .child('verification_requests')
            .orderByChild('assignedNgoId')
            .equalTo(ngoId)
            .once();

        if (querySnapshot.snapshot.value != null) {
          final queryResults = Map<String, dynamic>.from(querySnapshot.snapshot.value as Map);
          result['queryResults'] = queryResults.length;
          print('[SUCCESS] Query returned ${queryResults.length} results');
        } else {
          result['queryResults'] = 0;
          print('[ERROR] Query returned 0 results (snapshot.value = null)');
        }
      } catch (e) {
        print('[ERROR] Query FAILED with error: $e');
        result['issue'] = 'Query failed - likely missing Firebase index';
      }

      // Step 5: Diagnosis
      print('\n[INFO] STEP 5: Diagnosis');
      print('-' * 70);

      final matchingRequests = result['matchingRequests'] as int;
      final queryResults = result['queryResults'] as int;
      final pendingCount = (result['ngoDetails'] as Map)['pendingCount'] as int;

      if (matchingRequests == 0) {
        print('[ERROR] ISSUE: No requests assigned to your NGO');
        print('   Either:');
        print('   1. No acceptors have signed up yet');
        print('   2. Requests were assigned to other NGOs');
        result['issue'] = 'No requests assigned to this NGO';
        result['solution'] = 'Create a new acceptor account and upload CNIC';
      } else if (queryResults == 0 && matchingRequests > 0) {
        print('[ERROR] ISSUE: Requests exist but query returns nothing');
        print('   This is a FIREBASE INDEXING problem!');
        print('   Data is there, but query cannot find it.');
        result['issue'] = 'Firebase index missing for assignedNgoId';
        result['solution'] = 'Add Firebase index (see fix below)';
      } else if (pendingCount != matchingRequests) {
        print('[WARNING]  WARNING: Pending count mismatch');
        print('   Pending count: $pendingCount');
        print('   Actual requests: $matchingRequests');
        result['issue'] = 'Pending count out of sync';
      } else {
        print('[SUCCESS] Everything looks correct!');
        print('   Requests in DB: $matchingRequests');
        print('   Query results: $queryResults');
        print('   Pending count: $pendingCount');
      }

      // Step 6: Solution
      if (result['issue'] != null) {
        print('\n[INFO] STEP 6: Solution');
        print('-' * 70);

        if (result['issue'] == 'Firebase index missing for assignedNgoId') {
          print('Add this to Firebase Realtime Database Rules:');
          print('');
          print('{');
          print('  "rules": {');
          print('    "verification_requests": {');
          print('      ".indexOn": ["assignedNgoId", "acceptorId", "status"]');
          print('    }');
          print('  }');
          print('}');
          print('');
          print('Then wait 1-2 minutes for Firebase to build the index.');
        } else {
          print(result['solution']);
        }
      }

      print('\n' + '=' * 70);

    } catch (e, stackTrace) {
      print('[ERROR] ERROR during verification check: $e');
      print('Stack trace: $stackTrace');
      result['error'] = e.toString();
    }

    return result;
  }

  /// Force initialize NGO data
  static Future<bool> forceInitializeNGOs() async {
    try {
      print('=== FORCE INITIALIZE NGOs ===');

      // First, delete existing NGO data
      print('Step 1: Clearing existing NGO data...');
      await _databaseRef.child('ngos').remove();
      print('[SUCCESS] Cleared');

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize fresh data
      print('Step 2: Writing new NGO data...');
      final ngos = _getSampleNGOs();

      for (var ngo in ngos) {
        await _databaseRef.child('ngos').child(ngo['id']).set(ngo);
        print('  [SUCCESS] Added: ${ngo['name']}');
      }

      print('=== INITIALIZATION COMPLETE ===');
      print('Total NGOs added: ${ngos.length}');

      return true;
    } catch (e) {
      print('ERROR during force initialization: $e');
      return false;
    }
  }

  static List<Map<String, dynamic>> _getSampleNGOs() {
    return [
      {
        'id': 'ngo_001',
        'name': 'Al-Khidmat Foundation',
        'email': 'alkhidmat@example.com',
        'phone': '03001234567',
        'address': 'I-8 Markaz, Islamabad',
        'latitude': 33.6689,
        'longitude': 73.0765,
        'defaultPassword': 'alkhidmat123',
        'currentPassword': 'alkhidmat123',
        'isPasswordChanged': false,
        'createdAt': DateTime.now().toIso8601String(),
        'verifiedCount': 0,
        'pendingCount': 0,
      },
      {
        'id': 'ngo_002',
        'name': 'Edhi Foundation',
        'email': 'edhi@example.com',
        'phone': '03009876543',
        'address': 'Mithadar, Karachi',
        'latitude': 24.8607,
        'longitude': 67.0011,
        'defaultPassword': 'edhi123',
        'currentPassword': 'edhi123',
        'isPasswordChanged': false,
        'createdAt': DateTime.now().toIso8601String(),
        'verifiedCount': 0,
        'pendingCount': 0,
      },
      {
        'id': 'ngo_003',
        'name': 'Saylani Welfare Trust',
        'email': 'saylani@example.com',
        'phone': '03112233445',
        'address': 'Bahdurabad, Karachi',
        'latitude': 24.8800,
        'longitude': 67.0737,
        'defaultPassword': 'saylani123',
        'currentPassword': 'saylani123',
        'isPasswordChanged': false,
        'createdAt': DateTime.now().toIso8601String(),
        'verifiedCount': 0,
        'pendingCount': 0,
      },
      {
        'id': 'ngo_004',
        'name': 'JDC Foundation',
        'email': 'jdc@example.com',
        'phone': '03223344556',
        'address': 'Model Town, Lahore',
        'latitude': 31.4827,
        'longitude': 74.3172,
        'defaultPassword': 'jdc123',
        'currentPassword': 'jdc123',
        'isPasswordChanged': false,
        'createdAt': DateTime.now().toIso8601String(),
        'verifiedCount': 0,
        'pendingCount': 0,
      },
      {
        'id': 'ngo_005',
        'name': 'Pakistan Sweet Home',
        'email': 'sweethome@example.com',
        'phone': '03334455667',
        'address': 'Satellite Town, Rawalpindi',
        'latitude': 33.5651,
        'longitude': 73.0169,
        'defaultPassword': 'sweethome123',
        'currentPassword': 'sweethome123',
        'isPasswordChanged': false,
        'createdAt': DateTime.now().toIso8601String(),
        'verifiedCount': 0,
        'pendingCount': 0,
      },
    ];
  }

  /// Print comprehensive debug info
  static Future<void> printFullDebugInfo({String? ngoId}) async {
    print('\n' + '=' * 60);
    print('FIREBASE COMPREHENSIVE DEBUG INFO');
    print('=' * 60);

    // Check NGO database
    final ngoInfo = await checkNGODatabase();

    print('\n[INFO] CONNECTION STATUS: ${ngoInfo['connected'] ? "[SUCCESS] Connected" : "[ERROR] Not Connected"}');
    print('[INFO] NGO COUNT: ${ngoInfo['ngoCount']}');

    if (ngoInfo['error'] != null) {
      print('[ERROR] Error: ${ngoInfo['error']}');
    }

    if (ngoInfo['ngos'].isNotEmpty) {
      print('\n[INFO] NGOs in database:');
      for (var ngo in ngoInfo['ngos']) {
        print('  • $ngo');
      }
    } else {
      print('\n[WARNING]  WARNING: No NGOs found in database!');
      print('   Possible solutions:');
      print('   1. Check internet connection');
      print('   2. Run force initialization');
      print('   3. Check Firebase Console manually');
    }

    // If NGO ID provided, check verification requests
    if (ngoId != null && ngoId.isNotEmpty) {
      print('\n' + '=' * 60);
      final verificationInfo = await checkVerificationRequests(ngoId);

      if (verificationInfo['issue'] != null) {
        print('\n[ERROR] ISSUE DETECTED: ${verificationInfo['issue']}');
        if (verificationInfo['solution'] != null) {
          print('[INFO] SOLUTION: ${verificationInfo['solution']}');
        }
      }
    }

    print('\n' + '=' * 60 + '\n');
  }

  /// Quick check for NGO Dashboard - returns user-friendly message
  static Future<String> quickCheckForDashboard(String ngoId) async {
    try {
      final result = await checkVerificationRequests(ngoId);

      final totalRequests = result['totalRequests'] as int;
      final matchingRequests = result['matchingRequests'] as int;
      final queryResults = result['queryResults'] as int;

      if (totalRequests == 0) {
        return '[WARNING]  No verification requests in database yet.\nCreate an acceptor account to test.';
      }

      if (matchingRequests == 0) {
        return '[WARNING]  No requests assigned to your NGO yet.\nTotal requests in DB: $totalRequests';
      }

      if (queryResults == 0 && matchingRequests > 0) {
        return '[ERROR] FIREBASE INDEX MISSING!\n\nRequests exist ($matchingRequests) but query returns 0.\n\nFIX: Add Firebase index for "assignedNgoId"\nSee console logs for details.';
      }

      return '[SUCCESS] All checks passed!\nRequests found: $matchingRequests';

    } catch (e) {
      return '[ERROR] Debug check failed: $e';
    }
  }
}