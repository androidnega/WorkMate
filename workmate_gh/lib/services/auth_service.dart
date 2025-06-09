import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      return user;
    } catch (e) {
      throw Exception('Failed to register admin: $e');
    }
  } // Create manager user (Admin only) - Better approach using direct Firestore

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
  }

  // Login user
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

      return user;
    } catch (e) {
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
    await _auth.signOut();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
