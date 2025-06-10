// This script creates test users for the WorkMate GH application
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

Future<void> createTestUsers() async {
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

  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;

  try {
    // Create Admin User
    print('Creating admin user...');
    final adminResult = await auth.createUserWithEmailAndPassword(
      email: 'admin@workmate-gh.com',
      password: 'AdminPass123!',
    );
    
    final adminUser = AppUser(
      uid: adminResult.user!.uid,
      email: 'admin@workmate-gh.com',
      name: 'System Administrator',
      role: UserRole.admin,
      companyId: 'admin',
      createdAt: DateTime.now(),
    );
    
    await db.collection('users').doc(adminResult.user!.uid).set(adminUser.toMap());
    print('Admin user created successfully!');
    
    // Sign out admin
    await auth.signOut();
    
    // Create Test Company
    print('Creating test company...');
    final companyRef = await db.collection('companies').add({
      'name': 'Accra Tech Solutions',
      'address': '123 Independence Avenue, Accra',
      'phone': '+233 20 123 4567',
      'email': 'info@accratech.com',
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': adminResult.user!.uid,
      'coordinates': {
        'latitude': 5.6037,
        'longitude': -0.1870,
      },
      'locationRadius': 500,
    });
    
    print('Test company created with ID: ${companyRef.id}');
    
    // Create Manager User
    print('Creating manager user...');
    final managerResult = await auth.createUserWithEmailAndPassword(
      email: 'manager@workmate-gh.com',
      password: 'ManagerPass123!',
    );
    
    final managerUser = AppUser(
      uid: managerResult.user!.uid,
      email: 'manager@workmate-gh.com',
      name: 'John Mensah',
      role: UserRole.manager,
      companyId: companyRef.id,
      createdAt: DateTime.now(),
      createdBy: adminResult.user!.uid,
    );
    
    await db.collection('users').doc(managerResult.user!.uid).set(managerUser.toMap());
    print('Manager user created successfully!');
    
    // Sign out manager
    await auth.signOut();
    
    // Create Worker User
    print('Creating worker user...');
    final workerResult = await auth.createUserWithEmailAndPassword(
      email: 'worker@workmate-gh.com',
      password: 'WorkerPass123!',
    );
    
    final workerUser = AppUser(
      uid: workerResult.user!.uid,
      email: 'worker@workmate-gh.com',
      name: 'Akosua Asante',
      role: UserRole.worker,
      companyId: companyRef.id,
      createdAt: DateTime.now(),
      createdBy: managerResult.user!.uid,
    );
    
    await db.collection('users').doc(workerResult.user!.uid).set(workerUser.toMap());
    print('Worker user created successfully!');
    
    print('\n=== TEST USERS CREATED ===');
    print('Admin: admin@workmate-gh.com / AdminPass123!');
    print('Manager: manager@workmate-gh.com / ManagerPass123!');
    print('Worker: worker@workmate-gh.com / WorkerPass123!');
    print('Company ID: ${companyRef.id}');
    
  } catch (e) {
    print('Error creating test users: $e');
  }
}

void main() async {
  await createTestUsers();
}
