import 'package:flutter/foundation.dart';

import '../../data/database/database_helper.dart';

/// Initializes the durable local database before any data-dependent UI loads.
///
/// Account identity and app-lock storage are optional. They initialize lazily
/// when an account feature is explicitly opened and must never gate local use.
class AppInitializer {
  AppInitializer({
    Future<void> Function()? initializeDatabase,
    Future<void> Function()? initializeSecurity,
  })  : _initializeDatabase =
            initializeDatabase ?? _initializePersistentDatabase,
        _initializeSecurity = initializeSecurity ?? _skipOptionalSecurityWarmup;

  final Future<void> Function() _initializeDatabase;
  final Future<void> Function() _initializeSecurity;

  static Future<void> _skipOptionalSecurityWarmup() async {
    // Authentication secure storage is initialized at the point of use.
  }

  static Future<void> _initializePersistentDatabase() async {
    await DatabaseHelper.instance.database;
  }

  Future<void> initialize() async {
    try {
      await _initializeDatabase();
    } catch (error, stackTrace) {
      debugPrint(
        'Persistent academic database initialization failed: $error\\n$stackTrace',
      );
      Error.throwWithStackTrace(
        AppInitializationException(
          'The persistent academic database could not be initialized.',
          cause: error,
        ),
        stackTrace,
      );
    }

    // Optional secure-storage warm-up is best-effort and occurs only after
    // durable SQLite is available.
    try {
      await _initializeSecurity();
    } catch (error, stackTrace) {
      debugPrint(
        'Optional security warm-up unavailable; local workspace remains usable: '
        '$error\\n$stackTrace',
      );
    }

    debugPrint('Persistent academic database initialized successfully.');
  }
}

class AppInitializationException implements Exception {
  const AppInitializationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message Cause: $cause';
}
