import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/app/app_theme.dart';
import 'package:rsue_rasp_app/core/database/app_database.dart';
import 'package:rsue_rasp_app/features/schedule/data/rsue_api.dart';
import 'package:rsue_rasp_app/features/schedule/data/schedule_repository.dart';
import 'package:rsue_rasp_app/features/schedule/domain/schedule_models.dart';
import 'package:rsue_rasp_app/features/schedule/presentation/app_controller.dart';
import 'package:rsue_rasp_app/features/schedule/presentation/widgets/lesson_card.dart';

class TestConnectivity implements Connectivity {
  List<ConnectivityResult> results = [ConnectivityResult.none];
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

class TestApi extends RsueApi {
  bool fail = false;
  bool invalid = false;
  int calls = 0;
  final pending = <String, Completer<Map<String, dynamic>>>{};
  @override
  Future<List<Map<String, dynamic>>> searchItems() async => [
    {'id': 1, 'name': 'A'},
    {'id': 2, 'name': 'B'},
  ];
  @override
  Future<Set<String>> groupNames() async => {'A', 'B'};
  @override
  Future<Map<String, dynamic>> schedule(String entityName) async {
    calls++;
    if (fail) throw StateError('Server unavailable');
    if (invalid) return {};
    return pending[entityName]?.future ?? Future.value(payload(entityName));
  }
}

Map<String, dynamic> payload(String name) => {
  'instance': name,
  'kind': 'group',
  'weeks': [],
};
const a = ScheduleEntity(apiId: 1, name: 'A', kind: EntityKind.group);
const b = ScheduleEntity(apiId: 2, name: 'B', kind: EntityKind.group);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late TestApi api;
  late ScheduleRepository repository;
  late TestConnectivity connection;
  late AppController controller;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    api = TestApi();
    repository = ScheduleRepository(database, api);
    connection = TestConnectivity();
    await repository.syncCatalogue();
    controller = AppController(repository, connectivity: connection);
    await controller.initialize();
    await controller.checkConnection();
  });
  tearDown(() async {
    controller.dispose();
    await connection.changes.close();
    await database.close();
  });

  test(
    'restores selection and cached schedule offline; opt-out clears selection',
    () async {
      await controller.selectEntity(a);
      controller.dispose();
      api.fail = true;
      controller = AppController(repository, connectivity: connection);
      await controller.initialize();
      await controller.checkConnection();
      expect(controller.selectedEntity?.key, a.key);
      expect(controller.schedule?.instance, 'A');
      expect(controller.offline, isTrue);
      await controller.setRememberSelection(false);
      expect(await repository.setting('selectedEntity'), '');
      controller.dispose();
      controller = AppController(repository, connectivity: connection);
      await controller.initialize();
      await controller.checkConnection();
      expect(controller.selectedEntity, isNull);
    },
  );

  test('late previous selection cannot replace current schedule', () async {
    api.pending['A'] = Completer();
    final first = controller.selectEntity(a);
    while (api.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await controller.selectEntity(b);
    api.pending['A']!.complete(payload('A'));
    await first;
    expect(controller.selectedEntity?.key, b.key);
    expect(controller.schedule?.instance, 'B');
    expect(controller.syncing, isFalse);
  });

  test(
    'network restore refreshes selected schedule; server failure retains cache',
    () async {
      await controller.selectEntity(a);
      final synced = controller.lastSync;
      api.fail = true;
      connection.results = [ConnectivityResult.wifi];
      await controller.checkConnection();
      expect(controller.offline, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.schedule?.instance, 'A');
      expect(controller.lastSync, synced);
      api.fail = false;
      await controller.checkConnection();
      expect(controller.errorMessage, isNull);
      expect(controller.schedule?.instance, 'A');
      connection.results = [ConnectivityResult.none];
      await controller.checkConnection();
      expect(controller.offline, isTrue);
    },
  );

  test('malformed response cannot overwrite valid cache', () async {
    await controller.selectEntity(a);
    api.invalid = true;
    await controller.refreshSchedule();
    expect(controller.errorMessage, isNotNull);
    expect((await repository.cachedSchedule(a))?.schedule.instance, 'A');
  });

  test('current lesson includes start and excludes end, respects date', () {
    const pair = SchedulePair(id: 1, start: '09:00', end: '10:30', lessons: []);
    final day = DateTime(2026, 9, 11);
    expect(
      lessonMoment(day, pair, DateTime(2026, 9, 11, 9)),
      LessonMoment.current,
    );
    expect(
      lessonMoment(day, pair, DateTime(2026, 9, 11, 10, 30)),
      LessonMoment.completed,
    );
    expect(
      lessonMoment(day, pair, DateTime(2026, 9, 10, 9)),
      LessonMoment.upcoming,
    );
    expect(
      lessonMoment(day, pair, DateTime(2026, 9, 12, 9)),
      LessonMoment.completed,
    );
  });

  test('text and selected controls have readable contrast in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final c = theme.colorScheme;
      for (final pair in [
        (c.primary, c.surface),
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.primary, c.primaryContainer),
        (c.onSurfaceVariant, c.surface),
        (c.onSurface, c.primaryContainer),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    }
  });
}
