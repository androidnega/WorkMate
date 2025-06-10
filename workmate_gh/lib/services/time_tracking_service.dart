import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/app_user.dart';
import '../models/company.dart';
import '../models/attendance_summary.dart';

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
      endTime:
          json['endTime'] != null
              ? DateTime.parse(json['endTime'] as String)
              : null,
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
      breaks:
          breaksList
              .map((b) => BreakRecord.fromJson(b as Map<String, dynamic>))
              .toList(),
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
    return breaks.where((b) => b.isPaidBreak).fold(Duration.zero, (
      total,
      breakRecord,
    ) {
      return total + breakRecord.duration;
    });
  }

  /// Calculate unpaid break duration for this time entry
  Duration get unpaidBreakDuration {
    return breaks.where((b) => !b.isPaidBreak).fold(Duration.zero, (
      total,
      breakRecord,
    ) {
      return total + breakRecord.duration;
    });
  }
}

class TimeTrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Standard work hours (configurable per company in the future)
  static const workStartHour = 8; // 8 AM
  static const workStartMinute = 30; // 8:30 AM
  static const lateThresholdMinutes = 15; // 15 minutes grace period

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
          'error':
              'Location permissions are permanently denied. Please enable in settings.',
        };
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Check accuracy threshold
      if (position.accuracy > 100) {
        // 100 meters accuracy threshold
        return {
          'success': false,
          'error':
              'Location accuracy is too low (${position.accuracy.toInt()}m). Please try again.',
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
  Future<bool> _isWithinCompanyLocation(
    Position userPosition,
    Company company,
  ) async {
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
          await _db
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
  Future<void> clockIn(Map<String, double> location) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Get user's company ID
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User document not found');
    final companyId = userDoc.data()?['companyId'];

    // Check for existing clock-in today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final existing =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('type', isEqualTo: 'clockIn')
            .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Already clocked in today');
    }

    // Calculate if late
    final expectedStart = DateTime(
      today.year,
      today.month,
      today.day,
      workStartHour,
      workStartMinute,
    );
    final isLate =
        today.difference(expectedStart).inMinutes > lateThresholdMinutes;

    // Create clock-in record
    await _db.collection('time_entries').add({
      'userId': user.uid,
      'companyId': companyId,
      'type': 'clockIn',
      'timestamp': FieldValue.serverTimestamp(),
      'location': location,
      'isLate': isLate,
    });
  }

  // Clock out
  Future<void> clockOut(Map<String, double> location) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Get user's company ID
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User document not found');
    final companyId = userDoc.data()?['companyId'];

    // Check for existing clock-in today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final clockIn =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('type', isEqualTo: 'clockIn')
            .get();

    if (clockIn.docs.isEmpty) {
      throw Exception('No clock-in record found for today');
    }

    // Create clock-out record
    await _db.collection('time_entries').add({
      'userId': user.uid,
      'companyId': companyId,
      'type': 'clockOut',
      'timestamp': FieldValue.serverTimestamp(),
      'location': location,
    });
  }

  // Start break
  Future<void> startBreak() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Get user's company ID
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User document not found');
    final companyId = userDoc.data()?['companyId'];

    // Check for existing active break
    final activeBreak =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'break')
            .where('endTime', isNull: true)
            .get();

    if (activeBreak.docs.isNotEmpty) {
      throw Exception('Already on break');
    }

    // Create break record
    await _db.collection('time_entries').add({
      'userId': user.uid,
      'companyId': companyId,
      'type': 'break',
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'duration': null,
    });
  }

  // End break
  Future<void> endBreak() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Find active break
    final activeBreak =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'break')
            .where('endTime', isNull: true)
            .get();

    if (activeBreak.docs.isEmpty) {
      throw Exception('No active break found');
    }

    final breakDoc = activeBreak.docs.first;
    final startTime = (breakDoc.data()['startTime'] as Timestamp).toDate();
    final endTime = DateTime.now();
    final durationMinutes = endTime.difference(startTime).inMinutes;

    // Update break record with end time and duration
    await breakDoc.reference.update({
      'endTime': FieldValue.serverTimestamp(),
      'duration': durationMinutes,
    });
  }

  // Get current user's status (clocked in/out, on break)
  Future<Map<String, dynamic>> getCurrentStatus() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // Check clock-in status
    final clockIn =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('type', isEqualTo: 'clockIn')
            .get();

    final isClockedIn = clockIn.docs.isNotEmpty;

    // Check clock-out status
    final clockOut =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('type', isEqualTo: 'clockOut')
            .get();

    final isClockedOut = clockOut.docs.isNotEmpty;

    // Check break status
    final activeBreak =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'break')
            .where('endTime', isNull: true)
            .get();

    final isOnBreak = activeBreak.docs.isNotEmpty;

    return {
      'isClockedIn': isClockedIn,
      'isClockedOut': isClockedOut,
      'isOnBreak': isOnBreak,
      'clockInTime':
          isClockedIn
              ? (clockIn.docs.first.data()['timestamp'] as Timestamp).toDate()
              : null,
      'isLate':
          isClockedIn ? clockIn.docs.first.data()['isLate'] ?? false : false,
    };
  }

  // Get time entries for a specific period
  Future<List<TimeEntry>> getTimeEntries({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: userId)
            .where('timestamp', isGreaterThanOrEqualTo: startDate)
            .where('timestamp', isLessThan: endDate)
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TimeEntry.fromJson(data);
    }).toList();
  }

  // Get breaks for a time entry
  Future<List<BreakRecord>> getBreaksForTimeEntry(String timeEntryId) async {
    final snapshot =
        await _db
            .collection('time_entries')
            .doc(timeEntryId)
            .collection('breaks')
            .orderBy('startTime')
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return BreakRecord.fromJson(data);
    }).toList();
  }

  // Get current active break for a time entry
  Future<BreakRecord?> getCurrentBreak(String timeEntryId) async {
    final snapshot =
        await _db
            .collection('time_entries')
            .doc(timeEntryId)
            .collection('breaks')
            .where('endTime', isNull: true)
            .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return BreakRecord.fromJson(data);
  }

  // Calculate total hours worked
  Future<double> getTotalHoursWorked({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = await getTimeEntries(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    Duration totalWorked = Duration.zero;
    Duration totalBreaks = Duration.zero;

    // Group entries by clockIn/clockOut pairs
    final clockIns =
        entries.where((e) => e.type == TimeEntryType.clockIn).toList();
    for (final clockIn in clockIns) {
      final clockOut = entries.firstWhere(
        (e) =>
            e.type == TimeEntryType.clockOut &&
            e.timestamp.isAfter(clockIn.timestamp),
        orElse: () => clockIn,
      );

      if (clockOut.type == TimeEntryType.clockOut) {
        final duration = clockOut.timestamp.difference(clockIn.timestamp);
        totalWorked += duration;

        // Calculate break time
        final breaks = await getBreaksForTimeEntry(clockIn.id);
        totalBreaks += breaks.fold<Duration>(
          Duration.zero,
          (prev, curr) => prev + curr.duration,
        );
      }
    }

    // Convert to hours
    final effectiveMinutes = totalWorked.inMinutes - totalBreaks.inMinutes;
    return effectiveMinutes / 60.0;
  }

  // Check if a user is currently on break
  Future<bool> isCurrentlyOnBreak() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final latestEntry = await getLatestTimeEntry();
    if (latestEntry == null || latestEntry.type != TimeEntryType.clockIn) {
      return false;
    }

    final currentBreak = await getCurrentBreak(latestEntry.id);
    return currentBreak != null;
  }

  // Process location data for clock in/out
  Future<Map<String, double>> _getLocationData() async {
    final validationResult = await _validateLocation();
    if (!validationResult['success']) {
      throw Exception(validationResult['error']);
    }

    final position = validationResult['position'];
    return {'latitude': position.latitude, 'longitude': position.longitude};
  }
}
