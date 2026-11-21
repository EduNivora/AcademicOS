import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StudentProfile {
  static const String storageKey = 'academic_os_student_profile';

  final String fullName;
  final String university;
  final String major;
  final String department;
  final String semester;
  final String academicLevel;
  final String targetGpa;
  final String avatar;

  const StudentProfile({
    required this.fullName,
    required this.university,
    required this.major,
    this.department = '',
    this.semester = '',
    required this.academicLevel,
    required this.targetGpa,
    required this.avatar,
  });

  factory StudentProfile.empty() => const StudentProfile(
    fullName: '',
    university: '',
    major: '',
    department: '',
    semester: '',
    academicLevel: '',
    targetGpa: '',
    avatar: 'student',
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'university': university,
    'major': major,
    'department': department,
    'semester': semester,
    'academicLevel': academicLevel,
    'targetGpa': targetGpa,
    'avatar': avatar,
  };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
    fullName: json['fullName']?.toString() ?? '',
    university: json['university']?.toString() ?? '',
    major: json['major']?.toString() ?? '',
    department: json['department']?.toString() ?? '',
    semester: json['semester']?.toString() ?? '',
    academicLevel: json['academicLevel']?.toString() ?? '',
    targetGpa: json['targetGpa']?.toString() ?? '',
    avatar: json['avatar']?.toString() ?? 'student',
  );


  StudentProfile copyWith({
    String? fullName,
    String? university,
    String? major,
    String? department,
    String? semester,
    String? academicLevel,
    String? targetGpa,
    String? avatar,
  }) =>
      StudentProfile(
        fullName: fullName ?? this.fullName,
        university: university ?? this.university,
        major: major ?? this.major,
        department: department ?? this.department,
        semester: semester ?? this.semester,
        academicLevel: academicLevel ?? this.academicLevel,
        targetGpa: targetGpa ?? this.targetGpa,
        avatar: avatar ?? this.avatar,
      );

  static Future<StudentProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return StudentProfile.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return StudentProfile.fromJson(decoded);
      }
    } catch (_) {}
    return StudentProfile.empty();
  }

  static Future<void> save(StudentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(profile.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

