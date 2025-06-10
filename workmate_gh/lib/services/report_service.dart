import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import '../models/app_user.dart';
import '../services/time_tracking_service.dart';
import 'dart:html' as html;

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TimeTrackingService _timeTrackingService = TimeTrackingService();

  // Get weekly attendance report for a company
  Future<List<TimeEntry>> getWeeklyReport(String companyId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final snapshot =
        await _db
            .collection('time_entries')
            .where('companyId', isEqualTo: companyId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
            .where('timestamp', isLessThan: endOfWeek)
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => TimeEntry.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Get monthly attendance report for a company
  Future<List<TimeEntry>> getMonthlyReport(String companyId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final snapshot =
        await _db
            .collection('time_entries')
            .where('companyId', isEqualTo: companyId)
            .where('timestamp', isGreaterThanOrEqualTo: monthStart)
            .where('timestamp', isLessThan: monthEnd)
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => TimeEntry.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Get daily report for a specific date
  Future<List<TimeEntry>> getDailyReport(
    String companyId,
    DateTime date,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snapshot =
        await _db
            .collection('time_entries')
            .where('companyId', isEqualTo: companyId)
            .where('timestamp', isGreaterThanOrEqualTo: dayStart)
            .where('timestamp', isLessThan: dayEnd)
            .orderBy('timestamp', descending: false)
            .get();

    return snapshot.docs
        .map((doc) => TimeEntry.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Get worker performance summary
  Future<Map<String, dynamic>> getWorkerSummary(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final entries = await _timeTrackingService.getTimeEntries(
      startDate: startDate,
      endDate: endDate,
      userId: workerId,
    );

    Duration totalWorked = Duration.zero;
    Duration totalBreaks = Duration.zero;
    int daysWorked = 0;
    int totalClockIns = 0;

    final Map<DateTime, List<TimeEntry>> entriesByDate = {};

    // Group entries by date
    for (final entry in entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      entriesByDate.putIfAbsent(date, () => []).add(entry);
    }

    // Calculate daily totals
    for (final dateEntries in entriesByDate.values) {
      final clockIns =
          dateEntries.where((e) => e.type == TimeEntryType.clockIn).toList();
      final clockOuts =
          dateEntries.where((e) => e.type == TimeEntryType.clockOut).toList();

      if (clockIns.isNotEmpty) {
        daysWorked++;
        totalClockIns += clockIns.length;

        // Calculate work time for each clock-in/out pair
        for (int i = 0; i < clockIns.length; i++) {
          final clockIn = clockIns[i];
          final clockOut = clockOuts.length > i ? clockOuts[i] : null;

          if (clockOut != null) {
            final workDuration = clockOut.timestamp.difference(
              clockIn.timestamp,
            );
            totalWorked += workDuration;

            // Calculate break time for this session
            final breaks = await _timeTrackingService.getBreaksForTimeEntry(
              clockIn.id,
            );
            for (final breakRecord in breaks) {
              totalBreaks += breakRecord.duration;
            }
          }
        }
      }
    }

    final effectiveHours = totalWorked - totalBreaks;
    final averageHoursPerDay =
        daysWorked > 0 ? effectiveHours.inMinutes / daysWorked / 60 : 0.0;

    return {
      'workerId': workerId,
      'totalHoursWorked':
          effectiveHours.inHours + (effectiveHours.inMinutes % 60) / 60.0,
      'totalBreakTime':
          totalBreaks.inHours + (totalBreaks.inMinutes % 60) / 60.0,
      'daysWorked': daysWorked,
      'averageHoursPerDay': averageHoursPerDay,
      'totalClockIns': totalClockIns,
    };
  }

  // Generate CSV report
  Future<String> generateCSVReport(
    List<TimeEntry> entries,
    Map<String, AppUser> userMap,
  ) async {
    final List<List<dynamic>> csvData = [
      // Header row
      [
        'Date',
        'Time',
        'Worker Name',
        'Action',
        'Location',
        'Notes',
        'Duration (if break)',
      ],
    ];

    for (final entry in entries) {
      final user = userMap[entry.userId];
      final userName = user?.name ?? 'Unknown User';
      final date = entry.timestamp.toLocal();
      final dateStr = '${date.day}/${date.month}/${date.year}';
      final timeStr =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      String action = entry.type.name;
      String locationStr = '';
      String duration = '';

      if (entry.location != null) {
        locationStr =
            '${entry.location!['lat']?.toStringAsFixed(6)}, ${entry.location!['lng']?.toStringAsFixed(6)}';
      }

      // Add breaks information if this is a clock-in entry
      if (entry.type == TimeEntryType.clockIn) {
        final breaks = await _timeTrackingService.getBreaksForTimeEntry(
          entry.id,
        );
        if (breaks.isNotEmpty) {
          for (final breakRecord in breaks) {
            csvData.add([
              dateStr,
              timeStr,
              userName,
              'Break ${breakRecord.isPaidBreak ? '(Paid)' : '(Unpaid)'}',
              locationStr,
              breakRecord.notes ?? '',
              '${breakRecord.duration.inMinutes} min',
            ]);
          }
        }
      }

      csvData.add([
        dateStr,
        timeStr,
        userName,
        action,
        locationStr,
        entry.notes ?? '',
        duration,
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  // Download CSV file in web browser
  void downloadCSV(String csvContent, String filename) {
    final bytes = csvContent.codeUnits;
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  // Get company attendance summary
  Future<Map<String, dynamic>> getCompanySummary(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot =
        await _db
            .collection('time_entries')
            .where('companyId', isEqualTo: companyId)
            .where('timestamp', isGreaterThanOrEqualTo: startDate)
            .where('timestamp', isLessThan: endDate)
            .get();

    final entries =
        snapshot.docs
            .map((doc) => TimeEntry.fromJson({...doc.data(), 'id': doc.id}))
            .toList();

    final workerIds = entries.map((e) => e.userId).toSet();
    int totalClockIns =
        entries.where((e) => e.type == TimeEntryType.clockIn).length;
    int totalClockOuts =
        entries.where((e) => e.type == TimeEntryType.clockOut).length;

    return {
      'totalWorkers': workerIds.length,
      'totalClockIns': totalClockIns,
      'totalClockOuts': totalClockOuts,
      'totalEntries': entries.length,
      'dateRange': {
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
    };
  }
}
