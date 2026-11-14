import 'package:flutter/foundation.dart';

import '../../data/database/database_helper.dart';

/// Initializes the durable storage required by the application.
///
/// Initialization failures are intentionally propagated. The app must not
/// continue into data-dependent screens when its persistent database is
/// unavailable.
class AppInitializer {
  AppInitializer({
    Future<void> Function()? initializeDatabase,
  }) : _initializeDatabase =
            initializeDatabase ?? _initializePersistentDatabase;

  final Future<void> Function() _initializeDatabase;

  static Future<void> _initializePersistentDatabase() async {
    await DatabaseHelper.instance.database;
  }

  Future<void> initialize() async {
    try {
      await _initializeDatabase();
      debugPrint('Application storage initialized successfully.');
    } catch (error, stackTrace) {
      debugPrint(
        'Application storage initialization failed: $error\\n$stackTrace',
      );
      Error.throwWithStackTrace(
        AppInitializationException(
          'The persistent academic database could not be initialized.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}

class AppInitializationException implements Exception {
  const AppInitializationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message Cause: $cause';
}
