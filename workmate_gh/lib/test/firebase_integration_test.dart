// Test Firebase Integration
// This file can be used to verify Firebase connection and services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';

class FirebaseIntegrationTest {
  static Future<bool> testFirebaseConnection() async {
    try {
      // Test Firestore connection
      FirebaseFirestore.instance.settings;
      debugPrint('✅ Firestore connection successful');

      // Test collections access
      await FirebaseFirestore.instance.collection('users').limit(1).get();
      debugPrint('✅ Users collection accessible');

      await FirebaseFirestore.instance.collection('companies').limit(1).get();
      debugPrint('✅ Companies collection accessible');

      return true;
    } catch (e) {
      debugPrint('❌ Firebase connection failed: $e');
      return false;
    }
  }

  static Future<bool> testServices() async {
    try {
      // Test AuthService and CompanyService
      AuthService();
      debugPrint('✅ AuthService initialized');

      // Test CompanyService
      final companyService = CompanyService();
      await companyService.getAllCompanies();
      debugPrint('✅ CompanyService operational');

      return true;
    } catch (e) {
      debugPrint('❌ Services test failed: $e');
      return false;
    }
  }

  static Future<void> runAllTests() async {
    debugPrint('🔄 Starting Firebase Integration Tests...\n');

    final connectionTest = await testFirebaseConnection();
    final servicesTest = await testServices();

    if (connectionTest && servicesTest) {
      debugPrint(
        '\n🎉 All tests passed! Firebase integration is fully operational.',
      );
    } else {
      debugPrint(
        '\n⚠️ Some tests failed. Please check Firebase configuration.',
      );
    }
  }
}
