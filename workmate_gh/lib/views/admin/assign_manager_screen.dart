import 'package:flutter/material.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/models/company.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/services/company_service.dart';

class AssignManagerScreen extends StatefulWidget {
  final AppUser currentUser;

  const AssignManagerScreen({super.key, required this.currentUser});

  @override
  State<AssignManagerScreen> createState() => _AssignManagerScreenState();
}

class _AssignManagerScreenState extends State<AssignManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final CompanyService _companyService = CompanyService();

  List<Company> _companies = [];
  String? _selectedCompanyId;
  bool _isLoading = false;
  bool _isLoadingCompanies = true;

  // Ghana-inspired color palette
  static const Color _backgroundLight = Color(0xFFFBFEE7); // Light cream/yellow
  static const Color _primaryGreen = Color(0xFF10B981); // Emerald green
  static const Color _deepIndigo = Color(0xFF1E293B); // Deep indigo
  static const Color _ghanaRed = Color(0xFF5C2A2A); // Deep Ghanaian red/brown
  static const Color _cardWhite = Color(0xFFFFFFFF); // Pure white
  static const Color _textDark = Color(0xFF1F2937); // Dark text
  static const Color _textLight = Color(0xFF6B7280); // Light text
  static const Color _borderLight = Color(0xFFE5E7EB); // Light border

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _companyService.getAllCompanies();
      setState(() {
        _companies = companies;
        _isLoadingCompanies = false;
      });
    } catch (e) {
      setState(() => _isLoadingCompanies = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading companies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignManager() async {
    if (!_formKey.currentState!.validate() || _selectedCompanyId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.createManagerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        companyId: _selectedCompanyId!,
        createdBy: widget.currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Manager assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardWhite,
        foregroundColor: _textDark,
        title: const Text(
          'Assign Manager',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body:
          _isLoadingCompanies
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
                  strokeWidth: 3,
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderLight, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_add,
                                    color: _primaryGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assign New Manager',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create a manager account and assign to a company',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: _textLight,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Company Selection
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderLight, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.business,
                                  color: _primaryGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Company',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedCompanyId,
                              decoration: InputDecoration(
                                labelText: 'Company',
                                labelStyle: const TextStyle(color: _textLight),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _primaryGreen,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: _backgroundLight,
                                prefixIcon: const Icon(
                                  Icons.business,
                                  color: _textLight,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              hint: const Text(
                                'Choose a company',
                                style: TextStyle(color: _textLight),
                              ),
                              items:
                                  _companies.map((company) {
                                    return DropdownMenuItem<String>(
                                      value: company.id,
                                      child: Text(
                                        company.name,
                                        style: const TextStyle(
                                          color: _textDark,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCompanyId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a company';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Manager Details
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderLight, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: _primaryGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Manager Details',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: const TextStyle(color: _textLight),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _primaryGreen,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: _backgroundLight,
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: _textLight,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the manager\'s name';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: const TextStyle(color: _textLight),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _primaryGreen,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: _backgroundLight,
                                prefixIcon: const Icon(
                                  Icons.email,
                                  color: _textLight,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter an email address';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Temporary Password',
                                labelStyle: const TextStyle(color: _textLight),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _primaryGreen,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: _backgroundLight,
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: _textLight,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                helperText:
                                    'Manager will change this on first login',
                                helperStyle: const TextStyle(
                                  color: _textLight,
                                  fontSize: 12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _assignManager,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ghanaRed,
                            foregroundColor: _cardWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: _textLight,
                          ),
                          child:
                              _isLoading
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                _cardWhite,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Creating Manager...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                  : const Text(
                                    'Assign Manager',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Information Card
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _primaryGreen.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: _primaryGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Important Information',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '• Manager will receive login credentials via email\n'
                              '• Password must be changed on first login\n'
                              '• Manager can manage workers in assigned company\n'
                              '• Permissions can be modified later in settings',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textDark,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
