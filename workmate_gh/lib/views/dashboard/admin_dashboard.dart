import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/models/company.dart';
import 'package:workmate_gh/services/company_service.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/views/admin/assign_manager_screen.dart';

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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.user.name}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Administrator Dashboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                )
                : SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildDashboardCard(
                        'Company Management',
                        'Manage companies (${_companies.length})',
                        Icons.business,
                        Colors.blue,
                        () => _showCompanyManagement(),
                      ),
                      _buildDashboardCard(
                        'Manager Assignment',
                        'Assign managers to companies (${_managers.length})',
                        Icons.people,
                        Colors.green,
                        () => _showManagerManagement(),
                      ),
                      _buildDashboardCard(
                        'System Reports',
                        'View system-wide reports',
                        Icons.assessment,
                        Colors.purple,
                        () => _showSystemReports(),
                      ),
                      _buildDashboardCard(
                        'User Management',
                        'Manage all system users',
                        Icons.group,
                        Colors.orange,
                        () => _showUserManagement(),
                      ),
                    ],
                  ),
                ),
          ],
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
      builder: (context) => AlertDialog(
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
                          builder: (context) => AssignManagerScreen(
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
    );  }

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
}
