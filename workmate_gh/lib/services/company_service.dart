import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../models/company.dart';
import '../models/app_user.dart';

class CompanyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create new company
  Future<Company> createCompany({
    required String name,
    required String address,
    required String adminId,
    String? phone,
    String? email,
    String? logoUrl,
    Map<String, String>? workSchedule,
  }) async {
    final timestamp = DateTime.now();
    final coordinates = await getCoordinatesFromAddress(address);
    
    final doc = await _db.collection('companies').add({
      'name': name,
      'address': address,
      'adminId': adminId,
      'phone': phone,
      'email': email,
      'coordinates': coordinates,
      'locationRadius': 500.0, // Default 500m radius
      'logoUrl': logoUrl,
      'workSchedule': workSchedule ?? {
        'monday': '08:30-17:30',
        'tuesday': '08:30-17:30',
        'wednesday': '08:30-17:30',
        'thursday': '08:30-17:30',
        'friday': '08:30-17:30',
      },
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'isActive': true,
    });

    return Company(
      id: doc.id,
      name: name,
      address: address,
      adminId: adminId,
      phone: phone,
      email: email,
      coordinates: coordinates,
      logoUrl: logoUrl,
      workSchedule: workSchedule,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  // Convert address to coordinates
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (e) {
      print('Error geocoding address: $e');
    }
    return null;
  }

  // Calculate distance between two points using Haversine formula
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    // Convert to radians
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi/2) * sin(deltaPhi/2) +
              cos(phi1) * cos(phi2) *
              sin(deltaLambda/2) * sin(deltaLambda/2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return earthRadius * c; // Distance in meters
  }

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

    // Validate company name is unique
    final existingCompanies =
        await _db
            .collection('companies')
            .where('name', isEqualTo: name)
            .where('isActive', isEqualTo: true)
            .get();

    if (existingCompanies.docs.isNotEmpty) {
      throw Exception('A company with this name already exists');
    }

    // Get coordinates from address for geofencing
    List<Location> locations = await locationFromAddress('$address, $location');
    if (locations.isEmpty) {
      throw Exception('Invalid address or location');
    }

    final coordinates = {
      'lat': locations.first.latitude,
      'lng': locations.first.longitude,
    };

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
      coordinates: coordinates,
      locationRadius: 500.0, // Default 500 meter radius for geofencing
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

      final companies =
          querySnapshot.docs.map((doc) {
            return Company.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

      return {
        'companies': companies,
        'lastDocument':
            querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
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
      final nameQuery =
          await _db
              .collection('companies')
              .where('isActive', isEqualTo: true)
              .where('name', isGreaterThanOrEqualTo: searchLower)
              .where('name', isLessThanOrEqualTo: '$searchLower\uf8ff')
              .orderBy('name')
              .limit(20)
              .get();

      // Search by location
      final locationQuery =
          await _db
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
  Future<void> assignManagerToCompany(
    String companyId,
    String managerId,
  ) async {
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
      final querySnapshot =
          await _db
              .collection('users')
              .where('role', isEqualTo: 'manager')
              .where('isActive', isEqualTo: true)
              .get();

      final allManagers =
          querySnapshot.docs.map((doc) {
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

  // Get company location details
  Future<Map<String, dynamic>> getCompanyLocation(String companyId) async {
    try {
      final company = await getCompanyById(companyId);
      if (company == null || company.coordinates == null) {
        throw Exception('Company location not found');
      }

      return {
        'coordinates': company.coordinates,
        'radius': company.locationRadius,
        'address': company.address,
        'location': company.location,
      };
    } catch (e) {
      throw Exception('Failed to get company location: $e');
    }
  }

  // Update company geofence radius
  Future<void> updateCompanyGeofence(String companyId, double radius) async {
    try {
      await _db.collection('companies').doc(companyId).update({
        'locationRadius': radius,
      });
    } catch (e) {
      throw Exception('Failed to update company geofence: $e');
    }
  }

  // Verify if coordinates are within company's geofence
  Future<bool> verifyLocationForCompany(
    String companyId,
    double latitude,
    double longitude,
  ) async {
    try {
      final company = await getCompanyById(companyId);
      if (company == null || company.coordinates == null) {
        return false;
      }

      // Calculate distance between points
      final companyLat = company.coordinates!['lat']!;
      final companyLng = company.coordinates!['lng']!;

      final distance = _calculateDistance(
        companyLat,
        companyLng,
        latitude,
        longitude,
      );

      // Check if within radius (convert to meters)
      return distance <= (company.locationRadius ?? 500.0);
    } catch (e) {
      return false;
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }
}
