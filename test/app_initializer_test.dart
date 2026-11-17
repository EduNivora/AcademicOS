import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/initializer/app_initializer.dart';

void main() {
  group('AppInitializer', () {
    test('initializes the persistent database before completing startup', () async {
      var databaseInitialized = false;
      final initializer = AppInitializer(
        initializeDatabase: () async {
          databaseInitialized = true;
        },
      );

      await initializer.initialize();

      expect(databaseInitialized, isTrue);
    });

    test('propagates persistent database initialization failures', () async {
      final initializer = AppInitializer(
        initializeDatabase: () async {
          throw StateError('persistent SQLite unavailable');
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
  });
}
