import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/services/time_tracking_service.dart';

class WorkerDashboard extends StatefulWidget {
  final AppUser user;

  const WorkerDashboard({super.key, required this.user});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final TimeTrackingService _timeTrackingService = TimeTrackingService();
  bool _isClockedIn = false;
  DateTime? _lastClockTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final isClockedIn = await _timeTrackingService.isCurrentlyClockedIn();
      final latestEntry = await _timeTrackingService.getLatestTimeEntry();

      setState(() {
        _isClockedIn = isClockedIn;
        _lastClockTime = latestEntry?.timestamp;
      });
    } catch (e) {
      // Log error - consider using a proper logging framework in production
      // print('Error loading status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.user.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Worker Dashboard',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Clock In/Out Card
            Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      _isClockedIn ? Icons.work : Icons.work_off,
                      size: 64,
                      color: _isClockedIn ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isClockedIn ? 'Currently Working' : 'Not Working',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_lastClockTime != null)
                      Text(
                        _isClockedIn
                            ? 'Clocked in at ${_formatTime(_lastClockTime!)}'
                            : 'Last clocked out at ${_formatTime(_lastClockTime!)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _toggleClock,
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(_isClockedIn ? Icons.logout : Icons.login),
                      label: Text(
                        _isLoading
                            ? 'Processing...'
                            : (_isClockedIn ? 'Clock Out' : 'Clock In'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isClockedIn ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: MediaQuery.of(context).size.height - 400,
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    'My Timesheet',
                    'View your time tracking history',
                    Icons.history,
                    Colors.blue,
                    () {
                      // Navigate to timesheet screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Timesheet feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Schedule',
                    'View your work schedule',
                    Icons.calendar_today,
                    Colors.green,
                    () {
                      // Navigate to schedule screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Schedule feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Leave Requests',
                    'Request time off',
                    Icons.event_busy,
                    Colors.orange,
                    () {
                      // Navigate to leave requests screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Leave requests feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Profile',
                    'View and edit your profile',
                    Icons.person,
                    Colors.purple,
                    () {
                      // Navigate to profile screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile feature coming soon!'),
                        ),
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

  Future<void> _toggleClock() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isClockedIn) {
        await _timeTrackingService.clockOut();
        setState(() {
          _isClockedIn = false;
          _lastClockTime = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clocked Out Successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await _timeTrackingService.clockIn();
        setState(() {
          _isClockedIn = true;
          _lastClockTime = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clocked In Successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDashboardCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
