import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/app/app.dart';
import 'package:rsue_rasp_app/app/providers.dart';
import 'package:rsue_rasp_app/core/database/app_database.dart';
import 'package:rsue_rasp_app/features/schedule/data/schedule_repository.dart';
import 'package:rsue_rasp_app/features/schedule/domain/schedule_models.dart';
import 'package:rsue_rasp_app/features/schedule/presentation/app_controller.dart';
import 'package:rsue_rasp_app/features/schedule/presentation/widgets/full_calendar.dart';
import 'app_behavior_test.dart' show TestApi, TestConnectivity;

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
      const fonts = String.fromEnvironment('PREVIEW_FONTS');
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(
            '$fonts/${entry.value}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
      }
    }
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('calendar, favorites and pull to refresh in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(396, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = TestApi();
      final repository = ScheduleRepository(db, api);
      final connection = TestConnectivity();
      final controller = AppController(repository, connectivity: connection);
      final now = DateTime.now();
      final date = DateUtils.dateOnly(now);
      String clock(DateTime value) =>
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      const entity = ScheduleEntity(
        apiId: 1,
        name: 'ПИ-301',
        kind: EntityKind.group,
      );
      controller.initialized = true;
      controller.themeMode = mode;
      controller.selectedEntity = entity;
      controller.entities = [
        entity,
        const ScheduleEntity(apiId: 2, name: 'АА-101', kind: EntityKind.group),
      ];
      controller.favoriteKeys = {'1'};
      controller.schedule = EntitySchedule(
        kind: 'group',
        instance: 'ПИ-301',
        weeks: [
          ScheduleWeek(
            id: 1,
            name: 'Текущая неделя',
            current: true,
            parity: 1,
            days: [
              ScheduleDay(
                id: 1,
                date: date,
                name: 'Сегодня',
                pairs: [
                  SchedulePair(
                    id: 1,
                    start: clock(now.subtract(const Duration(minutes: 10))),
                    end: clock(now.add(const Duration(minutes: 45))),
                    lessons: const [
                      Lesson(
                        id: 1,
                        subject: 'Информационные системы и технологии',
                        teacher: 'Давтян А.Т.',
                        group: 'ПИ-301',
                        lessonKind: 'Лекция',
                        subgroup: '',
                        audience: '305',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: RepaintBoundary(
            key: boundaryKey,
            child: const RsueScheduleApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ИДЁТ ПАРА'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('docs/previews').create(recursive: true);
          await File(
            'docs/previews/schedule-${mode.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('Открыть календарь'));
      await tester.pumpAndSettle();
      expect(find.byType(FullCalendar), findsOneWidget);
      expect(find.text('Есть занятия'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Предыдущий месяц'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(FullCalendar),
          matching: find.text('${date.day}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FullCalendar), findsNothing);
      expect(controller.selectedDate, date);
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      // The now empty schedule must still be refreshable.
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(api.calls, 2);
      controller.schedule = null;
      controller.errorMessage = 'Нет сохранённого расписания';
      controller.notifyListeners();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(api.calls, 3);
      await tester.tap(find.byTooltip('Поиск'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('ПИ-301')).dy,
        lessThan(tester.getTopLeft(find.text('АА-101')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await connection.changes.close();
        await db.close();
      });
    });
  }
}
