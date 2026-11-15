/// Validates a weekly schedule slot against the student's existing local entries.
enum ScheduleValidationIssue {
  invalidTimeFormat,
  invalidTimeRange,
  invalidStoredEntry,
  overlap,
}

class ScheduleValidationResult {
  const ScheduleValidationResult({
    this.issue,
    this.conflictingScheduleId,
  });

  final ScheduleValidationIssue? issue;
  final int? conflictingScheduleId;

  bool get isValid => issue == null;
}

class ScheduleConflictValidator {
  const ScheduleConflictValidator._();

  /// Adjacent entries are valid; entries that overlap on the same weekday are not.
  static ScheduleValidationResult validate({
    required String day,
    required String startTime,
    required String endTime,
    required Iterable<Map<String, dynamic>> existingSchedules,
    int? excludingScheduleId,
  }) {
    final start = _parseMinutes(startTime);
    final end = _parseMinutes(endTime);

    if (start == null || end == null) {
      return const ScheduleValidationResult(
        issue: ScheduleValidationIssue.invalidTimeFormat,
      );
    }
    if (end <= start) {
      return const ScheduleValidationResult(
        issue: ScheduleValidationIssue.invalidTimeRange,
      );
    }

    for (final entry in existingSchedules) {
      if (entry['day_of_week']?.toString() != day) continue;

      final rawId = entry['id'];
      final entryId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');
      if (excludingScheduleId != null && entryId == excludingScheduleId) {
        continue;
      }

      final existingStart = _parseMinutes(entry['start_time']?.toString());
      final existingEnd = _parseMinutes(entry['end_time']?.toString());
      if (existingStart == null ||
          existingEnd == null ||
          existingEnd <= existingStart) {
        return ScheduleValidationResult(
          issue: ScheduleValidationIssue.invalidStoredEntry,
          conflictingScheduleId: entryId,
        );
      }

      if (start < existingEnd && existingStart < end) {
        return ScheduleValidationResult(
          issue: ScheduleValidationIssue.overlap,
          conflictingScheduleId: entryId,
        );
      }
    }

    return const ScheduleValidationResult();
  }

  static int? _parseMinutes(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) return null;

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour * 60 + minute;
  }
}
