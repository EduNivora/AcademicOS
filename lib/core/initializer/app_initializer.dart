import 'package:flutter/foundation.dart';

import '../../data/database/database_helper.dart';
import '../platform/app_platform.dart';
import '../security/secure_storage_service.dart';

class AppInitializer {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final SecureStorageService _secureStorageService = SecureStorageService();

  Future<void> initialize() async {
    if (AppPlatform.shouldUseNativeSecurity()) {
      await _secureStorageService.getDatabasePassword();
    } else {
      debugPrint(
        'Web mode detected: skipping secure storage initialization.',
      );
    }

    // Startup must fail if persistent storage cannot be opened. Silently
    // continuing can make the application appear usable while data is unsafe.
    await _databaseHelper.database;
    debugPrint('Application initialized successfully.');
  }
}
