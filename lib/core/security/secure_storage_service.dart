import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خدمة تخزين آمن لتخزين كلمات المرور والحساسية المحلية.
/// تفصل هذا عن قاعدة البيانات لتمنحنا مرونة في تغيير آلية التخزين لاحقًا.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _secureStorage = storage ?? const FlutterSecureStorage();

  static const String _dbPasswordKey = 'academic_os_db_password';
  final FlutterSecureStorage _secureStorage;

  static const String _taskFilterKey = 'task_filter_course';
  static const String _taskSortModeKey = 'task_sort_mode';
  static const String _taskStatusFilterKey = 'task_status_filter';

  static bool _isKeystoreDecryptionError(PlatformException error) {
    final details =
        '${error.code} ${error.message ?? ''} ${error.details ?? ''}'
            .toLowerCase();
    return details.contains('badpadding') ||
        details.contains('aeadbadtag') ||
        details.contains('keystore') ||
        details.contains('javax.crypto') ||
        details.contains('invalidkey') ||
        details.contains('decryption');
  }

  /// يعيد كلمة المرور الخاصة بقاعدة البيانات.
  /// إذا لم توجد، يتم إنشاؤها وتخزينها آمنًا.
  Future<String> getDatabasePassword() async {
    String? existingPassword;
    try {
      existingPassword = await _secureStorage.read(key: _dbPasswordKey);
    } on PlatformException catch (error) {
      if (!_isKeystoreDecryptionError(error)) {
        rethrow;
      }
      // On Android reinstall/backup restore, an orphaned Keystore entry can
      // fail decryption. Since SQLite is not currently encrypted with this key,
      // safely reset only this unreadable entry and regenerate it without
      // touching any user database tables.
      debugPrint(
        'SecureStorageService: resetting unreadable Keystore entry '
        '($_dbPasswordKey) after Android decryption failure.',
      );
      await _secureStorage.delete(key: _dbPasswordKey);
    }
    if (existingPassword != null && existingPassword.isNotEmpty) {
      return existingPassword;
    }

    final newPassword = _generateSecurePassword();
    await _secureStorage.write(key: _dbPasswordKey, value: newPassword);
    return newPassword;
  }

  Future<void> saveTaskFilter(String? courseName) async {
    if (courseName == null) {
      await _secureStorage.delete(key: _taskFilterKey);
      return;
    }
    await _secureStorage.write(key: _taskFilterKey, value: courseName);
  }

  Future<String?> getSavedTaskFilter() async {
    return await _secureStorage.read(key: _taskFilterKey);
  }

  Future<void> saveTaskSortMode(String sortModeName) async {
    await _secureStorage.write(key: _taskSortModeKey, value: sortModeName);
  }

  Future<String?> getSavedTaskSortMode() async {
    return await _secureStorage.read(key: _taskSortModeKey);
  }

  Future<void> saveTaskStatusFilter(String statusName) async {
    await _secureStorage.write(key: _taskStatusFilterKey, value: statusName);
  }

  Future<String?> getSavedTaskStatusFilter() async {
    return await _secureStorage.read(key: _taskStatusFilterKey);
  }

  String _generateSecurePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// يحذف كلمة المرور من التخزين الآمن.
  /// مفيد في حالات إعادة الضبط أو تسجيل الخروج الآمن.
  Future<void> deleteDatabasePassword() async {
    await _secureStorage.delete(key: _dbPasswordKey);
  }
}
