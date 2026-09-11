import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
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
  for (final variant in [
    (ThemeMode.dark, 285.0),
    (ThemeMode.light, 396.0),
    (ThemeMode.dark, 396.0),
    (ThemeMode.light, 1100.0),
    (ThemeMode.dark, 1100.0),
  ]) {
    final (mode, width) = variant;
    testWidgets(
      'calendar, favorites and pull to refresh at $width in ${mode.name}',
      (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final api = TestApi();
        final repository = ScheduleRepository(db, api);
        final connection = TestConnectivity();
        final controller = AppController(repository, connectivity: connection);
        addTearDown(() async {
          if (!connection.changes.isClosed) await connection.changes.close();
          await db.close();
        });
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
          const ScheduleEntity(
            apiId: 2,
            name: 'АА-101',
            kind: EntityKind.group,
          ),
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
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: RepaintBoundary(
              key: boundaryKey,
              child: const RsueScheduleApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Информационные системы и технологии'),
          findsOneWidget,
        );
        final barScope = tester.widget<BottomBarScope>(
          find.byType(BottomBarScope),
        );
        tester.view.physicalSize = Size(width, width < 320 ? 700 : 480);
        await tester.pumpAndSettle();
        final scheduleList = find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        );
        final scheduleViewportHeight = tester.getSize(scheduleList).height;
        await tester.dragFrom(
          tester.getTopLeft(scheduleList) + const Offset(20, 12),
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isTrue);
        expect(
          tester.getSize(scheduleList).height,
          closeTo(scheduleViewportHeight, 1),
        );
        await tester.dragFrom(
          tester.getTopLeft(scheduleList) + const Offset(20, 12),
          const Offset(0, 1000),
        );
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(width, 320);
        await tester.pumpAndSettle();
        final compactViewportHeight = tester.getSize(scheduleList).height;
        await tester.dragFrom(
          tester.getTopLeft(scheduleList) + const Offset(20, 12),
          const Offset(0, -160),
        );
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isFalse);
        expect(
          tester.getSize(scheduleList).height,
          greaterThan(compactViewportHeight + 60),
        );
        await tester.dragFrom(
          tester.getTopLeft(scheduleList) + const Offset(20, 12),
          const Offset(0, 40),
        );
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isTrue);
        expect(
          tester.getSize(scheduleList).height,
          closeTo(compactViewportHeight, 1),
        );
        tester.view.physicalSize = Size(width, 780);
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
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
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, 'ПИ-301'))
              .tileColor,
          isNull,
        );
        expect(tester.takeException(), isNull);
        controller.entities = List.generate(
          60,
          (i) => ScheduleEntity(
            apiId: i + 10,
            name: 'Группа $i',
            kind: EntityKind.group,
          ),
        );
        controller.notifyListeners();
        await tester.pumpAndSettle();
        final list = find.byType(ListView);
        final viewportHeight = tester.getSize(list).height;
        await tester.drag(list, const Offset(0, -280));
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isFalse);
        expect(tester.getSize(list).height, greaterThan(viewportHeight + 120));
        expect(find.byType(SearchBar), findsOneWidget);
        await tester.drag(list, const Offset(0, 120));
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isTrue);
        expect(tester.getSize(list).height, closeTo(viewportHeight, 1));
        await tester.tap(find.byTooltip('Настройки'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 16));
        await tester.pumpAndSettle();
        expect(barScope.isVisible.value, isTrue);
        final offlineDescription = find.text(
          'Каталог, избранное и просмотренные расписания хранятся на устройстве.',
        );
        expect(offlineDescription, findsOneWidget);
        expect(
          tester.getBottomRight(offlineDescription).dy,
          lessThan(tester.getTopLeft(find.byTooltip('Расписание')).dy),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
