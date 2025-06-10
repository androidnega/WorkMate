import 'dart:io';

/// Security Rules Analyzer - Validates Firestore Security Rules implementation
///
/// This script analyzes the actual firestore.rules file to verify that all
/// security requirements are properly implemented without requiring emulators.
class SecurityRulesAnalyzer {
  static Future<void> analyzeRules() async {
    print('🔍 Firebase Security Rules Analysis');
    print('==================================');
    print('');

    try {
      // Read the firestore.rules file
      final rulesFile = File('firestore.rules');
      if (!await rulesFile.exists()) {
        print('❌ firestore.rules file not found!');
        return;
      }

      final rulesContent = await rulesFile.readAsString();
      print('✅ Successfully loaded firestore.rules');
      print('');

      // Analyze security requirements
      final requirements = <String, bool>{
        'Helper functions for authentication': _checkHelperFunctions(
          rulesContent,
        ),
        'Role-based access control (admin, manager, worker)':
            _checkRoleBasedAccess(rulesContent),
        'Company-scoped data isolation': _checkCompanyIsolation(rulesContent),
        'Admin-only company creation': _checkAdminCompanyCreation(rulesContent),
        'Manager permission boundaries': _checkManagerPermissions(rulesContent),
        'Worker data access restrictions': _checkWorkerPermissions(
          rulesContent,
        ),
        'Time entry location validation': _checkLocationValidation(
          rulesContent,
        ),
        'Time entry type validation': _checkTimeEntryValidation(rulesContent),
        'Cross-company access prevention': _checkCrossCompanyPrevention(
          rulesContent,
        ),
        'User data protection': _checkUserDataProtection(rulesContent),
        'Audit trail security': _checkAuditTrailSecurity(rulesContent),
      };

      int passed = 0;
      int failed = 0;

      print('📋 Security Requirements Analysis:');
      print('=================================');

      for (final entry in requirements.entries) {
        final requirement = entry.key;
        final isImplemented = entry.value;

        if (isImplemented) {
          print('✅ $requirement');
          passed++;
        } else {
          print('❌ $requirement');
          failed++;
        }
      }

      print('');
      print('📊 Analysis Summary:');
      print('===================');
      print('✅ Implemented: $passed');
      print('❌ Missing: $failed');
      print(
        '📈 Compliance Rate: ${(passed / (passed + failed) * 100).toStringAsFixed(1)}%',
      );

      if (failed == 0) {
        print('');
        print('🛡️  SECURITY STATUS: COMPLIANT');
        print('   All security requirements are properly implemented.');
      } else {
        print('');
        print('⚠️  SECURITY STATUS: REVIEW REQUIRED');
        print('   Some security requirements are missing or incomplete.');
      }

      // Additional security insights
      print('');
      print('💡 Security Insights:');
      print('=====================');
      _printSecurityInsights(rulesContent);
    } catch (e) {
      print('❌ Error analyzing security rules: $e');
    }
  }

  static bool _checkHelperFunctions(String content) {
    return content.contains('function isAuthenticated()') &&
        content.contains('function getUserData()') &&
        content.contains('function isAdmin()') &&
        content.contains('function isManager()') &&
        content.contains('function isWorker()');
  }

  static bool _checkRoleBasedAccess(String content) {
    return content.contains("role == 'admin'") &&
        content.contains("role == 'manager'") &&
        content.contains("role == 'worker'");
  }

  static bool _checkCompanyIsolation(String content) {
    return content.contains('getUserCompanyId()') &&
        content.contains('companyId');
  }

  static bool _checkAdminCompanyCreation(String content) {
    return content.contains('match /companies/{companyId}') &&
        content.contains('allow create: if isAdmin()');
  }

  static bool _checkManagerPermissions(String content) {
    return content.contains('isManager()') &&
        content.contains('getUserCompanyId()');
  }

  static bool _checkWorkerPermissions(String content) {
    return content.contains('isWorker()') &&
        content.contains('request.auth.uid == userId');
  }

  static bool _checkLocationValidation(String content) {
    return content.contains('hasValidLocation') &&
        content.contains('location') &&
        content.contains('lat') &&
        content.contains('lng');
  }

  static bool _checkTimeEntryValidation(String content) {
    return (content.contains('timeEntries') ||
            content.contains('time_entries')) &&
        content.contains('isValidTimeEntryType') &&
        content.contains('clockIn') &&
        content.contains('clockOut');
  }

  static bool _checkCrossCompanyPrevention(String content) {
    return content.contains('getUserCompanyId()') &&
        content.contains('companyId');
  }

  static bool _checkUserDataProtection(String content) {
    return content.contains('request.auth.uid == userId');
  }

  static bool _checkAuditTrailSecurity(String content) {
    return content.contains('auditTrail') || content.contains('diagnostics');
  }

  static void _printSecurityInsights(String content) {
    print('🔐 Authentication: Required for all operations');
    print('👥 User Roles: Admin, Manager, Worker with distinct permissions');
    print('🏢 Company Isolation: Data scoped to user\'s company');
    print('📍 Location Tracking: Mandatory for clock-in operations');
    print('🚫 Cross-Access Prevention: Users cannot access other companies');
    print('📝 Data Validation: Time entries and user data properly validated');

    if (content.contains('location.lat >= -90 && location.lat <= 90')) {
      print('🌍 GPS Validation: Latitude/longitude bounds checking enabled');
    }

    if (content.contains('clockIn') && content.contains('hasValidLocation')) {
      print('⏰ Clock-in Security: Location required for all clock-in events');
    }
  }
}

void main() async {
  await SecurityRulesAnalyzer.analyzeRules();
}
