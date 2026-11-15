import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/models/exam_model.dart';

void main() {
  group('ExamModel', () {
    test('round trips a valid exam map', () {
      final exam = ExamModel(
        id: 9,
        title: 'Final',
        examDate: DateTime(2026, 12, 20, 9),
      );
      final parsed = ExamModel.fromMap(exam.toMap());
      expect(parsed.id, 9);
      expect(parsed.title, 'Final');
      expect(parsed.examDate, DateTime(2026, 12, 20, 9));
    });

    test('rejects missing titles and invalid dates instead of inventing a date', () {
      expect(
        () => ExamModel.fromMap({'id': 1, 'exam_date': '2026-12-20'}),
        throwsFormatException,
      );
      expect(
        () => ExamModel.fromMap({'id': 1, 'title': 'Final', 'exam_date': 'bad'}),
        throwsFormatException,
      );
    });
  });
}
