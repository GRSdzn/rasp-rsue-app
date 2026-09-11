import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';

class WeekCalendar extends StatelessWidget {
  const WeekCalendar({super.key, required this.controller});

  final AppController controller;

  DateTime _weekStart(DateTime value) {
    final offset = (value.weekday - controller.firstDayOfWeek + 7) % 7;
    return DateUtils.dateOnly(value.subtract(Duration(days: offset)));
  }

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(controller.selectedDate);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) return;
        controller.shiftWeek(velocity < 0 ? 1 : -1);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(.045, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(start),
          children: [
            for (final day in days)
              Expanded(
                child: _DayCell(
                  date: day,
                  selected: DateUtils.isSameDay(day, controller.selectedDate),
                  today: DateUtils.isSameDay(day, DateTime.now()),
                  hasLessons:
                      controller.schedule?.dayFor(day)?.hasLessons ?? false,
                  onTap: () => controller.selectDate(day),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasLessons,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool hasLessons;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: DateFormat('EEEE, d MMMM', 'ru').format(date),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: today && !selected
                ? Border.all(color: scheme.primary.withValues(alpha: .35))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat(
                  'EE',
                  'ru',
                ).format(date).replaceAll('.', '').toUpperCase(),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date.day.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: today ? 5 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected && (today || hasLessons)
                      ? scheme.onPrimary
                      : today
                      ? scheme.primary
                      : hasLessons
                      ? scheme.secondary.withValues(alpha: .7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
