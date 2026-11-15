import 'package:flutter/foundation.dart';

/// Student-defined academic term persisted only in the local SQLite database.
@immutable
class AcademicTermModel {
  const AcademicTermModel({
    this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isActive = false,
    this.createdAt,
  });

  final int? id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? createdAt;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void validate() {
    if (name.trim().isEmpty) {
      throw const FormatException('اسم الفصل الدراسي مطلوب.');
    }
    if (name.trim().length > 80) {
      throw const FormatException('اسم الفصل الدراسي طويل جداً.');
    }
    if (_dateOnly(endDate).isBefore(_dateOnly(startDate))) {
      throw const FormatException(
        'تاريخ نهاية الفصل يجب ألا يسبق تاريخ بدايته.',
      );
    }
  }

  Map<String, dynamic> toMap() {
    validate();
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'start_date': _dateOnly(startDate).toIso8601String(),
      'end_date': _dateOnly(endDate).toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory AcademicTermModel.fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('سجل الفصل الدراسي يحتوي على اسم غير صالح.');
    }

    final startDate = DateTime.tryParse(map['start_date']?.toString() ?? '');
    final endDate = DateTime.tryParse(map['end_date']?.toString() ?? '');
    if (startDate == null || endDate == null) {
      throw const FormatException('تواريخ الفصل الدراسي غير صالحة.');
    }

    final idValue = map['id'];
    final id = idValue is int
        ? idValue
        : int.tryParse(idValue?.toString() ?? '');
    final activeValue = map['is_active'];
    final result = AcademicTermModel(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      isActive: activeValue == 1 || activeValue == true,
      createdAt: map['created_at']?.toString(),
    );
    result.validate();
    return result;
  }
}
