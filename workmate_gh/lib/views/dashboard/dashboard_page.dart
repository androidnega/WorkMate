import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/views/dashboard/admin_dashboard.dart';
import 'package:workmate_gh/views/dashboard/manager_dashboard.dart';
import 'package:workmate_gh/views/dashboard/worker_dashboard.dart';

class DashboardPage extends StatefulWidget {
  final AppUser user;

  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.worker:
        return 'Worker';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WorkMate - ${_getRoleDisplayName(widget.user.role)}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _signOut();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(widget.user.name),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    switch (widget.user.role) {
      case UserRole.admin:
        return AdminDashboard(user: widget.user);
      case UserRole.manager:
        return ManagerDashboard(user: widget.user);
      case UserRole.worker:
        return WorkerDashboard(user: widget.user);
    }
  }
}
