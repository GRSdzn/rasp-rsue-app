import 'package:flutter/material.dart';

enum EntityKind { group, teacher }

@immutable
class ScheduleEntity {
  const ScheduleEntity({
    required this.apiId,
    required this.name,
    required this.kind,
  });

  final int apiId;
  final String name;
  final EntityKind kind;

  String get key => apiId.toString();
}

@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.group,
    required this.lessonKind,
    required this.subgroup,
    required this.audience,
  });

  final int id;
  final String subject;
  final String teacher;
  final String group;
  final String lessonKind;
  final String subgroup;
  final String audience;
}

@immutable
class SchedulePair {
  const SchedulePair({
    required this.id,
    required this.start,
    required this.end,
    required this.lessons,
  });

  final int id;
  final String start;
  final String end;
  final List<Lesson> lessons;
}

@immutable
class ScheduleDay {
  const ScheduleDay({
    required this.id,
    required this.date,
    required this.name,
    required this.pairs,
  });

  final int id;
  final DateTime date;
  final String name;
  final List<SchedulePair> pairs;

  bool get hasLessons => pairs.any((pair) => pair.lessons.isNotEmpty);
  Iterable<SchedulePair> get occupiedPairs =>
      pairs.where((pair) => pair.lessons.isNotEmpty);
}

@immutable
class ScheduleWeek {
  const ScheduleWeek({
    required this.id,
    required this.name,
    required this.current,
    required this.parity,
    required this.days,
  });

  final int id;
  final String name;
  final bool current;
  final int parity;
  final List<ScheduleDay> days;
}

@immutable
class EntitySchedule {
  const EntitySchedule({
    required this.kind,
    required this.instance,
    required this.weeks,
  });

  final String kind;
  final String instance;
  final List<ScheduleWeek> weeks;

  List<ScheduleDay> get days => [for (final week in weeks) ...week.days];

  ScheduleDay? dayFor(DateTime date) {
    for (final day in days) {
      if (DateUtils.isSameDay(day.date, date)) {
        return day;
      }
    }
    return null;
  }

  ScheduleWeek? weekFor(DateTime date) {
    for (final week in weeks) {
      if (week.days.any((day) => DateUtils.isSameDay(day.date, date))) {
        return week;
      }
    }
    return null;
  }
}
