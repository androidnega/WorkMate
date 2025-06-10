import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import '../models/attendance_summary.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Standard work hours (configurable per company in the future)
  static const workStartHour = 8; // 8 AM
  static const workStartMinute = 30; // 8:30 AM
  static const lateThresholdMinutes = 15; // 15 minutes grace period

  // Get weekly attendance summary for a worker
  Future<AttendanceSummary> getWeeklySummary(
    String userId,
    DateTime weekStart,
  ) async {
    // Ensure weekStart is the beginning of the week
    weekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - weekStart.weekday + 1,
    );
    final weekEnd = weekStart.add(const Duration(days: 7));

    return _getAttendanceSummary(userId, weekStart, weekEnd);
  }

  // Get monthly attendance summary for a worker
  Future<AttendanceSummary> getMonthlySummary(
    String userId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    return _getAttendanceSummary(userId, monthStart, monthEnd);
  }

  // Get attendance summary for all workers in a company
  Future<List<AttendanceSummary>> getCompanyMonthlySummary(
    String companyId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    // Get all workers in the company
    final workersSnapshot =
        await _db
            .collection('users')
            .where('companyId', isEqualTo: companyId)
            .where('role', isEqualTo: 'worker')
            .get();

    final summaries = <AttendanceSummary>[];
    for (final worker in workersSnapshot.docs) {
      final summary = await _getAttendanceSummary(
        worker.id,
        monthStart,
        monthEnd,
      );
      summaries.add(summary);
    }

    return summaries;
  }

  // Internal method to generate attendance summary
  Future<AttendanceSummary> _getAttendanceSummary(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get user details
    final userDoc = await _db.collection('users').doc(userId).get();
    final userName = userDoc.data()?['name'] ?? 'Unknown Worker';

    // Get attendance records
    final recordsQuery =
        await _db
            .collection('time_entries')
            .where('userId', isEqualTo: userId)
            .where('timestamp', isGreaterThanOrEqualTo: startDate)
            .where('timestamp', isLessThan: endDate)
            .orderBy('timestamp')
            .get();

    final records = <AttendanceRecord>[];
    var totalMinutes = 0;
    var totalBreakMinutes = 0;
    var lateArrivals = 0;
    var presentDays = 0;

    // Group records by day
    final dailyRecords = <String, List<DocumentSnapshot>>{};
    for (final record in recordsQuery.docs) {
      final data = record.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final dateKey = timestamp.toIso8601String().split('T')[0];

      dailyRecords.putIfAbsent(dateKey, () => []).add(record);
    }

    // Process each day's records
    for (final entry in dailyRecords.entries) {
      final dayRecords = entry.value;
      if (dayRecords.isEmpty) continue;

      var clockIn =
          (dayRecords.first.data() as Map<String, dynamic>)['timestamp']
              as Timestamp;
      DocumentSnapshot? clockOutDoc;
      Duration? breakDuration;

      for (final record in dayRecords) {
        final data = record.data() as Map<String, dynamic>;
        if (data['type'] == 'clockOut') {
          clockOutDoc = record;
        } else if (data['type'] == 'break') {
          final breakMinutes = data['duration'] as int? ?? 0;
          totalBreakMinutes += breakMinutes;
          breakDuration = Duration(minutes: breakMinutes);
        }
      }

      final clockInTime = clockIn.toDate();
      final expectedStart = DateTime(
        clockInTime.year,
        clockInTime.month,
        clockInTime.day,
        workStartHour,
        workStartMinute,
      );

      final isLate =
          clockInTime.difference(expectedStart).inMinutes >
          lateThresholdMinutes;
      if (isLate) lateArrivals++;

      Duration? totalHours;
      if (clockOutDoc != null) {
        final clockOut =
            (clockOutDoc.data() as Map<String, dynamic>)['timestamp']
                as Timestamp;
        final workMinutes = clockOut.toDate().difference(clockInTime).inMinutes;
        totalMinutes += workMinutes;
        totalHours = Duration(minutes: workMinutes);
        presentDays++;
      }

      records.add(
        AttendanceRecord(
          userId: userId,
          userName: userName,
          clockIn: clockInTime,
          clockOut:
              clockOutDoc != null
                  ? ((clockOutDoc.data() as Map<String, dynamic>)['timestamp']
                          as Timestamp)
                      .toDate()
                  : null,
          breakDuration: breakDuration,
          totalHours: totalHours,
          isLate: isLate,
        ),
      );
    }

    // Calculate total work days in period
    final totalDays = endDate.difference(startDate).inDays;

    return AttendanceSummary(
      userId: userId,
      userName: userName,
      startDate: startDate,
      endDate: endDate,
      totalHours: Duration(minutes: totalMinutes),
      totalBreakTime: Duration(minutes: totalBreakMinutes),
      lateArrivals: lateArrivals,
      totalDays: totalDays,
      presentDays: presentDays,
      records: records,
    );
  }

  // Generate CSV for attendance records
  String generateCsv(AttendanceSummary summary) {
    final csvData = [
      // Header row
      AttendanceSummary.csvHeaders,
      // Summary row
      ['Summary for ${summary.userName}'],
      [
        'Period',
        '${summary.startDate.toLocal().toString().split(' ')[0]} to ${summary.endDate.toLocal().toString().split(' ')[0]}',
      ],
      ['Total Hours', AttendanceSummary.formatDuration(summary.totalHours)],
      [
        'Average Daily Hours',
        AttendanceSummary.formatDuration(summary.averageDailyHours),
      ],
      [
        'Total Break Time',
        AttendanceSummary.formatDuration(summary.totalBreakTime),
      ],
      ['Late Arrivals', summary.lateArrivals.toString()],
      ['Attendance', '${summary.attendancePercentage}%'],
      [], // Empty row for spacing
      // Data rows
      ...summary.records.map((record) => summary.toCsvRow(record)),
    ];

    return const ListToCsvConverter().convert(csvData);
  }
}
