import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/services/company_service.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';

class ManagerDashboard extends StatefulWidget {
  final AppUser user;

  const ManagerDashboard({super.key, required this.user});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final CompanyService _companyService = CompanyService();
  List<AppUser> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _companyService.getWorkersByCompany(
        widget.user.companyId,
      );
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
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
                          Icons.dashboard,
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
                              'Manager Dashboard',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
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

                _isLoading
                    ? Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.successGreen,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    )
                    : GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildDashboardCard(
                          'Worker Management',
                          'Manage workers (${_workers.length})',
                          Icons.group,
                          AppTheme.successGreen,
                          () => _showWorkerManagement(),
                        ),
                        _buildDashboardCard(
                          'Create Worker',
                          'Add new worker to company',
                          Icons.person_add,
                          AppTheme.infoBlue,
                          () => _showCreateWorker(),
                        ),
                        _buildDashboardCard(
                          'Team Attendance',
                          'Monitor team time tracking',
                          Icons.access_time,
                          AppTheme.warningOrange,
                          () => _showTeamAttendance(),
                        ),
                        _buildDashboardCard(
                          'Team Reports',
                          'View team performance reports',
                          Icons.bar_chart,
                          Colors.purple.shade500,
                          () => _showTeamReports(),
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

  void _showWorkerManagement() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Worker Management'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Text('Workers in your company (${_workers.length})'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _workers.length,
                      itemBuilder: (context, index) {
                        final worker = _workers[index];
                        return ListTile(
                          title: Text(worker.name),
                          subtitle: Text(worker.email),
                          trailing:
                              worker.isActive
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : const Icon(Icons.cancel, color: Colors.red),
                          onTap: () => _editWorker(worker),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showCreateWorker() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create New Worker'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isNotEmpty &&
                      emailController.text.trim().isNotEmpty &&
                      passwordController.text.trim().isNotEmpty) {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      final authService = AuthService();
                      await authService.createWorkerUser(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        name: nameController.text.trim(),
                        companyId: widget.user.companyId,
                        createdBy: widget.user.uid,
                      );

                      if (mounted) {
                        navigator.pop();
                      }
                      _loadWorkers(); // Refresh workers list

                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Worker created successfully!'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error creating worker: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _showTeamAttendance() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Team Attendance'),
            content: const Text(
              'Team attendance monitoring will be implemented here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showTeamReports() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Team Reports'),
            content: const Text(
              'Team performance reports will be implemented here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _editWorker(AppUser worker) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${worker.name} will be implemented')),
    );
  }
}
