import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/initializer/app_initializer.dart';

void main() {
  group('AppInitializer', () {
    test('opens the persistent database before optional security warm-up',
        () async {
      final calls = <String>[];
      final initializer = AppInitializer(
        initializeSecurity: () async => calls.add('security'),
        initializeDatabase: () async => calls.add('database'),
      );

      await initializer.initialize();

      expect(calls, ['database', 'security']);
    });

    test('propagates persistent database initialization failures', () async {
      var optionalSecurityInitialized = false;
      final initializer = AppInitializer(
        initializeSecurity: () async {
          optionalSecurityInitialized = true;
        },
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
      expect(optionalSecurityInitialized, isFalse);
    });

    test('secure-storage warm-up failure does not block local workspace',
        () async {
      var databaseInitialized = false;
      final initializer = AppInitializer(
        initializeSecurity: () async {
          throw StateError('optional secure storage unavailable');
        },
        initializeDatabase: () async {
          databaseInitialized = true;
        },
      );

      await expectLater(initializer.initialize(), completes);
      expect(databaseInitialized, isTrue);
    });
  });
}
