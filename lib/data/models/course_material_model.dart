import 'dart:typed_data';

class CourseMaterialModel {
  final int? id;
  final int courseId;
  final String title;
  final String filePath;
  final String fileType;
  final String? createdAt;
  final Uint8List? fileBytes;

  CourseMaterialModel({
    this.id,
    required this.courseId,
    required this.title,
    required this.filePath,
    required this.fileType,
    this.createdAt,
    this.fileBytes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'course_id': courseId,
        'title': title,
        'file_path': filePath,
        'file_type': fileType,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        if (fileBytes != null) 'file_bytes': fileBytes,
      };

  factory CourseMaterialModel.fromMap(Map<String, dynamic> map) =>
      CourseMaterialModel(
        id: map['id'] as int?,
        courseId: map['course_id'] as int,
        title: map['title'] as String,
        filePath: map['file_path'] as String,
        fileType: map['file_type'] as String,
        createdAt: map['created_at'] as String?,
        fileBytes: map['file_bytes'] == null
            ? null
            : Uint8List.fromList(
                List<int>.from(map['file_bytes'] as List),
              ),
      );
}
