import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/models/company.dart';
import 'package:workmate_gh/services/company_service.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';

class CompanyManagementScreen extends StatefulWidget {
  final AppUser currentUser;

  const CompanyManagementScreen({super.key, required this.currentUser});

  @override
  State<CompanyManagementScreen> createState() =>
      _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  final CompanyService _companyService = CompanyService();
  final TextEditingController _searchController = TextEditingController();

  List<Company> _companies = [];
  List<AppUser> _availableManagers = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadAvailableManagers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _companies.clear();
        _lastDocument = null;
        _hasMore = true;
        _isLoading = true;
      });
    } else if (_isLoading || _isLoadingMore) {
      return;
    }

    setState(() {
      if (_companies.isEmpty) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await _companyService.getCompaniesPaginated(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        lastDocument: refresh ? null : _lastDocument,
        limit: _pageSize,
      );

      final newCompanies = result['companies'] as List<Company>;

      setState(() {
        if (refresh) {
          _companies = newCompanies;
        } else {
          _companies.addAll(newCompanies);
        }
        _lastDocument = result['lastDocument'] as DocumentSnapshot?;
        _hasMore = result['hasMore'] as bool;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading companies: $e')));
      }
    }
  }

  Future<void> _loadAvailableManagers() async {
    try {
      final managers = await _companyService.getAvailableManagers();
      setState(() {
        _availableManagers = managers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading managers: $e')));
      }
    }
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    _loadCompanies(refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _loadCompanies(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardWhite,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'Company Management',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadCompanies(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCompanyDialog,
        backgroundColor: AppTheme.successGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Company',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.cardWhite,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by company name or location...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.textLight,
                      ),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppTheme.textLight,
                                ),
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.successGreen,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundLight,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results Summary
          if (_searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.backgroundLight,
              child: Text(
                'Search results for "${_searchQuery}" - ${_companies.length} companies found',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Companies List
          Expanded(
            child:
                _isLoading && _companies.isEmpty
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.successGreen,
                        ),
                      ),
                    )
                    : _companies.isEmpty
                    ? _buildEmptyState()
                    : _buildCompaniesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.business_outlined,
            size: 64,
            color: AppTheme.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No companies found matching "${_searchQuery}"'
                : 'No companies found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first company to get started',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompaniesList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoadingMore &&
            _hasMore &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadCompanies();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _companies.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _companies.length) {
            // Loading indicator for pagination
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.successGreen,
                ),
              ),
            );
          }

          final company = _companies[index];
          return _buildCompanyCard(company);
        },
      ),
    );
  }

  Widget _buildCompanyCard(Company company) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: const Icon(
                    Icons.business,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppTheme.textLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            company.location,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleCompanyAction(value, company),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign_manager',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 18),
                              SizedBox(width: 8),
                              Text('Assign Manager'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Company Details
            _buildCompanyDetail(
              Icons.location_city,
              'Address',
              company.address,
            ),
            if (company.phone != null)
              _buildCompanyDetail(Icons.phone, 'Phone', company.phone!),
            if (company.email != null)
              _buildCompanyDetail(Icons.email, 'Email', company.email!),

            const SizedBox(height: 16),

            // Manager Assignment Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    company.managerId != null
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      company.managerId != null
                          ? AppTheme.successGreen.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    company.managerId != null
                        ? Icons.check_circle
                        : Icons.warning,
                    color:
                        company.managerId != null
                            ? AppTheme.successGreen
                            : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      company.managerId != null
                          ? 'Manager Assigned'
                          : 'No Manager Assigned',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            company.managerId != null
                                ? AppTheme.successGreen
                                : Colors.orange,
                      ),
                    ),
                  ),
                  if (company.managerId != null)
                    FutureBuilder<AppUser?>(
                      future: _companyService.getManagerById(
                        company.managerId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            snapshot.data!.name,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCompanyAction('edit', company),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                      side: const BorderSide(color: AppTheme.successGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _handleCompanyAction('assign_manager', company),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text(
                      company.managerId != null
                          ? 'Change Manager'
                          : 'Assign Manager',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCompanyAction(String action, Company company) {
    switch (action) {
      case 'edit':
        _showEditCompanyDialog(company);
        break;
      case 'assign_manager':
        _showAssignManagerDialog(company);
        break;
      case 'delete':
        _showDeleteCompanyDialog(company);
        break;
    }
  }

  void _showAddCompanyDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppTheme.cardWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              height: 600,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
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
                          child: const Icon(
                            Icons.business,
                            color: AppTheme.successGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Add New Company',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildFormField(
                              controller: nameController,
                              label: 'Company Name',
                              icon: Icons.business,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Company name is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: locationController,
                              label: 'Location (e.g., Takoradi)',
                              icon: Icons.location_on,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Location is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: addressController,
                              label: 'Full Address',
                              icon: Icons.location_city,
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Address is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: phoneController,
                              label: 'Phone Number (Optional)',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: emailController,
                              label: 'Email Address (Optional)',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(
                                color: AppTheme.borderLight,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => _createCompany(
                                  context,
                                  formKey,
                                  nameController,
                                  locationController,
                                  addressController,
                                  phoneController,
                                  emailController,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Create Company'),
                          ),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.successGreen, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.backgroundLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _createCompany(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController nameController,
    TextEditingController locationController,
    TextEditingController addressController,
    TextEditingController phoneController,
    TextEditingController emailController,
  ) async {
    if (!formKey.currentState!.validate()) return;

    try {
      await _companyService.createCompany(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company created successfully!')),
        );
        _loadCompanies(refresh: true);
        _loadAvailableManagers(); // Refresh available managers
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating company: $e')));
      }
    }
  }

  void _showEditCompanyDialog(Company company) {
    final nameController = TextEditingController(text: company.name);
    final locationController = TextEditingController(text: company.location);
    final addressController = TextEditingController(text: company.address);
    final phoneController = TextEditingController(text: company.phone ?? '');
    final emailController = TextEditingController(text: company.email ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppTheme.cardWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              height: 600,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
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
                          child: const Icon(
                            Icons.edit,
                            color: AppTheme.successGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Edit Company',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildFormField(
                              controller: nameController,
                              label: 'Company Name',
                              icon: Icons.business,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Company name is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: locationController,
                              label: 'Location',
                              icon: Icons.location_on,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Location is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: addressController,
                              label: 'Full Address',
                              icon: Icons.location_city,
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Address is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: phoneController,
                              label: 'Phone Number (Optional)',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),

                            const SizedBox(height: 16),

                            _buildFormField(
                              controller: emailController,
                              label: 'Email Address (Optional)',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(
                                color: AppTheme.borderLight,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => _updateCompany(
                                  context,
                                  formKey,
                                  company,
                                  nameController,
                                  locationController,
                                  addressController,
                                  phoneController,
                                  emailController,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Update Company'),
                          ),
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

  Future<void> _updateCompany(
    BuildContext context,
    GlobalKey<FormState> formKey,
    Company company,
    TextEditingController nameController,
    TextEditingController locationController,
    TextEditingController addressController,
    TextEditingController phoneController,
    TextEditingController emailController,
  ) async {
    if (!formKey.currentState!.validate()) return;

    try {
      final updatedCompany = company.copyWith(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
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

      await _companyService.updateCompany(updatedCompany);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company updated successfully!')),
        );
        _loadCompanies(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating company: $e')));
      }
    }
  }

  void _showAssignManagerDialog(Company company) {
    showDialog(
      context: context,
      builder:
          (context) => ManagerAssignmentDialog(
            company: company,
            availableManagers: _availableManagers,
            companyService: _companyService,
            onManagerAssigned: () {
              _loadCompanies(refresh: true);
              _loadAvailableManagers();
            },
          ),
    );
  }

  void _showDeleteCompanyDialog(Company company) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Company'),
            content: Text(
              'Are you sure you want to delete "${company.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _deleteCompany(context, company),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCompany(BuildContext context, Company company) async {
    try {
      await _companyService.deactivateCompany(company.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company deleted successfully!')),
        );
        _loadCompanies(refresh: true);
        _loadAvailableManagers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting company: $e')));
      }
    }
  }
}

class ManagerAssignmentDialog extends StatefulWidget {
  final Company company;
  final List<AppUser> availableManagers;
  final CompanyService companyService;
  final VoidCallback onManagerAssigned;

  const ManagerAssignmentDialog({
    super.key,
    required this.company,
    required this.availableManagers,
    required this.companyService,
    required this.onManagerAssigned,
  });

  @override
  State<ManagerAssignmentDialog> createState() =>
      _ManagerAssignmentDialogState();
}

class _ManagerAssignmentDialogState extends State<ManagerAssignmentDialog> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedManagerId;
  List<AppUser> _filteredManagers = [];
  bool _isLoading = false;
  AppUser? _currentManager;

  @override
  void initState() {
    super.initState();
    _filteredManagers = widget.availableManagers;
    _loadCurrentManager();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentManager() async {
    if (widget.company.managerId != null) {
      try {
        final manager = await widget.companyService.getManagerById(
          widget.company.managerId!,
        );
        setState(() {
          _currentManager = manager;
        });
      } catch (e) {
        // Handle error
      }
    }
  }

  void _filterManagers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredManagers = widget.availableManagers;
      } else {
        _filteredManagers =
            widget.availableManagers
                .where(
                  (manager) =>
                      manager.name.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      manager.email.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
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
                  child: const Icon(
                    Icons.person_add,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign Manager',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'for ${widget.company.name}',
                        style: const TextStyle(color: AppTheme.textSecondary),
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

            const SizedBox(height: 24),

            // Current Manager (if any)
            if (_currentManager != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Manager',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentManager!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_currentManager!.email)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _removeCurrentManager,
                        icon: const Icon(Icons.person_remove, size: 16),
                        label: const Text('Remove Manager'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Or assign a new manager:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _filterManagers,
              decoration: InputDecoration(
                hintText: 'Search managers...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.successGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Available Managers List
            Expanded(
              child:
                  _filteredManagers.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.availableManagers.isEmpty
                                  ? Icons.person_off
                                  : Icons.search_off,
                              size: 48,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.availableManagers.isEmpty
                                  ? 'No available managers'
                                  : 'No managers found',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (widget.availableManagers.isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'All managers are already assigned to companies',
                                style: TextStyle(color: AppTheme.textLight),
                              ),
                            ],
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: _filteredManagers.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final manager = _filteredManagers[index];
                          final isSelected = _selectedManagerId == manager.uid;

                          return Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppTheme.successGreen.withOpacity(0.1)
                                      : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppTheme.successGreen
                                        : AppTheme.borderLight,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  _selectedManagerId =
                                      isSelected ? null : manager.uid;
                                });
                              },
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isSelected
                                          ? AppTheme.successGreen
                                          : AppTheme.textLight)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color:
                                      isSelected
                                          ? AppTheme.successGreen
                                          : AppTheme.textLight,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                manager.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(manager.email),
                              trailing:
                                  isSelected
                                      ? const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.successGreen,
                                      )
                                      : null,
                            ),
                          );
                        },
                      ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _selectedManagerId != null && !_isLoading
                            ? _assignManager
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
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
                            : const Text('Assign Manager'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignManager() async {
    if (_selectedManagerId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.companyService.assignManagerToCompany(
        widget.company.id,
        _selectedManagerId!,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager assigned successfully!')),
        );
        widget.onManagerAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error assigning manager: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeCurrentManager() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.companyService.removeManagerFromCompany(widget.company.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager removed successfully!')),
        );
        widget.onManagerAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing manager: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
