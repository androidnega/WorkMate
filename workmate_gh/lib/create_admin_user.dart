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
      title: 'Create Test User',
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
  String _status = 'Ready to create admin user';
  bool _isLoading = false;

  Future<void> _createAdminUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating admin user...';
    });

    try {
      final user = await _authService.registerAdminUser(
        'admin@workmate.com',
        'Admin123!',
        'Test Admin',
      );

      setState(() {
        _status =
            'Admin user created successfully!\nEmail: admin@workmate.com\nPassword: Admin123!';
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
      appBar: AppBar(title: const Text('Create Test User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _createAdminUser,
              child: const Text('Create Admin User'),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
