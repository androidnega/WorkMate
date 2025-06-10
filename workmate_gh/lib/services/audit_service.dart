import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log an authentication event
  Future<void> logAuthEvent({
    required String eventType,
    required String userId,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    final timestamp = FieldValue.serverTimestamp();
    final currentUser = _auth.currentUser;

    await _db.collection('audit_trail').add({
      'type': eventType,
      'userId': userId,
      'description': description,
      'timestamp': timestamp,
      'performedBy': currentUser?.uid ?? 'system',
      'ipAddress': '', // Can be populated using Cloud Functions
      'userAgent': '', // Can be populated using Cloud Functions
      ...?additionalData,
    });
  }

  /// Log user creation
  Future<void> logUserCreation({
    required String userId,
    required String email,
    required String role,
    required String companyId,
    required String createdBy,
  }) async {
    await logAuthEvent(
      eventType: 'user_created',
      userId: userId,
      description: 'New user account created',
      additionalData: {
        'email': email,
        'role': role,
        'companyId': companyId,
        'createdBy': createdBy,
      },
    );
  }

  /// Log password reset request
  Future<void> logPasswordReset({required String email}) async {
    await logAuthEvent(
      eventType: 'password_reset_requested',
      userId: email, // Use email since we don't have userId during reset
      description: 'Password reset requested',
      additionalData: {'email': email},
    );
  }

  /// Log successful password change
  Future<void> logPasswordChange({
    required String userId,
    required bool isFirstLogin,
  }) async {
    await logAuthEvent(
      eventType:
          isFirstLogin ? 'first_login_password_change' : 'password_change',
      userId: userId,
      description:
          isFirstLogin
              ? 'Password changed on first login'
              : 'Password changed by user',
    );
  }

  /// Log failed login attempt
  Future<void> logFailedLogin({
    required String email,
    required String errorCode,
  }) async {
    await logAuthEvent(
      eventType: 'login_failed',
      userId: email, // Use email since login failed
      description: 'Failed login attempt',
      additionalData: {'email': email, 'errorCode': errorCode},
    );
  }

  /// Log successful login
  Future<void> logSuccessfulLogin({
    required String userId,
    required String email,
  }) async {
    await logAuthEvent(
      eventType: 'login_successful',
      userId: userId,
      description: 'Successful login',
      additionalData: {'email': email},
    );
  }
}
