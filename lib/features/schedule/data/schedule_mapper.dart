import '../domain/schedule_models.dart';

class ScheduleMapper {
  const ScheduleMapper();

  EntitySchedule fromJson(Map<String, dynamic> json) => EntitySchedule(
    kind: _text(json['kind']),
    instance: _text(json['instance']),
    weeks: _list(json['weeks']).map(_week).toList(growable: false),
  );

  ScheduleWeek _week(dynamic source) {
    final json = _map(source);
    return ScheduleWeek(
      id: _integer(json['id']),
      name: _text(json['name']),
      current: json['current'] == true,
      parity: _integer(json['parity']),
      days: _list(json['days']).map(_day).toList(growable: false),
    );
  }

  ScheduleDay _day(dynamic source) {
    final json = _map(source);
    return ScheduleDay(
      id: _integer(json['id']),
      date: parseApiDate(_text(json['date'])),
      name: _text(json['name']),
      pairs: _list(json['pairs']).map(_pair).toList(growable: false),
    );
  }

  SchedulePair _pair(dynamic source) {
    final json = _map(source);
    return SchedulePair(
      id: _integer(json['id']),
      start: _clock(json['startTime']),
      end: _clock(json['endTime']),
      lessons: _list(json['lessons']).map(_lesson).toList(growable: false),
    );
  }

  Lesson _lesson(dynamic source) {
    final json = _map(source);
    return Lesson(
      id: _integer(json['id']),
      subject: _text(json['subject']),
      teacher: _nestedName(json['teacher']),
      group: _text(json['group']),
      lessonKind: _nestedName(json['kind']),
      subgroup: _nestedName(json['subgroup']),
      audience: _text(json['audience']),
    );
  }

  DateTime parseApiDate(String value) {
    final parts = value.split('.');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
    return DateTime.parse(value);
  }

  String _nestedName(dynamic value) =>
      value is Map ? _text(value['name']) : _text(value);
  String _clock(dynamic value) => _text(value).split(':').take(2).join(':');
  String _text(dynamic value) => value?.toString().trim() ?? '';
  int _integer(dynamic value) =>
      value is int ? value : int.tryParse(_text(value)) ?? 0;
  Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
      ? value
      : Map<String, dynamic>.from(value as Map);
  List<dynamic> _list(dynamic value) => value is List ? value : const [];
}
