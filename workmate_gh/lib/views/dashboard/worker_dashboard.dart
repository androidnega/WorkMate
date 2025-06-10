import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/services/time_tracking_service.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';
import 'package:workmate_gh/widgets/break_button.dart';

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
  bool _isOnBreak = false;
  String? _currentTimeEntryId;
  String? _currentBreakId;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final isClockedIn = await _timeTrackingService.isCurrentlyClockedIn();
      final latestEntry = await _timeTrackingService.getLatestTimeEntry();

      bool isOnBreak = false;
      String? currentBreakId;

      if (isClockedIn && latestEntry != null) {
        isOnBreak = await _timeTrackingService.isCurrentlyOnBreak();
        if (isOnBreak) {
          final currentBreak = await _timeTrackingService.getCurrentBreak(
            latestEntry.id,
          );
          currentBreakId = currentBreak?.id;
        }
      }

      setState(() {
        _isClockedIn = isClockedIn;
        _lastClockTime = latestEntry?.timestamp;
        _isOnBreak = isOnBreak;
        _currentTimeEntryId = latestEntry?.id;
        _currentBreakId = currentBreakId;
      });
    } catch (e) {
      // Log error - consider using a proper logging framework in production
      // print('Error loading status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: AppTheme.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${widget.user.name}',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Worker Dashboard',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Clock In/Out Card - Enhanced Design
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderLight, width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (_isClockedIn
                                  ? AppTheme.successGreen
                                  : AppTheme.textLight)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _isClockedIn ? Icons.work : Icons.work_off,
                          size: 64,
                          color:
                              _isClockedIn
                                  ? AppTheme.successGreen
                                  : AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isClockedIn ? 'Currently Working' : 'Not Working',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_lastClockTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isClockedIn
                                ? 'Clocked in at ${_formatTime(_lastClockTime!)}'
                                : 'Last clocked out at ${_formatTime(_lastClockTime!)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Status indicator for break
                      if (_isOnBreak)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause,
                                color: Colors.orange.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Currently on break',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isOnBreak) const SizedBox(height: 16),

                      // Clock In/Out Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _toggleClock,
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Icon(
                                    _isClockedIn ? Icons.logout : Icons.login,
                                    size: 20,
                                  ),
                          label: Text(
                            _isLoading
                                ? 'Processing...'
                                : (_isClockedIn ? 'Clock Out' : 'Clock In'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isClockedIn
                                    ? Colors.red.shade500
                                    : AppTheme.successGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: AppTheme.textLight,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Break Button
                      BreakButton(
                        isOnBreak: _isOnBreak,
                        isClockedIn: _isClockedIn,
                        currentTimeEntryId: _currentTimeEntryId,
                        currentBreakId: _currentBreakId,
                        onBreakStateChanged: _loadCurrentStatus,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildDashboardCard(
                      'My Timesheet',
                      'View your time tracking history',
                      Icons.history,
                      AppTheme.infoBlue,
                      () {
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
                      AppTheme.successGreen,
                      () {
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
                      AppTheme.warningOrange,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Leave requests feature coming soon!',
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      'Profile',
                      'View and edit your profile',
                      Icons.person,
                      Colors.purple.shade500,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile feature coming soon!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final authService = AuthService();
      await authService.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleClock() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isClockedIn) {
        await _timeTrackingService.clockOut();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clocked In Successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refresh status after clock operation
      await _loadCurrentStatus();
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        Color backgroundColor = Colors.red;

        // Handle location-related errors with warning color
        if (errorMessage.contains('Location unavailable') ||
            errorMessage.contains('within') ||
            errorMessage.contains('location')) {
          backgroundColor = Colors.orange;

          // Show location warning dialog for location issues
          if (errorMessage.contains('within')) {
            _showLocationWarningDialog(errorMessage);
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
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

  void _showLocationWarningDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.location_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('Location Warning'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 16),
                const Text(
                  'Please ensure you are at your workplace location to clock in.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleClock(); // Retry clock in
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
    );
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
