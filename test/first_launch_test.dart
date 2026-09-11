import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/core/database/app_database.dart';
import 'package:rsue_rasp_app/features/schedule/data/schedule_repository.dart';
import 'package:rsue_rasp_app/features/schedule/domain/schedule_models.dart';
import 'package:rsue_rasp_app/features/schedule/presentation/app_controller.dart';

import 'app_behavior_test.dart' show TestApi, TestConnectivity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch seeds a usable offline catalogue', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final connection = TestConnectivity()..results = [ConnectivityResult.none];
    final controller = AppController(
      ScheduleRepository(database, TestApi()),
      connectivity: connection,
    );
    addTearDown(() async {
      controller.dispose();
      await connection.changes.close();
      await database.close();
    });

    expect(await database.allEntities(), isEmpty);
    await controller.initialize();
    await controller.checkConnection();

    expect(controller.initialized, isTrue);
    expect(controller.offline, isTrue);
    expect(controller.entities, isNotEmpty);
    expect(
      controller.entities.any((entity) => entity.kind == EntityKind.group),
      isTrue,
    );
    expect(
      controller.entities.any((entity) => entity.kind == EntityKind.teacher),
      isTrue,
    );
    expect(controller.selectedEntity, isNull);
  });

  test(
    'first online launch replaces seed data with server catalogue',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final connection = TestConnectivity()
        ..results = [ConnectivityResult.wifi];
      final api = TestApi();
      final controller = AppController(
        ScheduleRepository(database, api),
        connectivity: connection,
      );
      addTearDown(() async {
        controller.dispose();
        await connection.changes.close();
        await database.close();
      });

      await controller.initialize();
      await controller.checkConnection();

      expect(controller.initialized, isTrue);
      expect(controller.offline, isFalse);
      expect(controller.catalogueError, isNull);
      expect(controller.entities.map((entity) => entity.name), ['A', 'B']);
    },
  );
}
