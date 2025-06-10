import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;

class Company {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? email;
  final String adminId;
  String? managerId;  // Made mutable for manager assignment
  final Map<String, double>? coordinates;
  final double? locationRadius;
  final String? logoUrl;
  final Map<String, String> workSchedule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Company({
    required this.id,
    required this.name,
    required this.address,
    required this.adminId,
    this.managerId,
    this.phone,
    this.email,
    this.coordinates,
    this.locationRadius = 500.0,
    this.logoUrl,
    Map<String, String>? workSchedule,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  }) : workSchedule = workSchedule ?? {
    'monday': '08:30-17:30',
    'tuesday': '08:30-17:30',
    'wednesday': '08:30-17:30',
    'thursday': '08:30-17:30',
    'friday': '08:30-17:30',
  };

  factory Company.fromMap(Map<String, dynamic> map, String docId) {
    return Company(
      id: docId,
      name: map['name'] as String,
      address: map['address'] as String,
      adminId: map['adminId'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      coordinates:
          map['coordinates'] != null
              ? Map<String, double>.from(map['coordinates'])
              : null,
      locationRadius: map['locationRadius'] as double?,
      logoUrl: map['logoUrl'] as String?,
      workSchedule:
          map['workSchedule'] != null
              ? Map<String, String>.from(map['workSchedule'])
              : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'adminId': adminId,
      'phone': phone,
      'email': email,
      'coordinates': coordinates,
      'locationRadius': locationRadius,
      'logoUrl': logoUrl,
      'workSchedule': workSchedule,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  // Get work hours for a specific day
  WorkHours? getWorkHoursForDay(String day) {
    final schedule = workSchedule[day.toLowerCase()];
    if (schedule == null) return null;

    final parts = schedule.split('-');
    if (parts.length != 2) return null;

    final startParts = parts[0].split(':');
    final endParts = parts[1].split(':');

    if (startParts.length != 2 || endParts.length != 2) return null;

    try {
      return WorkHours(
        start: TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        ),
        end: TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // Check if a given time is within work hours
  bool isWithinWorkHours(DateTime time) {
    final dayName = _getDayName(time.weekday).toLowerCase();
    final workHours = getWorkHoursForDay(dayName);
    if (workHours == null) return false;

    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    return timeOfDay.isAfterOrEqual(workHours.start) &&
        timeOfDay.isBeforeOrEqual(workHours.end);
  }

  // Get day name from weekday number
  String _getDayName(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  Company copyWith({
    String? name,
    String? address,
    String? adminId,
    String? phone,
    String? email,
    Map<String, double>? coordinates,
    double? locationRadius,
    String? logoUrl,
    Map<String, String>? workSchedule,
    bool? isActive,
  }) {
    return Company(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      adminId: adminId ?? this.adminId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      coordinates: coordinates ?? this.coordinates,
      locationRadius: locationRadius ?? this.locationRadius,
      logoUrl: logoUrl ?? this.logoUrl,
      workSchedule: workSchedule ?? this.workSchedule,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
}

class WorkHours {
  final TimeOfDay start;
  final TimeOfDay end;

  WorkHours({required this.start, required this.end});
}

extension TimeOfDayExtension on TimeOfDay {
  bool isBeforeOrEqual(TimeOfDay other) {
    return this.hour < other.hour ||
        (this.hour == other.hour && this.minute <= other.minute);
  }

  bool isAfterOrEqual(TimeOfDay other) {
    return this.hour > other.hour ||
        (this.hour == other.hour && this.minute >= other.minute);
  }

  String format() {
    String addLeadingZero(int value) {
      return value < 10 ? '0$value' : value.toString();
    }

    return '${addLeadingZero(this.hour)}:${addLeadingZero(this.minute)}';
  }
}
