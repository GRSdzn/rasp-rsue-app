import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rsue_rasp_app/features/schedule/domain/schedule_models.dart';
import 'package:rsue_rasp_app/features/schedule/domain/schedule_share.dart';

Future<void> main() async {
  await initializeDateFormatting('ru');
  test('day sharing is human-readable and contains no API id', () {
    const entity = ScheduleEntity(
      apiId: 9999,
      name: 'ПРИZS-3401',
      kind: EntityKind.group,
    );
    final day = ScheduleDay(
      id: 1,
      date: DateTime(2026, 9, 14),
      name: 'Понедельник',
      pairs: const [
        SchedulePair(
          id: 1,
          start: '09:00',
          end: '10:30',
          lessons: [
            Lesson(
              id: 12,
              subject: 'Информатика',
              teacher: 'доц.Иванов И.И.',
              group: 'ПРИZS-3401',
              lessonKind: 'Лекция',
              subgroup: '',
              audience: '204',
            ),
          ],
        ),
      ],
    );

    final text = const ScheduleShare().day(entity: entity, day: day);
    expect(text, contains('Группа: ПРИZS-3401'));
    expect(text, contains('09:00–10:30'));
    expect(text, contains('Информатика'));
    expect(text, contains('Аудитория 204'));
    expect(text, isNot(contains('9999')));
  });
}
