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
    required String location,
    required String address,
    String? phone,
    String? email,
    String? managerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final company = Company(
      id: '', // Will be set by Firestore
      name: name,
      location: location,
      address: address,
      phone: phone,
      email: email,
      managerId: managerId,
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

  // Get companies with pagination and search (Admin only)
  Future<Map<String, dynamic>> getCompaniesPaginated({
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      Query query = _db
          .collection('companies')
          .where('isActive', isEqualTo: true);

      // Add search functionality
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Search by name (case-insensitive)
        final searchLower = searchQuery.toLowerCase();
        query = query
            .where('name', isGreaterThanOrEqualTo: searchLower)
            .where('name', isLessThanOrEqualTo: '$searchLower\uf8ff');
      }

      query = query.orderBy('name').limit(limit);

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      
      final companies = querySnapshot.docs.map((doc) {
        return Company.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      return {
        'companies': companies,
        'lastDocument': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        'hasMore': querySnapshot.docs.length == limit,
      };
    } catch (e) {
      throw Exception('Failed to get companies: $e');
    }
  }

  // Search companies by name or location
  Future<List<Company>> searchCompanies(String searchQuery) async {
    try {
      final searchLower = searchQuery.toLowerCase();
      
      // Search by name
      final nameQuery = await _db
          .collection('companies')
          .where('isActive', isEqualTo: true)
          .where('name', isGreaterThanOrEqualTo: searchLower)
          .where('name', isLessThanOrEqualTo: '$searchLower\uf8ff')
          .orderBy('name')
          .limit(20)
          .get();

      // Search by location
      final locationQuery = await _db
          .collection('companies')
          .where('isActive', isEqualTo: true)
          .where('location', isGreaterThanOrEqualTo: searchLower)
          .where('location', isLessThanOrEqualTo: '$searchLower\uf8ff')
          .orderBy('location')
          .limit(20)
          .get();

      final Set<String> addedIds = {};
      final List<Company> results = [];

      // Add name search results
      for (final doc in nameQuery.docs) {
        if (!addedIds.contains(doc.id)) {
          results.add(Company.fromMap(doc.data(), doc.id));
          addedIds.add(doc.id);
        }
      }

      // Add location search results
      for (final doc in locationQuery.docs) {
        if (!addedIds.contains(doc.id)) {
          results.add(Company.fromMap(doc.data(), doc.id));
          addedIds.add(doc.id);
        }
      }

      // Sort by name
      results.sort((a, b) => a.name.compareTo(b.name));
      
      return results;
    } catch (e) {
      throw Exception('Failed to search companies: $e');
    }
  }

  // Assign manager to company
  Future<void> assignManagerToCompany(String companyId, String managerId) async {
    try {
      await _db.collection('companies').doc(companyId).update({
        'managerId': managerId,
      });

      // Update the manager's company assignment
      await _db.collection('users').doc(managerId).update({
        'companyId': companyId,
      });
    } catch (e) {
      throw Exception('Failed to assign manager to company: $e');
    }
  }

  // Remove manager from company
  Future<void> removeManagerFromCompany(String companyId) async {
    try {
      final company = await getCompanyById(companyId);
      if (company?.managerId != null) {
        // Update company
        await _db.collection('companies').doc(companyId).update({
          'managerId': FieldValue.delete(),
        });

        // Remove company assignment from manager
        await _db.collection('users').doc(company!.managerId!).update({
          'companyId': FieldValue.delete(),
        });
      }
    } catch (e) {
      throw Exception('Failed to remove manager from company: $e');
    }
  }

  // Get available managers (not assigned to any company)
  Future<List<AppUser>> getAvailableManagers() async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .where('isActive', isEqualTo: true)
          .get();

      final allManagers = querySnapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();

      // Filter out managers already assigned to companies
      final availableManagers = <AppUser>[];
      for (final manager in allManagers) {
        if (manager.companyId.isEmpty) {
          availableManagers.add(manager);
        }
      }

      return availableManagers;
    } catch (e) {
      throw Exception('Failed to get available managers: $e');
    }
  }

  // Get manager by ID
  Future<AppUser?> getManagerById(String managerId) async {
    try {
      final doc = await _db.collection('users').doc(managerId).get();
      if (doc.exists) {
        final user = AppUser.fromMap(doc.data()!, doc.id);
        return user.role == UserRole.manager ? user : null;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get manager: $e');
    }
  }
}
