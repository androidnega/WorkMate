import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Test the complete authentication flow including:
/// - Password reset functionality
/// - First-login password change requirement
/// - Secure temporary password generation
/// - User creation process
void main() {
  group('Authentication Flow Tests', () {
    late AuthService authService;
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      authService = AuthService();
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;
    });

    tearDown(() async {
      await auth.signOut();
    });

    test('First login requires password change', () async {
      // Create a test user with default password
      final tempPassword = await authService.createUserWithTempPassword(
        email: 'test-first-login@workmate.com',
        name: 'Test User',
        role: UserRole.worker,
        companyId: 'test-company',
        createdBy: 'test-admin',
      );

      // Try to login
      final user = await authService.loginWithEmail(
        'test-first-login@workmate.com',
        tempPassword,
      );

      expect(user, isNotNull);
      expect(user!.isDefaultPassword, isTrue);
    });

    test('Password reset functionality works', () async {
      // Try to send password reset email
      await authService.sendPasswordReset('test-reset@workmate.com');
      // Note: We can't actually test the email receipt in unit tests
    });

    test('Temporary password is secure', () {
      final tempPassword = authService.generateSecurePassword();
      // Password should meet all requirements
      expect(tempPassword.length, greaterThanOrEqualTo(12));
      expect(tempPassword.contains(RegExp(r'[A-Z]')), isTrue);
      expect(tempPassword.contains(RegExp(r'[a-z]')), isTrue);
      expect(tempPassword.contains(RegExp(r'[0-9]')), isTrue);
      expect(tempPassword.contains(RegExp(r'[!@#%]')), isTrue);
    });

    test('Password change updates isDefaultPassword flag', () async {
      // Create test user
      final tempPassword = await authService.createUserWithTempPassword(
        email: 'test-password-change@workmate.com',
        name: 'Test User',
        role: UserRole.worker,
        companyId: 'test-company',
        createdBy: 'test-admin',
      );

      // Login
      await authService.loginWithEmail(
        'test-password-change@workmate.com',
        tempPassword,
      );

      // Change password
      await authService.changePassword(tempPassword, 'NewSecurePass123!');

      // Verify isDefaultPassword is now false
      final userDoc =
          await firestore.collection('users').doc(auth.currentUser!.uid).get();
      expect(userDoc.data()?['isDefaultPassword'], isFalse);
    });
  });
}
