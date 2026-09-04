import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'firebase_options.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("FLUTTER_DEBUG: Initializing Firebase...");
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Local emulators only when explicitly enabled (not on every debug run).
    // Run: flutter run --dart-define=USE_FIREBASE_EMULATOR=true
    // Optional host override: --dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x
    const useEmulator =
        bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
    if (kDebugMode && useEmulator) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2', // Android emulator → host machine
      );
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      debugPrint('FLUTTER_DEBUG: Using Firebase Emulator at $host');
    }

    debugPrint("FLUTTER_DEBUG: Firebase initialized successfully.");
  } catch (e) {
    debugPrint("FLUTTER_DEBUG: Firebase initialization failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}

