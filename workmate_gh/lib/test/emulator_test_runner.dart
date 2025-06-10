import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'security_rules_tester.dart';

/// Test runner for Firebase Security Rules using Firebase Emulator
/// 
/// This script configures Firebase to use the local emulator and runs
/// comprehensive security rule tests to validate all access control scenarios.
class EmulatorTestRunner {
  static const String emulatorHost = '127.0.0.1';
  static const int firestorePort = 8080;
  static const int authPort = 9099;
  
  /// Initialize Firebase with emulator configuration
  static Future<void> initializeEmulator() async {
    debugPrint('🔧 Initializing Firebase Emulator...');
    
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: 'demo-app-id',
          messagingSenderId: 'demo-sender-id',
          projectId: 'workmate-gh-test',
        ),
      );
      
      // Configure Firestore to use emulator
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
      
      // Configure Auth to use emulator
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
      
      debugPrint('✅ Firebase Emulator initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase Emulator: $e');
      rethrow;
    }
  }
  
  /// Run security rules tests against the emulator
  static Future<void> runSecurityTests() async {
    debugPrint('\n🚀 Starting Security Rules Testing...\n');
    
    try {
      // Initialize emulator
      await initializeEmulator();
      
      // Wait a moment for emulator to be ready
      await Future.delayed(const Duration(seconds: 2));
      
      // Create and run security tester
      final tester = SecurityRulesTester();
      await tester.runAllTests();
      
      debugPrint('\n✅ Security Rules Testing Complete!\n');
      
    } catch (e) {
      debugPrint('\n❌ Security Rules Testing Failed: $e\n');
      rethrow;
    }
  }
}

/// Main function to run emulator tests
void main() async {
  await EmulatorTestRunner.runSecurityTests();
}
