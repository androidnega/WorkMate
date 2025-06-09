enum UserRole {
  admin, // Can manage all companies and assign managers
  manager, // Assigned by admin, manages workers for their company
  worker, // Registered by manager, can clock in/out
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String
  companyId; // For admin: can be empty or "admin", for manager/worker: specific company ID
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isDefaultPassword; // Track if user has default password
  final String?
  createdBy; // Who created this user (admin uid for managers, manager uid for workers)
  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isDefaultPassword = true, // Default to true for new users
    this.createdBy,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.worker,
      ),
      companyId: data['companyId'] ?? '',
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      lastLoginAt:
          data['lastLoginAt'] != null
              ? DateTime.parse(data['lastLoginAt'])
              : null,
      isActive: data['isActive'] ?? true,
      isDefaultPassword: data['isDefaultPassword'] ?? true,
      createdBy: data['createdBy'],
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'companyId': companyId,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'isDefaultPassword': isDefaultPassword,
      'createdBy': createdBy,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    UserRole? role,
    String? companyId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isDefaultPassword,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isDefaultPassword: isDefaultPassword ?? this.isDefaultPassword,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Helper methods
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isWorker => role == UserRole.worker;

  bool canManageUser(AppUser other) {
    if (isAdmin) return true; // Admin can manage all users
    if (isManager && other.isWorker && other.companyId == companyId)
      return true;
    return false;
  }
}
