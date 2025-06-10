import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Simple test to diagnose Firestore connection issues
/// This will help identify the specific cause of the 400 error
class FirestoreConnectionTest {
  static Future<void> runDiagnosticTest() async {
    debugPrint('🔍 Starting Firestore Connection Diagnostic...\n');

    try {
      // Test 1: Check Firebase initialization
      debugPrint('1. Testing Firebase initialization...');
      final apps = Firebase.apps;
      if (apps.isNotEmpty) {
        debugPrint('✅ Firebase is initialized. App count: ${apps.length}');
        debugPrint('   Default app name: ${Firebase.app().name}');
        debugPrint('   Default app options: ${Firebase.app().options}');
      } else {
        debugPrint('❌ Firebase is not initialized');
        return;
      }

      // Test 2: Check Firebase Auth
      debugPrint('\n2. Testing Firebase Auth...');
      final auth = FirebaseAuth.instance;
      debugPrint('✅ Firebase Auth instance created');
      debugPrint('   Current user: ${auth.currentUser?.email ?? 'None'}');

      // Test 3: Check Firestore instance
      debugPrint('\n3. Testing Firestore instance...');
      final firestore = FirebaseFirestore.instance;
      debugPrint('✅ Firestore instance created');
      debugPrint('   App: ${firestore.app.name}');

      // Test 4: Test basic Firestore read operation
      debugPrint('\n4. Testing Firestore read operation...');
      try {
        // Try to read from a simple collection (this might trigger the error)
        final testCollection = firestore.collection('_test');
        final query = testCollection.limit(1);
        debugPrint('   Query created successfully');
        
        final snapshot = await query.get();
        debugPrint('✅ Firestore read successful!');
        debugPrint('   Documents returned: ${snapshot.docs.length}');
      } catch (e) {
        debugPrint('❌ Firestore read failed: $e');
        debugPrint('   Error type: ${e.runtimeType}');
        if (e.toString().contains('400')) {
          debugPrint('   This is likely the 400 error you\'re experiencing!');
        }
      }

      // Test 5: Test users collection specifically
      debugPrint('\n5. Testing users collection access...');
      try {
        final usersRef = firestore.collection('users');
        final usersSnapshot = await usersRef.limit(1).get();
        debugPrint('✅ Users collection accessible');
        debugPrint('   Documents in users: ${usersSnapshot.docs.length}');
      } catch (e) {
        debugPrint('❌ Users collection access failed: $e');
      }

      // Test 6: Test companies collection specifically
      debugPrint('\n6. Testing companies collection access...');
      try {
        final companiesRef = firestore.collection('companies');
        final companiesSnapshot = await companiesRef.limit(1).get();
        debugPrint('✅ Companies collection accessible');
        debugPrint('   Documents in companies: ${companiesSnapshot.docs.length}');
      } catch (e) {
        debugPrint('❌ Companies collection access failed: $e');
      }

      // Test 7: Check Firestore settings
      debugPrint('\n7. Testing Firestore settings...');
      try {
        final settings = firestore.settings;
        debugPrint('✅ Firestore settings accessible');
        debugPrint('   Host: ${settings.host}');
        debugPrint('   SSL enabled: ${settings.sslEnabled}');
        debugPrint('   Persistence enabled: ${settings.persistenceEnabled}');
      } catch (e) {
        debugPrint('❌ Firestore settings access failed: $e');
      }

      debugPrint('\n🎉 Diagnostic complete!');

    } catch (e) {
      debugPrint('❌ Fatal error during diagnostic: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Test with authentication
  static Future<void> testWithAuth() async {
    debugPrint('\n🔐 Testing with authentication...');
    
    try {
      final auth = FirebaseAuth.instance;
      
      // Try to get current user
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        debugPrint('✅ User is authenticated: ${currentUser.email}');
        
        // Test user-specific Firestore operations
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          debugPrint('✅ User document exists in Firestore');
          debugPrint('   User data: ${userDoc.data()}');
        } else {
          debugPrint('⚠️  User document does not exist in Firestore');
        }
      } else {
        debugPrint('⚠️  No user is currently authenticated');
      }
    } catch (e) {
      debugPrint('❌ Auth test failed: $e');
    }
  }

  /// Test network connectivity
  static Future<void> testNetworkConnectivity() async {
    debugPrint('\n🌐 Testing network connectivity...');
    
    try {
      // Enable network (in case it was disabled)
      await FirebaseFirestore.instance.enableNetwork();
      debugPrint('✅ Network enabled for Firestore');
      
      // Test a simple ping-like operation
      final firestore = FirebaseFirestore.instance;
      final testRef = firestore.collection('_connection_test').doc('ping');
      
      // Try to write a test document
      await testRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'test': true,
      });
      debugPrint('✅ Test write successful');
      
      // Try to read it back
      final doc = await testRef.get();
      if (doc.exists) {
        debugPrint('✅ Test read successful');
      }
      
      // Clean up
      await testRef.delete();
      debugPrint('✅ Test cleanup successful');
      
    } catch (e) {
      debugPrint('❌ Network connectivity test failed: $e');
      
      if (e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('   This suggests Firestore security rules may be blocking access');
      } else if (e.toString().contains('400')) {
        debugPrint('   This is the 400 error - likely a configuration issue');
      }
    }
  }
}

/// Main function to run all tests
Future<void> main() async {
  // Initialize Firebase if not already done
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAZUgDj3MVZnpVqOGcV45cnxWahBL0dioY",
        authDomain: "workmate-gh.firebaseapp.com",
        projectId: "workmate-gh",
        storageBucket: "workmate-gh.firebasestorage.app",
        messagingSenderId: "333207684567",
        appId: "1:333207684567:web:c04236d720a95da00e7792",
      ),
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    return;
  }

  // Run all diagnostic tests
  await FirestoreConnectionTest.runDiagnosticTest();
  await FirestoreConnectionTest.testWithAuth();
  await FirestoreConnectionTest.testNetworkConnectivity();
}
