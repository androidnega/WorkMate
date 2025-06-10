import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/models/company.dart';
import 'package:workmate_gh/services/company_service.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/views/admin/assign_manager_screen.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final CompanyService _companyService = CompanyService();
  List<Company> _companies = [];
  List<AppUser> _managers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final companies = await _companyService.getAllCompanies();
      // Get all managers across all companies
      final allManagers = <AppUser>[];
      for (final company in companies) {
        final companyManagers = await _companyService.getManagersByCompany(
          company.id,
        );
        allManagers.addAll(companyManagers);
      }
      setState(() {
        _companies = companies;
        _managers = allManagers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
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
                          Icons.admin_panel_settings,
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
                              'Administrator Dashboard',
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
                    )                    : GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildDashboardCard(
                          'Company Management',
                          'Manage companies (${_companies.length})',
                          Icons.business,
                          AppTheme.infoBlue,
                          () => _showCompanyManagement(),
                        ),
                        _buildDashboardCard(
                          'Manager Assignment',
                          'Assign managers to companies (${_managers.length})',
                          Icons.people,
                          AppTheme.successGreen,
                          () => _showManagerManagement(),
                        ),
                        _buildDashboardCard(
                          'System Reports',
                          'View system-wide reports',
                          Icons.assessment,
                          Colors.purple.shade500,
                          () => _showSystemReports(),
                        ),
                        _buildDashboardCard(
                          'User Management',
                          'Manage all system users',
                          Icons.group,
                          AppTheme.warningOrange,
                          () => _showUserManagement(),
                        ),
                        _buildDashboardCard(
                          'Firebase Diagnostic',
                          'Debug Firestore connection issues',
                          Icons.bug_report,
                          Colors.red.shade500,
                          () => _showFirestoreDiagnostic(),
                        ),
                        _buildDashboardCard(
                          'System Status',
                          'Check system health',
                          Icons.health_and_safety,
                          Colors.green.shade500,
                          () => _showSystemStatus(),
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
                const SizedBox(height: 8),                Text(
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

  void _showCompanyManagement() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Company Management'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Companies (${_companies.length})')),
                      ElevatedButton(
                        onPressed: _createNewCompany,
                        child: const Text('Add Company'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _companies.length,
                      itemBuilder: (context, index) {
                        final company = _companies[index];
                        return ListTile(
                          title: Text(company.name),
                          subtitle: Text(company.address),
                          trailing:
                              company.isActive
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : const Icon(Icons.cancel, color: Colors.red),
                          onTap: () => _editCompany(company),
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

  void _showManagerManagement() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Manager Management'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Managers (${_managers.length})')),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close the dialog first
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AssignManagerScreen(
                                    currentUser: widget.user,
                                  ),
                            ),
                          );
                          if (result == true) {
                            // Refresh data if manager was created successfully
                            _loadData();
                          }
                        },
                        child: const Text('Add Manager'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _managers.length,
                      itemBuilder: (context, index) {
                        final manager = _managers[index];
                        return ListTile(
                          title: Text(manager.name),
                          subtitle: Text(
                            '${manager.email}\nCompany: ${manager.companyId}',
                          ),
                          trailing:
                              manager.isActive
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : const Icon(Icons.cancel, color: Colors.red),
                          isThreeLine: true,
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

  void _showSystemReports() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('System Reports'),
            content: const Text(
              'System-wide reporting functionality will be implemented here.',
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

  void _showUserManagement() async {
    try {
      // Get all users from all companies
      final allUsers = <AppUser>[];
      for (final company in _companies) {
        final companyUsers = await _companyService.getUsersByCompany(
          company.id,
        );
        allUsers.addAll(companyUsers);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('User Management'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      Text('Total Users: ${allUsers.length}'),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allUsers.length,
                          itemBuilder: (context, index) {
                            final user = allUsers[index];
                            return ListTile(
                              title: Text(user.name),
                              subtitle: Text(
                                '${user.email}\nRole: ${user.role.name}\nCompany: ${user.companyId}',
                              ),
                              trailing:
                                  user.isActive
                                      ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                      : const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      ),
                              isThreeLine: true,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  void _createNewCompany() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create New Company'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
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
                      addressController.text.trim().isNotEmpty) {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await _companyService.createCompany(
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        phone:
                            phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                        email:
                            emailController.text.trim().isEmpty
                                ? null
                                : emailController.text.trim(),
                      );
                      if (mounted) {
                        navigator.pop();
                        navigator.pop(); // Close parent dialog
                      }
                      _loadData(); // Refresh data

                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Company created successfully!'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error creating company: $e')),
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

  void _editCompany(Company company) {
    // Navigate to company editing screen
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit ${company.name} feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  void _showFirestoreDiagnostic() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Running Firestore Diagnostic...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking Firestore connection and identifying issues...'),
          ],
        ),
      ),
    );

    final results = <String>[];
    
    try {
      // Test basic Firestore connection
      results.add('🔍 Testing Firestore connection...');
      
      final firestore = FirebaseFirestore.instance;
      results.add('✅ Firestore instance created');
        // Test reading from collections
      try {
        await firestore.collection('_test').limit(1).get();
        results.add('✅ Basic read operation successful');
      } catch (e) {
        results.add('❌ Read operation failed: $e');
        if (e.toString().contains('400')) {
          results.add('🎯 This is your 400 error!');
          results.add('   Likely causes:');
          results.add('   • Firestore security rules blocking access');
          results.add('   • Invalid project configuration');
          results.add('   • Network connectivity issues');
        }
      }
      
      // Test authentication
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        results.add('✅ User authenticated: ${auth.currentUser!.email}');
      } else {
        results.add('⚠️  No user authenticated');
      }
      
      // Test collections
      try {
        await _companyService.getAllCompanies();
        results.add('✅ Company service working');
      } catch (e) {
        results.add('❌ Company service failed: $e');
      }
      
    } catch (e) {
      results.add('❌ Fatal error: $e');
    }

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Firestore Diagnostic Results'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: results.map((result) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: result.startsWith('❌') ? Colors.red :
                             result.startsWith('⚠️') ? Colors.orange :
                             result.startsWith('✅') ? Colors.green :
                             null,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (results.any((r) => r.contains('400') || r.contains('❌')))
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFirestoreTroubleshooting();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Solutions'),
              ),
          ],
        ),
      );
    }
  }

  void _showSystemStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusItem('Firebase Connection', true),
            _buildStatusItem('Firestore Database', true),
            _buildStatusItem('Authentication', true),
            _buildStatusItem('Companies Loaded', _companies.isNotEmpty),
            _buildStatusItem('Managers Loaded', _managers.isNotEmpty),
            const SizedBox(height: 16),
            const Text(
              'If you\'re experiencing issues, use the "Firebase Diagnostic" tool to identify problems.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showFirestoreDiagnostic();
            },
            icon: const Icon(Icons.bug_report),
            label: const Text('Run Diagnostic'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _showFirestoreTroubleshooting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firestore Troubleshooting'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Common Solutions for Firestore 400 Errors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Firestore Security Rules'),
              Text(
                '   • Go to Firebase Console > Firestore > Rules\n'
                '   • Temporarily use: allow read, write: if true;\n'
                '   • Publish rules and test again',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              SizedBox(height: 12),
              Text('2. Project Configuration'),
              Text(
                '   • Verify project ID in Firebase config\n'
                '   • Check API keys are correct\n'
                '   • Ensure web app is configured in Firebase',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              SizedBox(height: 12),
              Text('3. Network Issues'),
              Text(
                '   • Check internet connection\n'
                '   • Disable VPN/proxy temporarily\n'
                '   • Try different network',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              SizedBox(height: 12),
              Text('4. Browser Issues'),
              Text(
                '   • Clear browser cache\n'
                '   • Disable browser extensions\n'
                '   • Try incognito/private mode',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showFirestoreDiagnostic();
            },
            child: const Text('Run Diagnostic Again'),
          ),
        ],
      ),
    );
  }
}
