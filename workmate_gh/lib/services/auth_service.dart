import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'email_service.dart';
import 'audit_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();
  final AuditService _auditService = AuditService();

  // Register initial admin user (only for first setup)
  Future<AppUser?> registerAdminUser(
    String email,
    String password,
    String name,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = result.user!.uid;

      final user = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: UserRole.admin,
        companyId: 'admin', // Special companyId for admin users
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(uid).set(user.toMap());

      await _auditService.logUserCreation(
        userId: uid,
        email: email,
        role: UserRole.admin.name,
        companyId: 'admin',
        createdBy: uid, // Admin is self-created
      );

      return user;
    } catch (e) {
      throw Exception('Failed to register admin: $e');
    }
  }

  // Create manager user (Admin only) - Better approach using direct Firestore

  Future<AppUser?> createManagerUser({
    required String email,
    required String password,
    required String name,
    required String companyId,
    required String createdBy,
  }) async {
    try {
      // Create a temporary user account
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = result.user!.uid;

      final user = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: UserRole.manager,
        companyId: companyId,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      // Save user data to Firestore
      await _db.collection('users').doc(uid).set(user.toMap());

      // Important: Sign out the newly created user immediately
      // The admin will remain logged in through auth state persistence
      await _auth.signOut();

      return user;
    } catch (e) {
      throw Exception('Failed to create manager: $e');
    }
  } // Create worker user (Manager only) - Better approach using direct Firestore

  Future<AppUser?> createWorkerUser({
    required String email,
    required String password,
    required String name,
    required String companyId,
    required String createdBy,
  }) async {
    try {
      // Create a temporary user account
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = result.user!.uid;

      final user = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: UserRole.worker,
        companyId: companyId,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      // Save user data to Firestore
      await _db.collection('users').doc(uid).set(user.toMap());

      // Important: Sign out the newly created user immediately
      // The manager will remain logged in through auth state persistence
      await _auth.signOut();

      return user;
    } catch (e) {
      throw Exception('Failed to create worker: $e');
    }
  } // Login user

  Future<AppUser?> loginWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await _db.collection('users').doc(result.user!.uid).get();

      if (!doc.exists) {
        throw Exception('User data not found');
      }

      final user = AppUser.fromMap(doc.data()!, result.user!.uid);

      // Update last login time
      await _db.collection('users').doc(user.uid).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });

      await _auditService.logSuccessfulLogin(userId: user.uid, email: email);

      return user;
    } catch (e) {
      await _auditService.logFailedLogin(email: email, errorCode: e.toString());
      throw Exception('Login failed: $e');
    }
  }

  // Get current user
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return AppUser.fromMap(doc.data()!, user.uid);
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(AppUser user) async {
    try {
      await _db.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Deactivate user (Admin/Manager only)
  Future<void> deactivateUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'isActive': false});
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }

  // Get users by role and company
  Future<List<AppUser>> getUsersByRoleAndCompany(
    UserRole role,
    String companyId,
  ) async {
    try {
      final querySnapshot =
          await _db
              .collection('users')
              .where('role', isEqualTo: role.name)
              .where('companyId', isEqualTo: companyId)
              .where('isActive', isEqualTo: true)
              .get();

      return querySnapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _auditService.logAuthEvent(
        eventType: 'user_logout',
        userId: user.uid,
        description: 'User logged out',
      );
    }
    await _auth.signOut();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // Password reset functionality
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      await _emailService.sendPasswordResetEmail(email);
      await _auditService.logPasswordReset(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Change password for current user
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Get user document to check if this is first login
      final doc = await _db.collection('users').doc(user.uid).get();
      final isDefaultPassword = doc.data()?['isDefaultPassword'] ?? false;

      // Update isDefaultPassword flag in Firestore
      await _db.collection('users').doc(user.uid).update({
        'isDefaultPassword': false,
      });

      await _auditService.logPasswordChange(
        userId: user.uid,
        isFirstLogin: isDefaultPassword,
      );

      await _emailService.sendPasswordChangeConfirmation(user.email!);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  // Generate secure temporary password
  String generateSecurePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%';
    final random = DateTime.now().millisecondsSinceEpoch;
    String password = '';

    // Ensure password has required characters
    password += chars[random % 26]; // Uppercase
    password += chars[26 + (random % 26)]; // Lowercase
    password += chars[52 + (random % 10)]; // Number
    password += chars[62 + (random % 4)]; // Special char

    // Fill remaining length with random chars
    for (int i = password.length; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }

    return password;
  }

  // Create user with temporary password
  Future<String> createUserWithTempPassword({
    required String email,
    required String name,
    required UserRole role,
    required String companyId,
    required String createdBy,
  }) async {
    try {
      final tempPassword = generateSecurePassword();

      // Create user in Firebase Auth
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      final uid = result.user!.uid;

      // Create user document
      final user = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: role,
        companyId: companyId,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        isDefaultPassword: true,
      );

      await _db.collection('users').doc(uid).set(user.toMap());

      // Get company name for welcome email
      final companyDoc = await _db.collection('companies').doc(companyId).get();
      final companyName = companyDoc.data()?['name'] ?? 'WorkMate GH';

      // Send welcome email with temporary password
      await _emailService.sendWelcomeEmail(
        email: email,
        name: name,
        tempPassword: tempPassword,
        role: role,
        companyName: companyName,
      );

      // Log user creation
      await _auditService.logUserCreation(
        userId: uid,
        email: email,
        role: role.name,
        companyId: companyId,
        createdBy: createdBy,
      );

      // Sign out the newly created user
      await _auth.signOut();

      return tempPassword;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }
}
