// Quick test script to create admin user
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmate_gh/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAZUgDj3MVZnpVqOGcV45cnxWahBL0dioY",
      authDomain: "workmate-gh.firebaseapp.com",
      projectId: "workmate-gh",
      storageBucket: "workmate-gh.firebasestorage.app",
      messagingSenderId: "333207684567",
      appId: "1:333207684567:web:c04236d720a95da00e7792",
    ),
  );

  runApp(const CreateUserApp());
}

class CreateUserApp extends StatelessWidget {
  const CreateUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkMate GH Admin Setup',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C2A2A), // Ghana red/brown
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C2A2A),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
      ),
      home: const CreateUserScreen(),
    );
  }
}

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final AuthService _authService = AuthService();
  String _status = 'Ready to create initial admin user';
  bool _isLoading = false;
  bool _isCreated = false;

  Future<void> _createAdminUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating admin user...';
    });

    try {
      await _authService.registerAdminUser(
        'admin@workmate.com',
        'Admin123!',
        'Test Admin',
      );

      setState(() {
        _isCreated = true;
        _status = 'Admin user created successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error creating admin user: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive width
            final containerWidth =
                constraints.maxWidth > 600 ? 500.0 : constraints.maxWidth * 0.9;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  width: containerWidth,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo/Icon
                      Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'WorkMate GH Setup',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Create Initial Admin Account',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              _isCreated
                                  ? Colors.green.withOpacity(0.1)
                                  : Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _isCreated
                                    ? Colors.green.withOpacity(0.3)
                                    : Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _status,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            if (_isCreated) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Login Credentials:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text('Email: admin@workmate.com'),
                              const Text('Password: Admin123!'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading || _isCreated
                                  ? null
                                  : _createAdminUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    _isCreated
                                        ? 'Admin Created ✓'
                                        : 'Create Admin User',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
