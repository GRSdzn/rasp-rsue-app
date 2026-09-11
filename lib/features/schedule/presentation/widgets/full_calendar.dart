import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';

Future<void> showFullCalendar(BuildContext context, AppController controller) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => FullCalendar(controller: controller),
    );

class FullCalendar extends StatefulWidget {
  const FullCalendar({super.key, required this.controller});
  final AppController controller;
  @override
  State<FullCalendar> createState() => _FullCalendarState();
}

class _FullCalendarState extends State<FullCalendar> {
  late DateTime month = DateTime(
    widget.controller.selectedDate.year,
    widget.controller.selectedDate.month,
  );

  void shift(int count) =>
      setState(() => month = DateTime(month.year, month.month + count));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final scheme = Theme.of(context).colorScheme;
      final offset = (month.weekday - controller.firstDayOfWeek + 7) % 7;
      final count = DateUtils.getDaysInMonth(month.year, month.month);
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Календарь',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        final now = DateTime.now();
                        month = DateTime(now.year, now.month);
                      }),
                      child: const Text('Текущий месяц'),
                    ),
                    IconButton(
                      tooltip: 'Закрыть календарь',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий месяц',
                      onPressed: () => shift(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('LLLL', 'ru').format(month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    DropdownButton<int>(
                      value: month.year,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (
                          var year = month.year - 10;
                          year <= month.year + 10;
                          year++
                        )
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (year) {
                        if (year != null) {
                          setState(() => month = DateTime(year, month.month));
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Следующий месяц',
                      onPressed: () => shift(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('EE', 'ru').format(
                              DateTime(2026, 6, controller.firstDayOfWeek + i),
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() > 150) shift(velocity < 0 ? 1 : -1);
                  },
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: GridView.builder(
                        key: ValueKey(month),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: 52,
                            ),
                        itemCount: ((offset + count + 6) ~/ 7) * 7,
                        itemBuilder: (context, index) {
                          final number = index - offset + 1;
                          if (number < 1 || number > count) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime(
                            month.year,
                            month.month,
                            number,
                          );
                          final day = controller.schedule?.dayFor(date);
                          final selected = DateUtils.isSameDay(
                            date,
                            controller.selectedDate,
                          );
                          final today = DateUtils.isSameDay(
                            date,
                            DateTime.now(),
                          );
                          final foreground = selected
                              ? scheme.onPrimary
                              : scheme.onSurface;
                          final status = day == null
                              ? 'данные не загружены'
                              : day.hasLessons
                              ? 'есть занятия'
                              : 'занятий нет';
                          return Semantics(
                            button: true,
                            selected: selected,
                            label:
                                '${DateFormat('d MMMM y', 'ru').format(date)}, $status',
                            child: Tooltip(
                              message: status,
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Material(
                                  color: selected
                                      ? scheme.primary
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: today && !selected
                                        ? BorderSide(color: scheme.primary)
                                        : BorderSide.none,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      controller.selectDate(date);
                                      controller.setViewMode(
                                        ScheduleViewMode.day,
                                      );
                                      Navigator.pop(context);
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$number',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(color: foreground),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: day?.hasLessons == true
                                                ? (selected
                                                      ? scheme.onPrimary
                                                      : scheme.primary)
                                                : Colors.transparent,
                                            border:
                                                day != null && !day.hasLessons
                                                ? Border.all(
                                                    color: selected
                                                        ? scheme.onPrimary
                                                        : scheme
                                                              .onSurfaceVariant,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _Legend(color: scheme.primary, text: 'Есть занятия'),
                    _Legend(
                      color: scheme.onSurfaceVariant,
                      text: 'Свободный день',
                      outlined: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Без отметки — данные за день ещё не загружены.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.text,
    this.outlined = false,
  });
  final Color color;
  final String text;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: outlined ? Colors.transparent : color,
          border: Border.all(color: color),
        ),
      ),
      const SizedBox(width: 6),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
