import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/data/database/database_helper.dart';
import 'package:academic_os/data/models/course_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Academic assistant execution ledger', () {
    test('upgrades schema v13 to v14 without losing academic records', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();
      const courseId = 987681;
      await helper.deleteCourse(courseId);
      await helper.insertCourse(
        const CourseModel(
          id: courseId,
          name: 'Ledger migration preservation',
          instructor: 'Instructor',
          code: 'LEDGER-14',
          credits: 3,
        ),
      );

      try {
        final db = await helper.database;
        await db.execute('DROP TABLE IF EXISTS assistant_action_steps');
        await db.execute('DROP TABLE IF EXISTS assistant_action_runs');
        await db.execute('PRAGMA user_version = 13');
        await helper.close();

        final upgraded = await helper.database;
        final version = await upgraded.rawQuery('PRAGMA user_version');
        expect(version.single['user_version'], 14);

        final tables = await upgraded.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('assistant_action_runs', 'assistant_action_steps')",
        );
        expect(
          tables.map((row) => row['name']),
          containsAll(['assistant_action_runs', 'assistant_action_steps']),
        );
        expect(
          (await helper.getCourseById(courseId))?.name,
          'Ledger migration preservation',
        );
      } finally {
        await helper.deleteCourse(courseId);
        await helper.close();
      }
    });

    test('persists step states and marks interrupted work without replay', () async {
      final helper = DatabaseHelper.instance;
      await helper.close();

      final runId = await helper.createAssistantActionRun(
        source: 'cloud_plan',
        actionNames: const ['create_material', 'create_task', 'add_lecture'],
      );
      await helper.updateAssistantActionRun(runId: runId, status: 'running');
      await helper.updateAssistantActionStep(
        runId: runId,
        stepIndex: 0,
        status: 'running',
      );
      await helper.updateAssistantActionStep(
        runId: runId,
        stepIndex: 0,
        status: 'succeeded',
        changedData: true,
      );
      await helper.updateAssistantActionStep(
        runId: runId,
        stepIndex: 1,
        status: 'running',
      );
      await helper.close();

      final recovered = await helper.recoverInterruptedAssistantRuns();
      expect(recovered, 1);

      final history = await helper.getAssistantActionHistory(limit: 10);
      final run = history.singleWhere((item) => item['id'] == runId);
      final steps = run['steps'] as List<Map<String, dynamic>>;
      expect(run['status'], 'interrupted');
      expect(run['failure_code'], 'app_restarted');
      expect(steps.map((step) => step['action_name']), [
        'create_material',
        'create_task',
        'add_lecture',
      ]);
      expect(steps[0]['status'], 'succeeded');
      expect(steps[0]['changed_data'], 1);
      expect(steps[1]['status'], 'interrupted');
      expect(steps[2]['status'], 'skipped');

      final db = await helper.database;
      final columns = await db.rawQuery(
        'PRAGMA table_info(assistant_action_runs)',
      );
      final names = columns.map((row) => row['name']).toSet();
      expect(
        names.intersection({
          'prompt',
          'response',
          'arguments',
          'academic_context',
          'file_bytes',
        }),
        isEmpty,
      );
      await db.delete(
        'assistant_action_runs',
        where: 'id = ?',
        whereArgs: [runId],
      );
      await helper.close();
    });

    test('rejects unsupported sources and oversized action batches', () async {
      final helper = DatabaseHelper.instance;
      await expectLater(
        helper.createAssistantActionRun(
          source: 'unknown',
          actionNames: const ['create_task'],
        ),
        throwsArgumentError,
      );
      await expectLater(
        helper.createAssistantActionRun(
          source: 'cloud_plan',
          actionNames: List.filled(11, 'create_task'),
        ),
        throwsArgumentError,
      );
      await helper.close();
    });
  });
}
