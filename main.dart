import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'overall_files/firebase_options.dart';
import 'overall_files/splash_screen.dart';
import 'overall_files/user_type_selection.dart';
import 'overall_files/auth_selector.dart';
import 'overall_files/auth_form.dart';
import 'donor/dashboard.dart';
import 'acceptor/acceptor_dashboard.dart';
import 'verifier/ngo_login.dart';
import 'verifier/ngo_dashboard.dart';
import 'verifier/ngo_data_initializer.dart';
import 'notifications/supabase_notification_service.dart';
import 'notifications/notification_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);


  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[SUCCESS] Firebase initialized');
  } catch (e) {
    print('[ERROR] Firebase initialization failed: $e');

    runApp(ErrorApp(error: 'Firebase initialization failed: $e'));
    return;
  }


  try {
    await NGODataInitializer.initializeIfNeeded();
    print('[SUCCESS] NGO data initialization completed');
  } catch (e) {
    print('[WARNING]  Warning: NGO data initialization failed: $e');

  }



  _initializeNotificationsInBackground();

  runApp(const ShareBitesApp());
}


void _initializeNotificationsInBackground() {
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      print('[INFO] Starting notification service initialization...');
      await SupabaseNotificationService().initialize();
      print('[SUCCESS] Supabase notification service initialized');
    } catch (e) {
      print('[WARNING]  Warning: Notification service initialization failed: $e');
      print('[WARNING]  App will continue without notifications');

    }
  });
}

class ShareBitesApp extends StatefulWidget {
  const ShareBitesApp({super.key});

  @override
  State<ShareBitesApp> createState() => _ShareBitesAppState();
}

class _ShareBitesAppState extends State<ShareBitesApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ShareBites',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/user-type': (context) => const UserTypeSelection(),
        '/auth-selector': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
          return AuthSelector(userType: args?['userType'] ?? 'Donor');
        },
        '/auth-form': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
          return AuthForm(
            action: args?['action'] ?? 'Log In',
            userType: args?['userType'] ?? 'Donor',
          );
        },
        '/donor-dashboard': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final user = args?['user'];
          if (user == null) {
            return const SplashScreen();
          }
          return Dashboard(user: user);
        },
        '/acceptor-dashboard': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final user = args?['user'];
          if (user == null) {
            return const SplashScreen();
          }
          return AcceptorDashboard(user: user);
        },
        '/ngo-login': (context) => const NGOLogin(),
        '/ngo-dashboard': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final ngo = args?['ngo'];
          if (ngo == null) {
            return const NGOLogin();
          }
          return NGODashboard(ngo: ngo);
        },
        '/notifications': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
          return NotificationsPage(
            userId: args?['userId'] ?? '',
            userType: args?['userType'] ?? '',
          );
        },
      },
      onGenerateRoute: (settings) {
        print('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Route ${settings.name} not found'),
            ),
          ),
        );
      },
    );
  }
}


class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Please check your internet connection and restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}