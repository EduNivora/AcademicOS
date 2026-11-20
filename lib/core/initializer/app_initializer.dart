import 'package:flutter/foundation.dart';

import '../../data/database/database_helper.dart';

/// Initializes the durable storage required by the application.
///
/// Startup is gated only by the actual persistent academic database. The old
/// database-password preflight was removed because that password is not
/// consumed by the current SQLite engine; allowing an unrelated Keystore
/// failure to block startup incorrectly reported healthy SQLite as unavailable.
class AppInitializer {
  AppInitializer({Future<void> Function()? initializeDatabase})
    : _initializeDatabase =
          initializeDatabase ?? _initializePersistentDatabase;

  final Future<void> Function() _initializeDatabase;

  static Future<void> _initializePersistentDatabase() async {
    await DatabaseHelper.instance.database;
  }

  Future<void> initialize() async {
    try {
      await _initializeDatabase();
      debugPrint('Application persistent database initialized successfully.');
    } catch (error, stackTrace) {
      debugPrint(
        'Application persistent database initialization failed: '
        '${error.runtimeType}: $error\n$stackTrace',
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
