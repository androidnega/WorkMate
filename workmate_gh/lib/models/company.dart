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
  final Map<String, double>? coordinates; // {latitude: x, longitude: y}
  final double? locationRadius; // Radius in meters for location validation

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
    this.coordinates,
    this.locationRadius = 500.0, // Default 500 meters
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
      coordinates:
          data['coordinates'] != null
              ? Map<String, double>.from(data['coordinates'])
              : null,
      locationRadius: data['locationRadius']?.toDouble() ?? 500.0,
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
      'coordinates': coordinates,
      'locationRadius': locationRadius,
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
    Map<String, double>? coordinates,
    double? locationRadius,
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
      coordinates: coordinates ?? this.coordinates,
      locationRadius: locationRadius ?? this.locationRadius,
    );
  }
}
