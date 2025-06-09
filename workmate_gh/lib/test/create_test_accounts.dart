import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../models/app_user.dart';

/// Test script to create test accounts
/// Run this file to create test accounts for the app
///
/// Test Accounts Created:
/// 1. Admin: admin@workmate.com / admin123
/// 2. Manager: manager@workmate.com / manager123
/// 3. Worker: worker@workmate.com / worker123
class TestAccountCreator {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createTestAccounts() async {
    debugPrint('🚀 Creating test accounts...');
    try {
      // Create Admin Account
      await _createTestUser(
        email: 'admin@workmate.com',
        password: 'admin123',
        name: 'Test Admin',
        role: UserRole.admin,
        companyId: 'admin',
        isDefaultPassword: false, // Admin doesn't need password change
      );
      debugPrint('✅ Admin account created: admin@workmate.com / admin123');

      // Create Manager Account
      await _createTestUser(
        email: 'manager@workmate.com',
        password: 'manager123',
        name: 'Test Manager',
        role: UserRole.manager,
        companyId: 'test-company-1',
        isDefaultPassword: false, // Manager doesn't need password change
      );
      debugPrint(
        '✅ Manager account created: manager@workmate.com / manager123',
      );

      // Create Worker Account with default password (will trigger change dialog)
      await _createTestUser(
        email: 'worker@workmate.com',
        password: 'worker123',
        name: 'Test Worker',
        role: UserRole.worker,
        companyId: 'test-company-1',
        isDefaultPassword: true, // Worker will be prompted to change password
      );
      debugPrint('✅ Worker account created: worker@workmate.com / worker123');
      debugPrint('   📝 Worker will be prompted to change password on login');

      debugPrint('\n🎉 All test accounts created successfully!');
      debugPrint('\n📋 Login Credentials:');
      debugPrint('   Admin:   admin@workmate.com / admin123');
      debugPrint('   Manager: manager@workmate.com / manager123');
      debugPrint('   Worker:  worker@workmate.com / worker123');
      debugPrint(
        '\n⚠️  Worker will be prompted to change password on first login',
      );
    } catch (e) {
      debugPrint('❌ Error creating test accounts: $e');
    }
  }

  Future<void> _createTestUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String companyId,
    required bool isDefaultPassword,
  }) async {
    try {
      // Check if user already exists
      final existingDoc =
          await _db.collection('users').where('email', isEqualTo: email).get();
      if (existingDoc.docs.isNotEmpty) {
        debugPrint('⚠️  User $email already exists, skipping...');
        return;
      }

      // Create Firebase Auth user
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = result.user!.uid;

      // Create user document in Firestore
      final user = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: role,
        companyId: companyId,
        createdAt: DateTime.now(),
        isActive: true,
        isDefaultPassword: isDefaultPassword,
        createdBy: role == UserRole.admin ? null : 'test-admin-uid',
      );

      await _db
          .collection('users')
          .doc(uid)
          .set(user.toMap()); // Sign out after creating each user
      await _auth.signOut();
    } catch (e) {
      debugPrint('❌ Failed to create user $email: $e');
    }
  }

  /// Clean up test accounts (optional)
  Future<void> deleteTestAccounts() async {
    debugPrint('🧹 Cleaning up test accounts...');

    final testEmails = [
      'admin@workmate.com',
      'manager@workmate.com',
      'worker@workmate.com',
    ];

    for (final email in testEmails) {
      try {
        // Find user document
        final querySnapshot =
            await _db
                .collection('users')
                .where('email', isEqualTo: email)
                .get();

        for (final doc in querySnapshot.docs) {
          await doc.reference.delete();
          debugPrint('✅ Deleted Firestore document for $email');
        }
      } catch (e) {
        debugPrint('❌ Error deleting $email: $e');
      }
    }

    debugPrint(
      '⚠️  Note: Firebase Auth users need to be deleted manually from Firebase Console',
    );
  }
}

// Main function to run the test account creator
Future<void> main() async {
  // Initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
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

  final creator = TestAccountCreator();

  // Create test accounts
  await creator.createTestAccounts();

  // Uncomment the line below if you want to clean up accounts
  // await creator.deleteTestAccounts();
}
