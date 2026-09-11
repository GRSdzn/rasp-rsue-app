import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/features/schedule/data/schedule_mapper.dart';

void main() {
  test('maps the observed RSUE date format and all lesson fields', () {
    final schedule = const ScheduleMapper().fromJson({
      'kind': 'Group',
      'instance': 'ПРИZS-3401',
      'weeks': [
        {
          'id': 1,
          'name': '1. Нечетная',
          'current': true,
          'parity': 1,
          'days': [
            {
              'id': 1,
              'date': '14.09.2026',
              'name': 'Понедельник',
              'pairs': [
                {
                  'id': 1,
                  'startTime': '09:00:00',
                  'endTime': '10:30:00',
                  'lessons': [
                    {
                      'id': 42,
                      'subject': 'Проектирование систем',
                      'teacher': {'id': 2, 'name': 'доц.Иванов И.И.'},
                      'group': 'ПРИZS-3401',
                      'kind': {'id': 1, 'name': 'Лекция', 'shortName': 'лек.'},
                      'subgroup': {'id': 1, 'name': '1 подгруппа'},
                      'audience': '204',
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    });

    final day = schedule.days.single;
    final pair = day.occupiedPairs.single;
    final lesson = pair.lessons.single;
    expect(day.date, DateTime(2026, 9, 14));
    expect(pair.start, '09:00');
    expect(pair.end, '10:30');
    expect(lesson.subject, 'Проектирование систем');
    expect(lesson.teacher, 'доц.Иванов И.И.');
    expect(lesson.lessonKind, 'Лекция');
    expect(lesson.subgroup, '1 подгруппа');
    expect(lesson.audience, '204');
  });

  test('accepts ISO date fallback and empty lesson slots', () {
    final schedule = const ScheduleMapper().fromJson({
      'kind': 'Teacher',
      'instance': 'Иванов',
      'weeks': [
        {
          'id': 2,
          'name': '2. Четная',
          'current': false,
          'parity': 2,
          'days': [
            {
              'id': 1,
              'date': '2026-09-15',
              'name': 'Вторник',
              'pairs': [
                {
                  'id': 1,
                  'startTime': '08:30:00',
                  'endTime': '10:00:00',
                  'lessons': <Object>[],
                },
              ],
            },
          ],
        },
      ],
    });

    expect(schedule.days.single.date, DateTime(2026, 9, 15));
    expect(schedule.days.single.hasLessons, isFalse);
  });
}
