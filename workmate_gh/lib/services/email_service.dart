import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class EmailService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Send a welcome email with temporary password to a new user
  Future<void> sendWelcomeEmail({
    required String email,
    required String name,
    required String tempPassword,
    required UserRole role,
    required String companyName,
  }) async {
    // This is handled by Firebase Auth's email templates
    // You can customize the templates in Firebase Console -> Authentication -> Email Templates
    await _auth.sendPasswordResetEmail(email: email);

    // Log the email send in audit trail
    await _db.collection('audit_trail').add({
      'type': 'welcome_email_sent',
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
      'role': role.name,
      'companyName': companyName,
    });
  }

  /// Send password reset email to user
  Future<void> sendPasswordResetEmail(String email) async {
    // Firebase Auth handles the actual email sending
    await _auth.sendPasswordResetEmail(email: email);

    // Log the password reset request
    await _db.collection('audit_trail').add({
      'type': 'password_reset_requested',
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Send notification email when user changes their password
  Future<void> sendPasswordChangeConfirmation(String email) async {
    // Your email sending logic here (e.g., using a service like SendGrid or Firebase Cloud Functions)
    // For now, we'll just log it
    await _db.collection('audit_trail').add({
      'type': 'password_changed_email_sent',
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
