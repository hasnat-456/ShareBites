import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/models/ngo_model.dart';

class NGODataInitializer {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  static DatabaseReference get _ngosRef => _databaseRef.child('ngos');


  static Future<void> initializeIfNeeded() async {
    try {
      print('[INFO] Checking NGO data...');


      final snapshot = await _ngosRef.limitToFirst(1).once();

      if (snapshot.snapshot.value == null) {
        print('[INFO] No NGOs found. Starting initialization...');
        await initializeSampleNGOs();
      } else {
        print('[SUCCESS] NGO data already exists');


        final allSnapshot = await _ngosRef.once();
        if (allSnapshot.snapshot.value != null) {
          final ngosMap = Map<String, dynamic>.from(allSnapshot.snapshot.value as Map);
          print('[INFO] Found ${ngosMap.length} NGOs in database');
        }
      }
    } catch (e) {
      print('[ERROR] Error in initializeIfNeeded: $e');
      print('[INFO] Attempting force initialization...');


      try {
        await initializeSampleNGOs();
      } catch (e2) {
        print('[ERROR] Force initialization also failed: $e2');
        rethrow;
      }
    }
  }

  static Future<void> initializeSampleNGOs() async {
    try {
      print('[INFO] Starting NGO initialization...');

      final sampleNGOs = [
        NGO(
          id: 'ngo_001',
          name: 'Al-Khidmat Foundation',
          email: 'alkhidmat@example.com',
          phone: '03001234567',
          address: 'I-8 Markaz, Islamabad',
          location: const LatLng(33.6689, 73.0765),
          defaultPassword: 'alkhidmat123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_002',
          name: 'Edhi Foundation',
          email: 'edhi@example.com',
          phone: '03009876543',
          address: 'Mithadar, Karachi',
          location: const LatLng(24.8607, 67.0011),
          defaultPassword: 'edhi123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_003',
          name: 'Saylani Welfare Trust',
          email: 'saylani@example.com',
          phone: '03112233445',
          address: 'Bahdurabad, Karachi',
          location: const LatLng(24.8800, 67.0737),
          defaultPassword: 'saylani123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_004',
          name: 'JDC Foundation',
          email: 'jdc@example.com',
          phone: '03223344556',
          address: 'Model Town, Lahore',
          location: const LatLng(31.4827, 74.3172),
          defaultPassword: 'jdc123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_005',
          name: 'Pakistan Sweet Home',
          email: 'sweethome@example.com',
          phone: '03334455667',
          address: 'Satellite Town, Rawalpindi',
          location: const LatLng(33.5651, 73.0169),
          defaultPassword: 'sweethome123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_006',
          name: 'Chhipa Welfare Association',
          email: 'chhipa@example.com',
          phone: '03445566778',
          address: 'Gulshan-e-Iqbal, Karachi',
          location: const LatLng(24.9181, 67.0828),
          defaultPassword: 'chhipa123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_007',
          name: 'The Citizens Foundation',
          email: 'tcf@example.com',
          phone: '03556677889',
          address: 'Clifton, Karachi',
          location: const LatLng(24.8138, 67.0272),
          defaultPassword: 'tcf123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_008',
          name: 'Akhuwat Foundation',
          email: 'akhuwat@example.com',
          phone: '03667788990',
          address: 'Township, Lahore',
          location: const LatLng(31.4678, 74.2931),
          defaultPassword: 'akhuwat123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_009',
          name: 'Transparent Hands',
          email: 'transparenthands@example.com',
          phone: '03778899001',
          address: 'F-7 Markaz, Islamabad',
          location: const LatLng(33.7181, 73.0776),
          defaultPassword: 'transparent123',
          createdAt: DateTime.now(),
        ),
        NGO(
          id: 'ngo_010',
          name: 'Dar-ul-Sukun',
          email: 'darulsukun@example.com',
          phone: '03889900112',
          address: 'PECHS, Karachi',
          location: const LatLng(24.8727, 67.0681),
          defaultPassword: 'darulsukun123',
          createdAt: DateTime.now(),
        ),
      ];

      print('[INFO] Preparing to add ${sampleNGOs.length} NGOs...');


      int successCount = 0;
      for (var ngo in sampleNGOs) {
        try {
          await _ngosRef.child(ngo.id).set(ngo.toJson());
          successCount++;
          print('[SUCCESS] Added: ${ngo.name}');
        } catch (e) {
          print('[ERROR] Failed to add ${ngo.name}: $e');
        }
      }

      print('');
      print('-' * 60);
      print('[SUCCESS] Successfully initialized $successCount/${sampleNGOs.length} NGOs');
      print('-' * 60);
      print('');
      print('[INFO] NGO Login Credentials:');
      print('-' * 60);
      for (var ngo in sampleNGOs) {
        print('NGO: ${ngo.name}');
        print('Password: ${ngo.defaultPassword}');
        print('-' * 60);
      }
      print('');

      if (successCount < sampleNGOs.length) {
        throw Exception('Only $successCount out of ${sampleNGOs.length} NGOs were added');
      }
    } catch (e) {
      print('[ERROR] Error initializing NGOs: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }


  static Future<int> countNGOs() async {
    try {
      final snapshot = await _ngosRef.once();
      if (snapshot.snapshot.value == null) return 0;

      final ngosMap = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return ngosMap.length;
    } catch (e) {
      print('Error counting NGOs: $e');
      return 0;
    }
  }


  static Future<void> deleteAllNGOs() async {
    try {
      await _ngosRef.remove();
      print('[SUCCESS] All NGOs deleted');
    } catch (e) {
      print('[ERROR] Error deleting NGOs: $e');
    }
  }
}