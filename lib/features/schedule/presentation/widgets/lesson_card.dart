import 'package:flutter/material.dart';

import '../../domain/schedule_models.dart';

enum LessonMoment { completed, current, upcoming }

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.pair,
    required this.lesson,
    required this.moment,
    required this.entityKind,
  });

  final SchedulePair pair;
  final Lesson lesson;
  final LessonMoment moment;
  final EntityKind entityKind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = moment == LessonMoment.current;
    final completed = moment == LessonMoment.completed;
    final accent = scheme.primary;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: current ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: current
                ? accent.withValues(alpha: .65)
                : scheme.outlineVariant,
          ),
          boxShadow: [
            if (!completed)
              BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.start,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: current ? accent : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pair.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 1,
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 13),
              color: current
                  ? accent.withValues(alpha: .3)
                  : scheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (current)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'ИДЁТ ПАРА',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                  Text(
                    lesson.subject.isEmpty ? 'Без названия' : lesson.subject,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (lesson.lessonKind.isNotEmpty)
                        _Meta(
                          icon: Icons.school_outlined,
                          text: lesson.lessonKind,
                        ),
                      if (entityKind == EntityKind.group &&
                          lesson.teacher.isNotEmpty)
                        _Meta(
                          icon: Icons.person_outline_rounded,
                          text: lesson.teacher,
                        ),
                      if (entityKind == EntityKind.teacher &&
                          lesson.group.isNotEmpty)
                        _Meta(icon: Icons.groups_outlined, text: lesson.group),
                      if (lesson.audience.isNotEmpty)
                        _Meta(
                          icon: Icons.location_on_outlined,
                          text: lesson.audience,
                        ),
                      if (lesson.subgroup.isNotEmpty)
                        _Meta(
                          icon: Icons.call_split_rounded,
                          text: lesson.subgroup,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

LessonMoment lessonMoment(DateTime date, SchedulePair pair, DateTime now) {
  DateTime? time(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  final start = time(pair.start);
  final end = time(pair.end);
  if (start == null || end == null || !end.isAfter(start)) {
    return LessonMoment.upcoming;
  }
  if (!now.isBefore(end)) return LessonMoment.completed;
  return !now.isBefore(start) ? LessonMoment.current : LessonMoment.upcoming;
}
