import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';
import '../models/company.dart';
import '../services/time_tracking_service.dart';

/// Comprehensive Security Rules Tester for WorkMate GH
///
/// This class tests all Firebase Security Rules scenarios to ensure:
/// 1. Proper role-based access control
/// 2. Company-scoped data isolation
/// 3. Time entry validation and location requirements
/// 4. Admin, Manager, and Worker permission boundaries
class SecurityRulesTester {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Test accounts for different roles
  static const String testAdminEmail = 'test-admin@workmate.com';
  static const String testManagerEmail = 'test-manager@workmate.com';
  static const String testWorkerEmail = 'test-worker@workmate.com';
  static const String testWorker2Email =
      'test-worker2@workmate.com'; // Different company
  static const String testPassword = 'testpass123';

  // Test company IDs
  static const String testCompanyId1 = 'test-company-1';
  static const String testCompanyId2 = 'test-company-2';

  final List<String> _testResults = [];

  /// Run all security rule tests
  Future<void> runAllTests() async {
    debugPrint('🔐 Starting Firebase Security Rules Tests...\n');
    _testResults.clear();

    try {
      // Setup test data
      await _setupTestData();

      // Test admin permissions
      await _testAdminPermissions();

      // Test manager permissions
      await _testManagerPermissions();

      // Test worker permissions
      await _testWorkerPermissions();

      // Test cross-company isolation
      await _testCompanyIsolation();

      // Test time entry validation
      await _testTimeEntryValidation();

      // Print summary
      _printTestSummary();
    } catch (e) {
      _addResult('❌ Fatal error during security tests: $e');
    } finally {
      // Cleanup
      await _cleanupTestData();
    }
  }

  /// Setup test data for security rule testing
  Future<void> _setupTestData() async {
    _addResult('🏗️  Setting up test data...');

    try {
      // Create test admin
      await _createTestUser(
        email: testAdminEmail,
        password: testPassword,
        name: 'Test Admin',
        role: UserRole.admin,
        companyId: 'admin',
      );

      // Create test companies (as admin)
      await _authenticateAs(testAdminEmail);
      await _createTestCompany(testCompanyId1, 'Test Company 1');
      await _createTestCompany(testCompanyId2, 'Test Company 2');

      // Create test manager for company 1
      await _createTestUser(
        email: testManagerEmail,
        password: testPassword,
        name: 'Test Manager',
        role: UserRole.manager,
        companyId: testCompanyId1,
      );

      // Create test workers
      await _createTestUser(
        email: testWorkerEmail,
        password: testPassword,
        name: 'Test Worker 1',
        role: UserRole.worker,
        companyId: testCompanyId1,
      );

      await _createTestUser(
        email: testWorker2Email,
        password: testPassword,
        name: 'Test Worker 2',
        role: UserRole.worker,
        companyId: testCompanyId2,
      );

      _addResult('✅ Test data setup complete');
    } catch (e) {
      _addResult('❌ Failed to setup test data: $e');
      rethrow;
    }
  }

  /// Test admin-level permissions
  Future<void> _testAdminPermissions() async {
    _addResult('\n📋 Testing Admin Permissions...');

    await _authenticateAs(testAdminEmail);

    // Test: Admin can read all users
    await _testOperation('Admin reads all users', () async {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.isNotEmpty;
    });

    // Test: Admin can read all companies
    await _testOperation('Admin reads all companies', () async {
      final snapshot = await _firestore.collection('companies').get();
      return snapshot.docs.isNotEmpty;
    });

    // Test: Admin can create companies
    await _testOperation('Admin creates company', () async {
      await _firestore.collection('companies').add({
        'name': 'Admin Test Company',
        'address': '123 Test St',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'adminId': _auth.currentUser!.uid,
      });
      return true;
    });

    // Test: Admin can create manager accounts
    await _testOperation('Admin creates manager account', () async {
      final userId = 'test-manager-2';
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': 'test-manager-2@workmate.com',
        'name': 'Test Manager 2',
        'role': 'manager',
        'companyId': testCompanyId1,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'createdBy': _auth.currentUser!.uid,
      });
      return true;
    });

    // Test: Admin can read all time entries
    await _testOperation('Admin reads all time entries', () async {
      final snapshot = await _firestore.collection('time_entries').get();
      return true; // Should not throw even if empty
    });
  }

  /// Test manager-level permissions
  Future<void> _testManagerPermissions() async {
    _addResult('\n👔 Testing Manager Permissions...');

    await _authenticateAs(testManagerEmail);

    // Test: Manager can read their company
    await _testOperation('Manager reads own company', () async {
      final doc =
          await _firestore.collection('companies').doc(testCompanyId1).get();
      return doc.exists;
    });

    // Test: Manager cannot read other companies
    await _testOperation('Manager cannot read other companies', () async {
      try {
        await _firestore.collection('companies').doc(testCompanyId2).get();
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test: Manager can create worker accounts for their company
    await _testOperation('Manager creates worker for own company', () async {
      final userId = 'test-worker-manager-created';
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': 'manager-worker@workmate.com',
        'name': 'Manager Created Worker',
        'role': 'worker',
        'companyId': testCompanyId1,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'createdBy': _auth.currentUser!.uid,
      });
      return true;
    });

    // Test: Manager cannot create workers for other companies
    await _testOperation(
      'Manager cannot create worker for other company',
      () async {
        try {
          final userId = 'test-invalid-worker';
          await _firestore.collection('users').doc(userId).set({
            'uid': userId,
            'email': 'invalid-worker@workmate.com',
            'name': 'Invalid Worker',
            'role': 'worker',
            'companyId': testCompanyId2, // Different company!
            'createdAt': DateTime.now().toIso8601String(),
            'isActive': true,
            'createdBy': _auth.currentUser!.uid,
          });
          return false; // Should fail
        } catch (e) {
          return e.toString().contains('PERMISSION_DENIED');
        }
      },
    );

    // Test: Manager cannot create admin or manager accounts
    await _testOperation('Manager cannot create admin accounts', () async {
      try {
        final userId = 'test-invalid-admin';
        await _firestore.collection('users').doc(userId).set({
          'uid': userId,
          'email': 'invalid-admin@workmate.com',
          'name': 'Invalid Admin',
          'role': 'admin',
          'companyId': 'admin',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
          'createdBy': _auth.currentUser!.uid,
        });
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });
  }

  /// Test worker-level permissions
  Future<void> _testWorkerPermissions() async {
    _addResult('\n👷 Testing Worker Permissions...');

    await _authenticateAs(testWorkerEmail);

    // Test: Worker can read their own user data
    await _testOperation('Worker reads own user data', () async {
      final doc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();
      return doc.exists;
    });

    // Test: Worker can read their company
    await _testOperation('Worker reads own company', () async {
      final doc =
          await _firestore.collection('companies').doc(testCompanyId1).get();
      return doc.exists;
    });

    // Test: Worker cannot read other users
    await _testOperation('Worker cannot read other users', () async {
      try {
        final snapshot = await _firestore.collection('users').get();
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test: Worker cannot create user accounts
    await _testOperation('Worker cannot create user accounts', () async {
      try {
        await _firestore.collection('users').add({
          'email': 'worker-created@workmate.com',
          'name': 'Worker Created User',
          'role': 'worker',
        });
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test: Worker cannot create companies
    await _testOperation('Worker cannot create companies', () async {
      try {
        await _firestore.collection('companies').add({
          'name': 'Worker Company',
          'address': '456 Worker St',
        });
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });
  }

  /// Test company data isolation
  Future<void> _testCompanyIsolation() async {
    _addResult('\n🏢 Testing Company Data Isolation...');

    // Test as worker from company 1
    await _authenticateAs(testWorkerEmail);

    await _testOperation('Worker cannot access other company data', () async {
      try {
        final doc =
            await _firestore.collection('companies').doc(testCompanyId2).get();
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test as manager from company 1
    await _authenticateAs(testManagerEmail);

    await _testOperation(
      'Manager cannot read workers from other companies',
      () async {
        try {
          // Try to read all users (should be restricted to own company)
          final snapshot =
              await _firestore
                  .collection('users')
                  .where('companyId', isEqualTo: testCompanyId2)
                  .get();
          return snapshot.docs.isEmpty; // Should be empty due to rules
        } catch (e) {
          return e.toString().contains('PERMISSION_DENIED');
        }
      },
    );
  }

  /// Test time entry validation and location requirements
  Future<void> _testTimeEntryValidation() async {
    _addResult('\n⏰ Testing Time Entry Validation...');

    await _authenticateAs(testWorkerEmail);

    // Test: Valid clock-in with location
    await _testOperation('Valid clock-in with location', () async {
      await _firestore.collection('time_entries').add({
        'userId': _auth.currentUser!.uid,
        'companyId': testCompanyId1,
        'timestamp': Timestamp.now(),
        'type': 'clockIn',
        'location': {'lat': 5.6037, 'lng': -0.1870},
      });
      return true;
    });

    // Test: Clock-in without location should fail
    await _testOperation('Clock-in without location fails', () async {
      try {
        await _firestore.collection('time_entries').add({
          'userId': _auth.currentUser!.uid,
          'companyId': testCompanyId1,
          'timestamp': Timestamp.now(),
          'type': 'clockIn',
          // No location provided
        });
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test: Valid clock-out without location
    await _testOperation('Valid clock-out without location', () async {
      await _firestore.collection('time_entries').add({
        'userId': _auth.currentUser!.uid,
        'companyId': testCompanyId1,
        'timestamp': Timestamp.now(),
        'type': 'clockOut',
      });
      return true;
    });

    // Test: Invalid location coordinates
    await _testOperation('Invalid location coordinates fail', () async {
      try {
        await _firestore.collection('time_entries').add({
          'userId': _auth.currentUser!.uid,
          'companyId': testCompanyId1,
          'timestamp': Timestamp.now(),
          'type': 'clockIn',
          'location': {
            'lat': 999, // Invalid latitude
            'lng': -0.1870,
          },
        });
        return false; // Should fail
      } catch (e) {
        return e.toString().contains('PERMISSION_DENIED');
      }
    });

    // Test: Worker cannot create time entries for other users
    await _testOperation(
      'Worker cannot create time entries for others',
      () async {
        try {
          await _firestore.collection('time_entries').add({
            'userId': 'other-user-id',
            'companyId': testCompanyId1,
            'timestamp': Timestamp.now(),
            'type': 'clockIn',
            'location': {'lat': 5.6037, 'lng': -0.1870},
          });
          return false; // Should fail
        } catch (e) {
          return e.toString().contains('PERMISSION_DENIED');
        }
      },
    );

    // Test: Worker cannot create time entries for other companies
    await _testOperation(
      'Worker cannot create time entries for other companies',
      () async {
        try {
          await _firestore.collection('time_entries').add({
            'userId': _auth.currentUser!.uid,
            'companyId': testCompanyId2, // Different company
            'timestamp': Timestamp.now(),
            'type': 'clockIn',
            'location': {'lat': 5.6037, 'lng': -0.1870},
          });
          return false; // Should fail
        } catch (e) {
          return e.toString().contains('PERMISSION_DENIED');
        }
      },
    );
  }

  /// Test a specific operation and record the result
  Future<void> _testOperation(
    String testName,
    Future<bool> Function() operation,
  ) async {
    try {
      final result = await operation();
      if (result) {
        _addResult('✅ $testName');
      } else {
        _addResult('❌ $testName');
      }
    } catch (e) {
      _addResult('❌ $testName - Error: $e');
    }
  }

  /// Authenticate as a specific test user
  Future<void> _authenticateAs(String email) async {
    try {
      await _auth.signOut();
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: testPassword,
      );
    } catch (e) {
      // User might not exist, try to create
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: testPassword,
      );
    }
  }

  /// Create a test user account
  Future<void> _createTestUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String companyId,
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'name': name,
        'role': role.name,
        'companyId': companyId,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'createdBy': role == UserRole.admin ? null : _auth.currentUser?.uid,
      });

      // Sign out after creating
      await _auth.signOut();
    } catch (e) {
      if (!e.toString().contains('email-already-in-use')) {
        rethrow;
      }
    }
  }

  /// Create a test company
  Future<void> _createTestCompany(String companyId, String name) async {
    try {
      await _firestore.collection('companies').doc(companyId).set({
        'name': name,
        'address': '123 Test Street, Test City',
        'phone': '+233123456789',
        'email': 'contact@$companyId.com',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'adminId': _auth.currentUser!.uid,
      });
    } catch (e) {
      // Company might already exist
      debugPrint('Company creation failed (might already exist): $e');
    }
  }

  /// Clean up test data
  Future<void> _cleanupTestData() async {
    _addResult('\n🧹 Cleaning up test data...');

    try {
      // Authenticate as admin for cleanup
      await _authenticateAs(testAdminEmail);

      // Delete test documents
      final batch = _firestore.batch();

      // Delete test users
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where(
                'email',
                whereIn: [
                  testAdminEmail,
                  testManagerEmail,
                  testWorkerEmail,
                  testWorker2Email,
                  'test-manager-2@workmate.com',
                  'manager-worker@workmate.com',
                ],
              )
              .get();

      for (final doc in usersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete test companies
      batch.delete(_firestore.collection('companies').doc(testCompanyId1));
      batch.delete(_firestore.collection('companies').doc(testCompanyId2));

      // Delete test time entries
      final timeEntriesSnapshot =
          await _firestore
              .collection('time_entries')
              .where('companyId', whereIn: [testCompanyId1, testCompanyId2])
              .get();

      for (final doc in timeEntriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      _addResult('✅ Test data cleanup complete');
    } catch (e) {
      _addResult('⚠️ Cleanup had issues (this is normal): $e');
    }
  }

  /// Add a test result to the results list
  void _addResult(String result) {
    _testResults.add(result);
    debugPrint(result);
  }

  /// Print test summary
  void _printTestSummary() {
    final passed = _testResults.where((r) => r.startsWith('✅')).length;
    final failed = _testResults.where((r) => r.startsWith('❌')).length;
    final total = passed + failed;

    debugPrint('\n📊 Security Rules Test Summary:');
    debugPrint('Total Tests: $total');
    debugPrint('Passed: $passed ✅');
    debugPrint('Failed: $failed ❌');
    debugPrint(
      'Success Rate: ${total > 0 ? ((passed / total) * 100).toStringAsFixed(1) : 0}%',
    );

    if (failed == 0) {
      debugPrint(
        '\n🎉 All security rule tests passed! Your rules are properly configured.',
      );
    } else {
      debugPrint(
        '\n⚠️ Some tests failed. Please review your Firestore Security Rules.',
      );
    }
  }

  /// Get test results for external consumption
  List<String> getTestResults() => List.from(_testResults);
}

/// Simple test runner function
Future<void> runSecurityRulesTests() async {
  final tester = SecurityRulesTester();
  await tester.runAllTests();
}
