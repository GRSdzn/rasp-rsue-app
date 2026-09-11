import 'package:intl/intl.dart';

import 'schedule_models.dart';

class ScheduleShare {
  const ScheduleShare();

  String day({required ScheduleEntity entity, required ScheduleDay day}) {
    final title = entity.kind == EntityKind.group ? 'Группа' : 'Преподаватель';
    final buffer = StringBuffer()
      ..writeln('$title: ${entity.name}')
      ..writeln()
      ..writeln(DateFormat('EEEE, d MMMM', 'ru').format(day.date));
    _writeDay(buffer, day, entity);
    return buffer.toString().trim();
  }

  String week({required ScheduleEntity entity, required ScheduleWeek week}) {
    final title = entity.kind == EntityKind.group ? 'Группа' : 'Преподаватель';
    final buffer = StringBuffer()
      ..writeln('$title: ${entity.name}')
      ..writeln(week.name);
    for (final day in week.days.where((item) => item.hasLessons)) {
      buffer
        ..writeln()
        ..writeln('— ${DateFormat('EEEE, d MMMM', 'ru').format(day.date)} —');
      _writeDay(buffer, day, entity);
    }
    if (!week.days.any((day) => day.hasLessons)) {
      buffer
        ..writeln()
        ..writeln('Занятий нет');
    }
    return buffer.toString().trim();
  }

  void _writeDay(StringBuffer buffer, ScheduleDay day, ScheduleEntity entity) {
    if (!day.hasLessons) {
      buffer
        ..writeln()
        ..writeln('Занятий нет');
      return;
    }
    for (final pair in day.occupiedPairs) {
      for (final lesson in pair.lessons) {
        buffer
          ..writeln()
          ..writeln('${pair.start}–${pair.end}')
          ..writeln(lesson.subject);
        if (lesson.lessonKind.isNotEmpty) buffer.writeln(lesson.lessonKind);
        if (lesson.teacher.isNotEmpty && entity.kind == EntityKind.group) {
          buffer.writeln(lesson.teacher);
        }
        if (lesson.group.isNotEmpty && entity.kind == EntityKind.teacher) {
          buffer.writeln(lesson.group);
        }
        if (lesson.subgroup.isNotEmpty) buffer.writeln(lesson.subgroup);
        if (lesson.audience.isNotEmpty) {
          buffer.writeln('Аудитория ${lesson.audience}');
        }
      }
    }
  }
}
