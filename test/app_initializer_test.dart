import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/initializer/app_initializer.dart';

void main() {
  group('AppInitializer', () {
    test('completes when persistent storage initializes', () async {
      var called = false;
      final initializer = AppInitializer(
        initializeDatabase: () async {
          called = true;
        },
      );

      await initializer.initialize();

      expect(called, isTrue);
    });

    test('propagates database initialization failures', () async {
      final initializer = AppInitializer(
        initializeDatabase: () async {
          throw StateError('storage unavailable');
        },
      );

      await expectLater(
        initializer.initialize(),
        throwsA(isA<AppInitializationException>()),
      );
    });
  });
}
