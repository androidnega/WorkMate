import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmate_gh/core/theme.dart';
import 'package:workmate_gh/core/constants.dart';
import 'package:workmate_gh/views/auth/login_screen.dart';
import 'package:workmate_gh/views/auth/change_password_screen.dart';
import 'package:workmate_gh/services/auth_service.dart';
import 'package:workmate_gh/models/app_user.dart';
import 'package:workmate_gh/views/dashboard/dashboard_page.dart';

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const Wrapper();
        }

        return const LoginScreen();
      },
    );
  }
}

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final AuthService _authService = AuthService();

  void _showPasswordChangeDialog(AppUser user) {
    if (user.role == UserRole.worker && user.isDefaultPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => AlertDialog(
                title: const Text("Security Notice"),
                content: const Text(
                  "We recommend changing your password for security.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Later"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                    child: const Text("Change Now"),
                  ),
                ],
              ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _authService.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        _showPasswordChangeDialog(user);
        return DashboardPage(user: user);
      },
    );
  }
}
