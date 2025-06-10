class Company {
  final String id;
  final String name;
  final String location; // e.g. "Takoradi"
  final String address;
  final String? phone;
  final String? email;
  final String? managerId; // Assigned manager ID
  final DateTime createdAt;
  final bool isActive;
  final String adminId; // The admin who manages this company

  Company({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    this.phone,
    this.email,
    this.managerId,
    required this.createdAt,
    this.isActive = true,
    required this.adminId,
  });
  factory Company.fromMap(Map<String, dynamic> data, String id) {
    return Company(
      id: id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'],
      email: data['email'],
      managerId: data['managerId'],
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
      'location': location,
      'address': address,
      'phone': phone,
      'email': email,
      'managerId': managerId,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'adminId': adminId,
    };
  }
  Company copyWith({
    String? id,
    String? name,
    String? location,
    String? address,
    String? phone,
    String? email,
    String? managerId,
    DateTime? createdAt,
    bool? isActive,
    String? adminId,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      managerId: managerId ?? this.managerId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      adminId: adminId ?? this.adminId,
    );
  }
}
