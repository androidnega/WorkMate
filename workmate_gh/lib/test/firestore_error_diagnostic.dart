import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore 400 Error Diagnostic Tool
/// This will help identify the specific cause of the 400 status error
class FirestoreErrorDiagnostic extends StatefulWidget {
  const FirestoreErrorDiagnostic({super.key});

  @override
  State<FirestoreErrorDiagnostic> createState() =>
      _FirestoreErrorDiagnosticState();
}

class _FirestoreErrorDiagnosticState extends State<FirestoreErrorDiagnostic> {
  final List<String> _diagnosticResults = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Error Diagnostic'),
        backgroundColor: Colors.red.shade500,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Firestore 400 Error Diagnostic',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool will help identify why you\'re getting 400 status errors '
                      'when trying to connect to Firestore. Common causes include:\n'
                      '• Incorrect project configuration\n'
                      '• Security rules blocking access\n'
                      '• Network connectivity issues\n'
                      '• Invalid API keys or permissions',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runDiagnostic,
              icon:
                  _isRunning
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.play_arrow),
              label: Text(
                _isRunning ? 'Running Diagnostic...' : 'Run Diagnostic',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Diagnostic Results:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child:
                            _diagnosticResults.isEmpty
                                ? const Center(
                                  child: Text(
                                    'Click "Run Diagnostic" to check for issues',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _diagnosticResults.length,
                                  itemBuilder: (context, index) {
                                    final result = _diagnosticResults[index];
                                    final isError = result.startsWith('❌');
                                    final isWarning = result.startsWith('⚠️');
                                    final isSuccess = result.startsWith('✅');

                                    Color? color;
                                    if (isError) color = Colors.red.shade700;
                                    if (isWarning) {
                                      color = Colors.orange.shade700;
                                    }
                                    if (isSuccess) {
                                      color = Colors.green.shade700;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        result,
                                        style: TextStyle(
                                          color: color,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _diagnosticResults.clear();
    });

    _addResult('🔍 Starting Firestore Connection Diagnostic...\n');

    try {
      // Test 1: Firebase App Status
      _addResult('1. Checking Firebase App Status...');
      final apps = Firebase.apps;
      if (apps.isNotEmpty) {
        _addResult('✅ Firebase is initialized (${apps.length} app(s))');
        _addResult('   Default app: ${Firebase.app().name}');
        _addResult('   Project ID: ${Firebase.app().options.projectId}');
      } else {
        _addResult('❌ Firebase is not initialized!');
        _addResult('   This is likely the source of your 400 error.');
        return;
      }

      // Test 2: Firestore Instance
      _addResult('\n2. Creating Firestore Instance...');
      final firestore = FirebaseFirestore.instance;
      _addResult('✅ Firestore instance created');

      // Test 3: Basic Read Test (this often triggers the 400 error)
      _addResult('\n3. Testing Basic Firestore Read...');
      try {
        final testQuery = firestore.collection('_diagnostic_test').limit(1);
        _addResult('   Query created successfully');

        final snapshot = await testQuery.get();
        _addResult('✅ Basic read successful! Docs: ${snapshot.docs.length}');
      } catch (e) {
        _addResult('❌ Basic read failed: $e');
        _addResult('   Error type: ${e.runtimeType}');

        if (e.toString().contains('400')) {
          _addResult('   🎯 This is your 400 error!');
          _analyzeFirestoreError(e);
        }
      }

      // Test 4: Authentication Status
      _addResult('\n4. Checking Authentication Status...');
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        _addResult('✅ User authenticated: ${currentUser.email}');
        _addResult('   UID: ${currentUser.uid}');
      } else {
        _addResult('⚠️ No user authenticated');
        _addResult(
          '   This might affect Firestore access if security rules require auth',
        );
      }

      // Test 5: Test User Collection Access
      _addResult('\n5. Testing User Collection Access...');
      try {
        final usersRef = firestore.collection('users');
        final usersSnapshot = await usersRef.limit(1).get();
        _addResult(
          '✅ Users collection accessible (${usersSnapshot.docs.length} docs)',
        );
      } catch (e) {
        _addResult('❌ Users collection failed: $e');
        if (e.toString().contains('PERMISSION_DENIED')) {
          _addResult('   Cause: Security rules are blocking access');
        }
      }

      // Test 6: Test Companies Collection Access
      _addResult('\n6. Testing Companies Collection Access...');
      try {
        final companiesRef = firestore.collection('companies');
        final companiesSnapshot = await companiesRef.limit(1).get();
        _addResult(
          '✅ Companies collection accessible (${companiesSnapshot.docs.length} docs)',
        );
      } catch (e) {
        _addResult('❌ Companies collection failed: $e');
        if (e.toString().contains('PERMISSION_DENIED')) {
          _addResult('   Cause: Security rules are blocking access');
        }
      }

      // Test 7: Network and Settings
      _addResult('\n7. Checking Firestore Settings...');
      try {
        final settings = firestore.settings;
        _addResult('✅ Settings accessible');
        _addResult('   Host: ${settings.host}');
        _addResult('   SSL: ${settings.sslEnabled}');
        _addResult('   Persistence: ${settings.persistenceEnabled}');
      } catch (e) {
        _addResult('❌ Settings access failed: $e');
      }

      // Test 8: Write Test (if user is authenticated)
      if (currentUser != null) {
        _addResult('\n8. Testing Write Operation...');
        try {
          final testRef = firestore.collection('_diagnostic_test').doc('test');
          await testRef.set({
            'timestamp': DateTime.now().toIso8601String(),
            'user': currentUser.uid,
            'test': true,
          });
          _addResult('✅ Write operation successful');

          // Clean up
          await testRef.delete();
          _addResult('✅ Cleanup successful');
        } catch (e) {
          _addResult('❌ Write operation failed: $e');
          if (e.toString().contains('PERMISSION_DENIED')) {
            _addResult('   Cause: Security rules are blocking writes');
          }
        }
      }

      _addResult('\n🎉 Diagnostic Complete!');
      _addResult('\n📋 Summary:');
      final errors = _diagnosticResults.where((r) => r.contains('❌')).length;
      final warnings = _diagnosticResults.where((r) => r.contains('⚠️')).length;

      if (errors > 0) {
        _addResult('❌ Found $errors error(s) - these need to be fixed');
      }
      if (warnings > 0) {
        _addResult(
          '⚠️ Found $warnings warning(s) - check these for potential issues',
        );
      }
      if (errors == 0 && warnings == 0) {
        _addResult('✅ No issues found - Firestore should be working correctly');
      }
    } catch (e) {
      _addResult('❌ Fatal diagnostic error: $e');
      _addResult('   Stack trace: ${StackTrace.current}');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _analyzeFirestoreError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    _addResult('\n🔍 Analyzing 400 Error:');

    if (errorString.contains('invalid api key') ||
        errorString.contains('api key')) {
      _addResult('   Likely cause: Invalid or missing API key');
      _addResult('   Solution: Check your Firebase configuration');
    } else if (errorString.contains('project not found') ||
        errorString.contains('project')) {
      _addResult('   Likely cause: Project ID mismatch');
      _addResult('   Solution: Verify your Firebase project ID');
    } else if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      _addResult('   Likely cause: Firestore security rules');
      _addResult('   Solution: Update security rules or authenticate user');
    } else if (errorString.contains('quota') ||
        errorString.contains('billing')) {
      _addResult('   Likely cause: Billing or quota issues');
      _addResult('   Solution: Check Firebase console for billing status');
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      _addResult('   Likely cause: Network connectivity issues');
      _addResult('   Solution: Check internet connection and firewall');
    } else {
      _addResult('   Cause: Unknown - check full error message above');
      _addResult('   Solution: Check Firebase console and documentation');
    }
  }

  void _addResult(String result) {
    setState(() {
      _diagnosticResults.add(result);
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If we had a scroll controller, we would scroll here
      print(result); // Also print to console for debugging
    });
  }
}

// Simple launcher widget
class FirestoreDiagnosticApp extends StatelessWidget {
  const FirestoreDiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore Diagnostic',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const FirestoreErrorDiagnostic(),
      debugShowCheckedModeBanner: false,
    );
  }
}
