import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/services/time_tracking_service.dart';
import 'package:workmate_gh/services/company_service.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';

class TeamAttendanceScreen extends StatefulWidget {
  final AppUser manager;

  const TeamAttendanceScreen({super.key, required this.manager});

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  final TimeTrackingService _timeTrackingService = TimeTrackingService();
  final CompanyService _companyService = CompanyService();
  
  List<AppUser> _workers = [];
  Map<String, bool> _workerClockStatus = {};
  Map<String, TimeEntry?> _latestEntries = {};
  Map<String, bool> _workerBreakStatus = {};
  Map<String, Duration> _dailyBreakTime = {};
  bool _isLoading = true;
  
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }
  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load workers for this manager's company
      final workers = await _companyService.getWorkersByCompany(widget.manager.companyId);
      
      final workerClockStatus = <String, bool>{};
      final latestEntries = <String, TimeEntry?>{};
      final workerBreakStatus = <String, bool>{};
      final dailyBreakTime = <String, Duration>{};
      
      // Get attendance status for each worker
      for (final worker in workers) {
        // Get today's entries for the worker
        final todayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        
        final entries = await _timeTrackingService.getTimeEntries(
          startDate: todayStart,
          endDate: todayEnd,
          userId: worker.uid,
        );
        
        // Check if currently clocked in by looking at the latest entry
        bool isClockedIn = false;
        TimeEntry? latestEntry;
        bool isOnBreak = false;
        Duration totalBreakTime = Duration.zero;
        
        if (entries.isNotEmpty) {
          latestEntry = entries.first; // Latest entry (list is ordered by timestamp desc)
          isClockedIn = latestEntry.type == TimeEntryType.clockIn;
          
          // Check if on break (only if clocked in)
          if (isClockedIn) {
            final currentBreak = await _timeTrackingService.getCurrentBreak(latestEntry.id);
            isOnBreak = currentBreak != null;
          }
          
          // Calculate total break time for the day
          for (final entry in entries) {
            if (entry.type == TimeEntryType.clockIn) {
              final breaks = await _timeTrackingService.getBreaksForTimeEntry(entry.id);
              for (final breakRecord in breaks) {
                totalBreakTime += breakRecord.duration;
              }
            }
          }
        }
        
        workerClockStatus[worker.uid] = isClockedIn;
        latestEntries[worker.uid] = latestEntry;
        workerBreakStatus[worker.uid] = isOnBreak;
        dailyBreakTime[worker.uid] = totalBreakTime;
      }
      
      setState(() {
        _workers = workers;
        _workerClockStatus = workerClockStatus;
        _latestEntries = latestEntries;
        _workerBreakStatus = workerBreakStatus;
        _dailyBreakTime = dailyBreakTime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance data: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAttendanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(_selectedDate);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardWhite,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'Team Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
          ),
          if (isToday)
            IconButton(
              onPressed: _loadAttendanceData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successGreen),
                strokeWidth: 3,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.today, color: AppTheme.successGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Today\'s Attendance' : 'Attendance for',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                    // Attendance Summary
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildSummaryCard(
                        'Total Workers',
                        '${_workers.length}',
                        Icons.group,
                        AppTheme.infoBlue,
                      ),
                      _buildSummaryCard(
                        'Present',
                        '${_getPresentCount()}',
                        Icons.check_circle,
                        AppTheme.successGreen,
                      ),
                      _buildSummaryCard(
                        'On Break',
                        '${_getOnBreakCount()}',
                        Icons.pause_circle,
                        Colors.orange.shade500,
                      ),
                      _buildSummaryCard(
                        'Absent',
                        '${_getAbsentCount()}',
                        Icons.cancel,
                        Colors.red.shade500,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Worker Attendance List
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(Icons.list_alt, color: AppTheme.successGreen, size: 20),
                              const SizedBox(width: 12),
                              const Text(
                                'Individual Attendance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.borderLight),
                        
                        if (_workers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.group_off, size: 48, color: AppTheme.textLight),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No workers found',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _workers.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderLight),                            itemBuilder: (context, index) {
                              final worker = _workers[index];
                              final isClockedIn = _workerClockStatus[worker.uid] ?? false;
                              final latestEntry = _latestEntries[worker.uid];
                              final isOnBreak = _workerBreakStatus[worker.uid] ?? false;
                              final breakTime = _dailyBreakTime[worker.uid] ?? Duration.zero;
                              
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isClockedIn ? AppTheme.successGreen : AppTheme.textLight).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isClockedIn ? Icons.work : Icons.work_off,
                                    color: isClockedIn ? AppTheme.successGreen : AppTheme.textLight,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        worker.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isOnBreak)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.pause, color: Colors.orange.shade700, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Break',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(worker.email, style: const TextStyle(color: AppTheme.textSecondary)),
                                    const SizedBox(height: 4),
                                    if (latestEntry != null)
                                      Text(
                                        '${isClockedIn ? "Clocked in" : "Last activity"} at ${_formatTime(latestEntry.timestamp)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                      )
                                    else
                                      Text(
                                        'No activity today',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                      ),
                                    if (breakTime.inMinutes > 0)
                                      Text(
                                        'Break time: ${_formatDuration(breakTime)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                      ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isClockedIn ? AppTheme.successGreen.withOpacity(0.1) : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isClockedIn ? AppTheme.successGreen.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    isClockedIn ? 'Present' : 'Absent',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isClockedIn ? AppTheme.successGreen : Colors.red.shade600,
                                    ),
                                  ),
                                ),                                onTap: () => _showWorkerDetails(worker),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showWorkerDetails(AppUser worker) async {
    // Get today's entries for detailed view
    final todayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    final entries = await _timeTrackingService.getTimeEntries(
      startDate: todayStart,
      endDate: todayEnd,
      userId: worker.uid,
    );
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person, color: AppTheme.successGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Attendance Details',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderLight),
              
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time_outlined, size: 48, color: AppTheme.textLight),
                            const SizedBox(height: 16),
                            Text(
                              'No activity for this day',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isClockIn = entry.type == TimeEntryType.clockIn;
                          
                          return Card(
                            elevation: 0,
                            color: AppTheme.backgroundLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isClockIn ? AppTheme.successGreen : Colors.orange).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isClockIn ? Icons.login : Icons.logout,
                                  color: isClockIn ? AppTheme.successGreen : Colors.orange,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                isClockIn ? 'Clocked In' : 'Clocked Out',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(_formatTime(entry.timestamp)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  int _getPresentCount() {
    return _workerClockStatus.values.where((status) => status).length;
  }

  int _getOnBreakCount() {
    return _workerBreakStatus.values.where((status) => status).length;
  }

  int _getAbsentCount() {
    return _workers.length - _getPresentCount();
  }

  int _getOnBreakCount() {
    return _workerBreakStatus.values.where((status) => status).length;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
