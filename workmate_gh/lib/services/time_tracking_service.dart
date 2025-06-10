import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/app_user.dart';
import '../models/company.dart';

enum TimeEntryType { clockIn, clockOut, breakStart, breakEnd }

class BreakRecord {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isPaidBreak;
  final String? notes;

  BreakRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.isPaidBreak,
    this.notes,
  });

  factory BreakRecord.fromJson(Map<String, dynamic> json) {
    return BreakRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      isPaidBreak: json['isPaidBreak'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isPaidBreak': isPaidBreak,
      'notes': notes,
    };
  }

  BreakRecord copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    bool? isPaidBreak,
    String? notes,
  }) {
    return BreakRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isPaidBreak: isPaidBreak ?? this.isPaidBreak,
      notes: notes ?? this.notes,
    );
  }

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }
}

class TimeEntry {
  final String id;
  final String userId;
  final String companyId; // Added for company-specific tracking
  final DateTime timestamp;
  final TimeEntryType type;
  final String? notes;
  final Map<String, double>? location; // lat, lng
  final List<BreakRecord> breaks; // Break records for this time entry

  TimeEntry({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.timestamp,
    required this.type,
    this.notes,
    this.location,
    this.breaks = const [],
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    final breaksList = json['breaks'] as List<dynamic>? ?? [];
    return TimeEntry(
      id: json['id'] as String,
      userId: json['userId'] as String,
      companyId: json['companyId'] as String? ?? '', // Handle legacy data
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: TimeEntryType.values.byName(json['type'] as String),
      notes: json['notes'] as String?,
      location:
          json['location'] != null
              ? Map<String, double>.from(json['location'])
              : null,
      breaks: breaksList.map((b) => BreakRecord.fromJson(b as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'companyId': companyId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'notes': notes,
      'location': location,
      'breaks': breaks.map((b) => b.toJson()).toList(),
    };
  }

  TimeEntry copyWith({
    String? id,
    String? userId,
    String? companyId,
    DateTime? timestamp,
    TimeEntryType? type,
    String? notes,
    Map<String, double>? location,
    List<BreakRecord>? breaks,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      breaks: breaks ?? this.breaks,
    );
  }

  /// Calculate total break duration for this time entry
  Duration get totalBreakDuration {
    return breaks.fold(Duration.zero, (total, breakRecord) {
      return total + breakRecord.duration;
    });
  }

  /// Calculate paid break duration for this time entry
  Duration get paidBreakDuration {
    return breaks.where((b) => b.isPaidBreak).fold(Duration.zero, (total, breakRecord) {
      return total + breakRecord.duration;
    });
  }

  /// Calculate unpaid break duration for this time entry
  Duration get unpaidBreakDuration {
    return breaks.where((b) => !b.isPaidBreak).fold(Duration.zero, (total, breakRecord) {
      return total + breakRecord.duration;
    });
  }
}

class TimeTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Location validation methods
  
  // Validate current location and get position
  Future<Map<String, dynamic>> _validateLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'error': 'Location services are disabled. Please enable GPS.',
        };
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'error': 'Location permissions are denied.',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'error': 'Location permissions are permanently denied. Please enable in settings.',
        };
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Check accuracy threshold
      if (position.accuracy > 100) { // 100 meters accuracy threshold
        return {
          'success': false,
          'error': 'Location accuracy is too low (${position.accuracy.toInt()}m). Please try again.',
        };
      }

      return {
        'success': true,
        'position': position,
        'coordinates': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get location: ${e.toString()}',
      };
    }
  }

  // Check if user is within company location radius
  Future<bool> _isWithinCompanyLocation(Position userPosition, Company company) async {
    if (company.coordinates == null) {
      // If company has no location set, allow clock-in from anywhere
      return true;
    }

    final companyLat = company.coordinates!['latitude']!;
    final companyLng = company.coordinates!['longitude']!;
    final allowedRadius = company.locationRadius ?? 500.0; // Default 500m

    final distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      companyLat,
      companyLng,
    );

    return distance <= allowedRadius;
  }

  // Get current user's latest time entry
  Future<TimeEntry?> getLatestTimeEntry() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final querySnapshot =
          await _firestore
              .collection('time_entries')
              .where('userId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return TimeEntry.fromJson(data);
      }
    } catch (e) {
      // Log error - consider using a proper logging framework in production
      // print('Error getting latest time entry: $e');
    }

    return null;
  }

  // Check if user is currently clocked in
  Future<bool> isCurrentlyClockedIn() async {
    final latestEntry = await getLatestTimeEntry();
    return latestEntry?.type == TimeEntryType.clockIn;
  }
  // Clock in with location validation
  Future<TimeEntry> clockIn({String? notes}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user's company info
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromMap(userDoc.data()!, user.uid);

    // Get company info for location validation
    final companyDoc = await _firestore.collection('companies').doc(appUser.companyId).get();
    if (!companyDoc.exists) throw Exception('Company not found');
    final company = Company.fromMap(companyDoc.data()!, companyDoc.id);

    // Check if already clocked in
    if (await isCurrentlyClockedIn()) {
      throw Exception('Already clocked in');
    }

    // Validate location
    final locationResult = await _validateLocation();
    if (!locationResult['success']) {
      throw Exception('Location unavailable: ${locationResult['error']}');
    }

    final position = locationResult['position'] as Position;
    final coordinates = locationResult['coordinates'] as Map<String, double>;

    // Check if within company location
    if (!await _isWithinCompanyLocation(position, company)) {
      final radius = company.locationRadius ?? 500.0;
      throw Exception('You must be within ${radius.toInt()}m of the company location to clock in');
    }

    final timeEntry = TimeEntry(
      id: '', // Will be set by Firestore
      userId: user.uid,
      companyId: appUser.companyId,
      timestamp: DateTime.now(),
      type: TimeEntryType.clockIn,
      notes: notes,
      location: coordinates,
    );

    try {
      final docRef = await _firestore
          .collection('time_entries')
          .add(timeEntry.toJson());

      return timeEntry.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to clock in: $e');
    }
  }

  // Clock out
  Future<TimeEntry> clockOut({String? notes}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user's company info
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromMap(userDoc.data()!, user.uid);

    // Check if currently clocked in
    if (!await isCurrentlyClockedIn()) {
      throw Exception('Not currently clocked in');
    }

    final timeEntry = TimeEntry(
      id: '', // Will be set by Firestore
      userId: user.uid,
      companyId: appUser.companyId,
      timestamp: DateTime.now(),
      type: TimeEntryType.clockOut,
      notes: notes,
    );

    try {
      final docRef = await _firestore
          .collection('time_entries')
          .add(timeEntry.toJson());

      return timeEntry.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to clock out: $e');
    }
  }

  // Get time entries for a specific date range
  Future<List<TimeEntry>> getTimeEntries({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) throw Exception('User not authenticated');

      final querySnapshot =
          await _firestore
              .collection('time_entries')
              .where('userId', isEqualTo: targetUserId)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: startDate.toIso8601String(),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: endDate.toIso8601String(),
              )
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TimeEntry.fromJson(data);
      }).toList();
    } catch (e) {
      // Log error - consider using a proper logging framework in production
      // print('Error getting time entries: $e');
      return [];
    }
  }

  // Calculate total hours worked for a date range
  Future<double> getTotalHoursWorked({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    final entries = await getTimeEntries(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );

    double totalHours = 0.0;
    TimeEntry? clockInEntry;

    for (final entry in entries.reversed) {
      if (entry.type == TimeEntryType.clockIn) {
        clockInEntry = entry;
      } else if (entry.type == TimeEntryType.clockOut && clockInEntry != null) {
        final duration = entry.timestamp.difference(clockInEntry.timestamp);
        totalHours += duration.inMinutes / 60.0;
        clockInEntry = null;
      }
    }

    return totalHours;
  }

  // Get time entries for a specific company (Manager/Admin use)
  Future<List<TimeEntry>> getTimeEntriesByCompany({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    try {
      Query query = _firestore
          .collection('time_entries')
          .where('companyId', isEqualTo: companyId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .where('timestamp', isLessThanOrEqualTo: endDate.toIso8601String());

      // Filter by specific user if provided
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final querySnapshot =
          await query.orderBy('timestamp', descending: true).get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return TimeEntry.fromJson(data);
      }).toList();
    } catch (e) {
      // Log error - consider using a proper logging framework in production
      return [];
    }
  }

  // Get total hours worked by company (Manager/Admin use)
  Future<double> getTotalHoursWorkedByCompany({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    final entries = await getTimeEntriesByCompany(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );

    double totalHours = 0.0;
    TimeEntry? clockInEntry;

    for (final entry in entries.reversed) {
      if (entry.type == TimeEntryType.clockIn) {
        clockInEntry = entry;
      } else if (entry.type == TimeEntryType.clockOut && clockInEntry != null) {
        final duration = entry.timestamp.difference(clockInEntry.timestamp);
        totalHours += duration.inMinutes / 60.0;
        clockInEntry = null;
      }
    }

    return totalHours;
  }

  // Get all users with time entries for a company (Admin/Manager use)
  Future<Map<String, double>> getHoursByUserForCompany({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = await getTimeEntriesByCompany(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, double> userHours = {};
    final Map<String, TimeEntry?> userClockIns = {};

    for (final entry in entries.reversed) {
      final userId = entry.userId;

      if (entry.type == TimeEntryType.clockIn) {
        userClockIns[userId] = entry;
      } else if (entry.type == TimeEntryType.clockOut &&
          userClockIns[userId] != null) {
        final clockInEntry = userClockIns[userId]!;
        final duration = entry.timestamp.difference(clockInEntry.timestamp);
        userHours[userId] =
            (userHours[userId] ?? 0) + (duration.inMinutes / 60.0);
        userClockIns[userId] = null;
      }
    }

    return userHours;
  }

  // Break tracking methods
  
  // Start a break
  Future<BreakRecord> startBreak({
    required String timeEntryId,
    bool isPaidBreak = false,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if currently clocked in
    if (!await isCurrentlyClockedIn()) {
      throw Exception('Must be clocked in to start a break');
    }

    // Check if already on a break
    final currentBreak = await getCurrentBreak(timeEntryId);
    if (currentBreak != null) {
      throw Exception('Already on a break');
    }

    final breakRecord = BreakRecord(
      id: '', // Will be set by Firestore
      startTime: DateTime.now(),
      isPaidBreak: isPaidBreak,
      notes: notes,
    );

    try {
      // Add break to the time entry's breaks subcollection
      final docRef = await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .collection('breaks')
          .add(breakRecord.toJson());

      return breakRecord.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to start break: $e');
    }
  }

  // End a break
  Future<BreakRecord> endBreak({
    required String timeEntryId,
    required String breakId,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get the current break
      final breakDoc = await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .collection('breaks')
          .doc(breakId)
          .get();

      if (!breakDoc.exists) {
        throw Exception('Break record not found');
      }

      final breakData = breakDoc.data()!;
      breakData['id'] = breakDoc.id;
      final currentBreak = BreakRecord.fromJson(breakData);

      if (currentBreak.endTime != null) {
        throw Exception('Break already ended');
      }

      // Update break with end time
      final updatedBreak = currentBreak.copyWith(
        endTime: DateTime.now(),
        notes: notes ?? currentBreak.notes,
      );

      await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .collection('breaks')
          .doc(breakId)
          .update(updatedBreak.toJson());

      return updatedBreak;
    } catch (e) {
      throw Exception('Failed to end break: $e');
    }
  }

  // Get current active break for a time entry
  Future<BreakRecord?> getCurrentBreak(String timeEntryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .collection('breaks')
          .where('endTime', isNull: true)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return BreakRecord.fromJson(data);
      }
    } catch (e) {
      // Log error
    }
    return null;
  }

  // Get all breaks for a time entry
  Future<List<BreakRecord>> getBreaksForTimeEntry(String timeEntryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .collection('breaks')
          .orderBy('startTime', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BreakRecord.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Check if user is currently on a break
  Future<bool> isCurrentlyOnBreak() async {
    final latestEntry = await getLatestTimeEntry();
    if (latestEntry == null || latestEntry.type != TimeEntryType.clockIn) {
      return false;
    }

    final currentBreak = await getCurrentBreak(latestEntry.id);
    return currentBreak != null;
  }

  // Calculate total break duration for a date range
  Future<Duration> getTotalBreakDuration({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
    bool? isPaidBreak,
  }) async {
    final entries = await getTimeEntries(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );

    Duration totalDuration = Duration.zero;

    for (final entry in entries) {
      final breaks = await getBreaksForTimeEntry(entry.id);
      for (final breakRecord in breaks) {
        if (isPaidBreak == null || breakRecord.isPaidBreak == isPaidBreak) {
          totalDuration += breakRecord.duration;
        }
      }
    }

    return totalDuration;
  }

  // Calculate effective working hours (excluding unpaid breaks)
  Future<double> getEffectiveHoursWorked({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    final totalHours = await getTotalHoursWorked(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );

    final unpaidBreakDuration = await getTotalBreakDuration(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
      isPaidBreak: false,
    );

    final effectiveHours = totalHours - (unpaidBreakDuration.inMinutes / 60.0);
    return effectiveHours > 0 ? effectiveHours : 0;
  }
}
