import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;
  final Uint8List? fileBytes;

  const DocumentViewerScreen(
      {super.key, required this.filePath, required this.title, this.fileBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsWeb) ...[
                const Icon(Icons.insert_drive_file,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('عرض المستند غير مدعوم في الويب داخل التطبيق.'),
                const SizedBox(height: 8),
                const Text('الملف محفوظ محلياً، لكن عارض PDF للويب غير مفعّل بعد.'),
              ] else ...[
                const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                    'معاينة المستند داخل التطبيق غير متاحة في هذه النسخة.'),
                const SizedBox(height: 8),
                const Text('الملف محفوظ محلياً، لكن المعاينة غير متاحة في هذه الشاشة.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
