class Company {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final bool isActive;
  final String adminId; // The admin who manages this company

  Company({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.email,
    required this.createdAt,
    this.isActive = true,
    required this.adminId,
  });

  factory Company.fromMap(Map<String, dynamic> data, String id) {
    return Company(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'],
      email: data['email'],
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: data['isActive'] ?? true,
      adminId: data['adminId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'adminId': adminId,
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    DateTime? createdAt,
    bool? isActive,
    String? adminId,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      adminId: adminId ?? this.adminId,
    );
  }
}
