import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/models/academic_term_model.dart';

void main() {
  group('AcademicTermModel', () {
    test('trims names and stores date-only values', () {
      final term = AcademicTermModel(
        name: '  Fall 2026  ',
        startDate: DateTime(2026, 9, 1, 18, 30),
        endDate: DateTime(2026, 12, 20, 9, 15),
        isActive: true,
      );

      final map = term.toMap();

      expect(map['name'], 'Fall 2026');
      expect(map['start_date'], '2026-09-01T00:00:00.000');
      expect(map['end_date'], '2026-12-20T00:00:00.000');
      expect(map['is_active'], 1);
    });

    test('rejects empty names', () {
      final term = AcademicTermModel(
        name: '  ',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 12, 20),
      );

      expect(term.validate, throwsFormatException);
    });

    test('rejects names longer than 80 characters', () {
      final term = AcademicTermModel(
        name: 'x' * 81,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 12, 20),
      );

      expect(term.validate, throwsFormatException);
    });

    test('rejects an end date before the start date', () {
      final term = AcademicTermModel(
        name: 'Fall 2026',
        startDate: DateTime(2026, 12, 20),
        endDate: DateTime(2026, 9, 1),
      );

      expect(term.validate, throwsFormatException);
    });

    test('round-trips persisted maps', () {
      final original = AcademicTermModel(
        id: 7,
        name: 'Spring 2027',
        startDate: DateTime(2027, 1, 10),
        endDate: DateTime(2027, 5, 20),
        isActive: true,
        createdAt: '2026-11-15T00:00:00.000Z',
      );

      final restored = AcademicTermModel.fromMap(original.toMap());

      expect(restored.id, 7);
      expect(restored.name, original.name);
      expect(restored.startDate, DateTime(2027, 1, 10));
      expect(restored.endDate, DateTime(2027, 5, 20));
      expect(restored.isActive, isTrue);
      expect(restored.createdAt, original.createdAt);
    });

    test('rejects malformed persisted date values', () {
      expect(
        () => AcademicTermModel.fromMap({
          'id': 1,
          'name': 'Fall 2026',
          'start_date': 'not-a-date',
          'end_date': '2026-12-20',
          'is_active': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
