import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/initializer/app_initializer.dart';

void main() {
  group('AppInitializer', () {
    test('initializes secure storage before the persistent database', () async {
      final calls = <String>[];
      final initializer = AppInitializer(
        initializeSecurity: () async => calls.add('security'),
        initializeDatabase: () async => calls.add('database'),
      );

      await initializer.initialize();

      expect(calls, ['security', 'database']);
    });

    test('propagates database initialization failures', () async {
      final initializer = AppInitializer(
        initializeSecurity: () async {},
        initializeDatabase: () async {
          throw StateError('persistent storage unavailable');
        },
      );

      await expectLater(
        initializer.initialize(),
        throwsA(
          isA<AppInitializationException>().having(
            (error) => error.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
    });

    test('does not continue to database when secure storage fails', () async {
      var databaseInitialized = false;
      final initializer = AppInitializer(
        initializeSecurity: () async {
          throw StateError('secure storage unavailable');
        },
        initializeDatabase: () async {
          databaseInitialized = true;
        },
      );

      await expectLater(
        initializer.initialize(),
        throwsA(isA<AppInitializationException>()),
      );
      expect(databaseInitialized, isFalse);
    });
  });
}
