import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/company.dart';
import '../models/app_user.dart';

class CompanyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new company (Admin only)
  Future<Company> createCompany({
    required String name,
    required String address,
    String? phone,
    String? email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final company = Company(
      id: '', // Will be set by Firestore
      name: name,
      address: address,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
      adminId: user.uid,
    );

    try {
      final docRef = await _db.collection('companies').add(company.toMap());
      return company.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create company: $e');
    }
  }

  // Get all companies (Admin only)
  Future<List<Company>> getAllCompanies() async {
    try {
      final querySnapshot =
          await _db
              .collection('companies')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

      return querySnapshot.docs.map((doc) {
        return Company.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get companies: $e');
    }
  }

  // Get companies managed by current admin
  Future<List<Company>> getCompaniesByAdmin(String adminId) async {
    try {
      final querySnapshot =
          await _db
              .collection('companies')
              .where('adminId', isEqualTo: adminId)
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

      return querySnapshot.docs.map((doc) {
        return Company.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get companies by admin: $e');
    }
  }

  // Get company by ID
  Future<Company?> getCompanyById(String companyId) async {
    try {
      final doc = await _db.collection('companies').doc(companyId).get();
      if (doc.exists) {
        return Company.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get company: $e');
    }
  }

  // Update company (Admin only)
  Future<void> updateCompany(Company company) async {
    try {
      await _db.collection('companies').doc(company.id).update(company.toMap());
    } catch (e) {
      throw Exception('Failed to update company: $e');
    }
  }

  // Deactivate company (Admin only)
  Future<void> deactivateCompany(String companyId) async {
    try {
      await _db.collection('companies').doc(companyId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to deactivate company: $e');
    }
  }

  // Get users by company
  Future<List<AppUser>> getUsersByCompany(String companyId) async {
    try {
      final querySnapshot =
          await _db
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .get();

      return querySnapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users by company: $e');
    }
  }

  // Get managers for a company
  Future<List<AppUser>> getManagersByCompany(String companyId) async {
    try {
      final querySnapshot =
          await _db
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .where('role', isEqualTo: 'manager')
              .get();

      return querySnapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get managers by company: $e');
    }
  }

  // Get workers for a company
  Future<List<AppUser>> getWorkersByCompany(String companyId) async {
    try {
      final querySnapshot =
          await _db
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .where('role', isEqualTo: 'worker')
              .get();

      return querySnapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get workers by company: $e');
    }
  }
}
