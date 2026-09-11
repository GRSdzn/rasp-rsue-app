import 'dart:io';
import 'package:rsue_rasp_app/features/schedule/data/rsue_api.dart';

bool looksLikeGroup(String name) {
  final normalized = name.trim().toLowerCase();
  return normalized.startsWith('комиссия') ||
      (normalized.contains('-') &&
          RegExp(
            r'^[\p{L}\d]{2,12}-[\p{L}\d]{2,12}$',
            unicode: true,
          ).hasMatch(normalized));
}

Future<void> main() async {
  final api = RsueApi();
  try {
    final items = await api.searchItems();
    stdout.writeln('search: ${items.length} entries');
    final groupCandidates = items
        .where((item) => looksLikeGroup(item['name']?.toString() ?? ''))
        .toList();
    final teacherCandidates = items
        .where((item) => !looksLikeGroup(item['name']?.toString() ?? ''))
        .toList();
    final namedTeachers = teacherCandidates.where((item) {
      final name = item['name']?.toString() ?? '';
      return RegExp(r'\p{L}{2,}\s+\p{L}\.', unicode: true).hasMatch(name);
    }).toList();
    final commissions = items.where((item) {
      final name = item['name']?.toString().trim().toLowerCase() ?? '';
      return name.startsWith('комиссия');
    }).toList();
    final unclassified = teacherCandidates
        .where((item) => !namedTeachers.contains(item))
        .toList();
    stdout.writeln(
      'classified: groups=${groupCandidates.length}, '
      'teachers=${teacherCandidates.length}',
    );
    stdout.writeln(
      'group sample: ${groupCandidates.take(3).map((item) => item['name']).toList()}',
    );
    stdout.writeln(
      'teacher sample: ${namedTeachers.take(3).map((item) => item['name']).toList()}',
    );
    stdout.writeln('search item sample: ${items.take(3).toList()}');
    stdout.writeln(
      'teacher-like=${namedTeachers.length}, commissions=${commissions.length}, '
      'other=${unclassified.length}, '
      'other sample=${unclassified.take(10).map((item) => item['name']).toList()}',
    );
    try {
      final groups = await api.groupNames();
      stdout.writeln('groups: ${groups.length}');
    } catch (error) {
      stderr.writeln('groups: $error');
    }
    for (final item in [groupCandidates.first, namedTeachers.first]) {
      final name = item['name'] as String;
      final schedule = await api.schedule(name);
      stdout.writeln(
        'schedule "$name": keys=${schedule.keys.toList()}, '
        'kind=${schedule['kind']}, weeks=${schedule['weeks'] is List}, '
        'instance=${schedule['instance']}',
      );
    }
  } catch (error, stack) {
    stderr.writeln(error);
    stderr.writeln(stack);
    exitCode = 1;
  }
}
