import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

enum TimeEntryType { clockIn, clockOut, breakStart, breakEnd }

class TimeEntry {
  final String id;
  final String userId;
  final String companyId; // Added for company-specific tracking
  final DateTime timestamp;
  final TimeEntryType type;
  final String? notes;
  final Map<String, double>? location; // lat, lng

  TimeEntry({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.timestamp,
    required this.type,
    this.notes,
    this.location,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
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
  }) {
    return TimeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      location: location ?? this.location,
    );
  }
}

class TimeTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Clock in
  Future<TimeEntry> clockIn({String? notes}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user's company info
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromMap(userDoc.data()!, user.uid);

    // Check if already clocked in
    if (await isCurrentlyClockedIn()) {
      throw Exception('Already clocked in');
    }

    final timeEntry = TimeEntry(
      id: '', // Will be set by Firestore
      userId: user.uid,
      companyId: appUser.companyId,
      timestamp: DateTime.now(),
      type: TimeEntryType.clockIn,
      notes: notes,
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
}
