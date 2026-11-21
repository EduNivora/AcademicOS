import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/models/student_profile_model.dart';

void main() {
  group('StudentProfile academic fields', () {
    test('loads legacy profiles without department and semester', () {
      final profile = StudentProfile.fromJson({
        'fullName': 'Student',
        'university': 'University',
        'major': 'Cybersecurity',
        'academicLevel': 'Level 3',
        'targetGpa': '4.5',
        'avatar': 'student',
      });

      expect(profile.fullName, 'Student');
      expect(profile.department, isEmpty);
      expect(profile.semester, isEmpty);
    });

    test('serializes department and semester in the academic profile', () {
      const profile = StudentProfile(
        fullName: 'Student',
        university: 'University',
        major: 'Cybersecurity',
        department: 'Computing',
        semester: 'Fall 2026',
        academicLevel: 'Level 3',
        targetGpa: '4.5',
        avatar: 'student',
      );

      final json = profile.toJson();
      expect(json['department'], 'Computing');
      expect(json['semester'], 'Fall 2026');
      expect(StudentProfile.fromJson(json).semester, 'Fall 2026');
    });
  });
}
