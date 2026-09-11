import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../domain/schedule_models.dart';
import '../domain/schedule_share.dart';
import 'app_controller.dart';
import 'widgets/lesson_card.dart';
import 'widgets/full_calendar.dart';
import 'widgets/week_calendar.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({
    super.key,
    required this.onOpenSearch,
    required this.onScrollDown,
    required this.onScrollUp,
  });
  final VoidCallback onOpenSearch;
  final VoidCallback onScrollDown;
  final VoidCallback onScrollUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final main = controller.selectedEntity == null
        ? _Welcome(controller: controller, onOpenSearch: onOpenSearch)
        : _ScheduleContent(
            controller: controller,
            onScrollDown: onScrollDown,
            onScrollUp: onScrollUp,
          );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                SizedBox(
                  width: 300,
                  child: _FavoriteSidebar(
                    controller: controller,
                    onOpenSearch: onOpenSearch,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: main),
              ],
            )
          : main,
    );
  }
}

class _ScheduleContent extends StatefulWidget {
  const _ScheduleContent({
    required this.controller,
    required this.onScrollDown,
    required this.onScrollUp,
  });
  final AppController controller;
  final VoidCallback onScrollDown;
  final VoidCallback onScrollUp;

  @override
  State<_ScheduleContent> createState() => _ScheduleContentState();
}

class _ScheduleContentState extends State<_ScheduleContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _calendarController;
  late final Animation<double> _calendarAnimation;
  final _calendarKey = GlobalKey();

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _calendarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    _calendarAnimation = CurvedAnimation(
      parent: _calendarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calendarController.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
  }

  @override
  void didUpdateWidget(covariant _ScheduleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.selectedEntity?.key !=
        widget.controller.selectedEntity?.key) {
      _showCalendar();
    }
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <=
        notification.metrics.minScrollExtent + 1) {
      _showCalendar();
      widget.onScrollUp();
      return false;
    }
    if (notification case ScrollUpdateNotification(:final scrollDelta)) {
      final delta = scrollDelta ?? 0;
      if (delta > 3) {
        if (_canKeepScrollingAfterCollapse(notification.metrics)) {
          _hideCalendar();
          widget.onScrollDown();
        } else {
          _showCalendar();
          widget.onScrollUp();
        }
      } else if (delta < -3) {
        _showCalendar();
        widget.onScrollUp();
      }
    }
    return false;
  }

  bool _canKeepScrollingAfterCollapse(ScrollMetrics metrics) {
    final renderBox =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    final calendarHeight = renderBox?.size.height ?? 120;
    final scrollRange = metrics.maxScrollExtent - metrics.minScrollExtent;
    return scrollRange > calendarHeight + 8;
  }

  void _showCalendar() {
    if (!_calendarController.isCompleted) {
      _calendarController.forward();
    }
  }

  void _hideCalendar() {
    if (!_calendarController.isDismissed) {
      _calendarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entity = controller.selectedEntity!;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.kind == EntityKind.group
                            ? 'Расписание группы'
                            : 'Расписание преподавателя',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: controller.favoriteKeys.contains(entity.key)
                      ? 'Убрать из избранного'
                      : 'В избранное',
                  onPressed: () => controller.toggleFavorite(entity),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      controller.favoriteKeys.contains(entity.key)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      key: ValueKey(
                        controller.favoriteKeys.contains(entity.key),
                      ),
                      color: controller.favoriteKeys.contains(entity.key)
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить расписание',
                  onPressed: controller.syncing
                      ? null
                      : controller.refreshSchedule,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Поделиться',
                  onPressed: controller.schedule == null
                      ? null
                      : () => _share(context, controller),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
          ),
          SizeTransition(
            sizeFactor: _calendarAnimation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _calendarAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -.12),
                  end: Offset.zero,
                ).animate(_calendarAnimation),
                child: Padding(
                  key: _calendarKey,
                  padding: const EdgeInsets.fromLTRB(18, 5, 18, 10),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 330;
                          return Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<ScheduleViewMode>(
                                  style: const ButtonStyle(
                                    padding: WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: ScheduleViewMode.day,
                                      label: Text('День', maxLines: 1),
                                    ),
                                    ButtonSegment(
                                      value: ScheduleViewMode.week,
                                      label: Text('Неделя', maxLines: 1),
                                    ),
                                  ],
                                  selected: {controller.viewMode},
                                  showSelectedIcon: false,
                                  onSelectionChanged: (value) =>
                                      controller.setViewMode(value.first),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Открыть календарь',
                                onPressed: () =>
                                    showFullCalendar(context, controller),
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                              if (compact)
                                IconButton(
                                  tooltip: 'Сегодня',
                                  onPressed: controller.goToday,
                                  icon: const Icon(
                                    Icons.near_me_outlined,
                                    size: 19,
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: controller.goToday,
                                  icon: const Icon(
                                    Icons.near_me_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Сегодня'),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      WeekCalendar(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: RefreshIndicator.adaptive(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                displacement: 48,
                strokeWidth: 2.5,
                semanticsLabel: 'Обновить расписание',
                onRefresh: controller.refreshSchedule,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  child: controller.schedule == null
                      ? _LoadingSchedule(error: controller.errorMessage)
                      : controller.viewMode == ScheduleViewMode.day
                      ? _DayList(controller: controller)
                      : _WeekList(controller: controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, AppController controller) async {
    final entity = controller.selectedEntity!;
    final schedule = controller.schedule!;
    final formatter = const ScheduleShare();
    final text = controller.viewMode == ScheduleViewMode.week
        ? schedule.weekFor(controller.selectedDate) == null
              ? null
              : formatter.week(
                  entity: entity,
                  week: schedule.weekFor(controller.selectedDate)!,
                )
        : schedule.dayFor(controller.selectedDate) == null
        ? null
        : formatter.day(
            entity: entity,
            day: schedule.dayFor(controller.selectedDate)!,
          );
    if (text == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            '$text\n\nrsue-schedule://schedule?entity=${Uri.encodeComponent(entity.name)}'
            '&kind=${entity.kind.name}&date=${controller.selectedDate.toIso8601String()}'
            '&mode=${controller.viewMode.name}',
        subject: 'Расписание · ${entity.name}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class _DayList extends StatefulWidget {
  const _DayList({required this.controller});
  final AppController controller;

  @override
  State<_DayList> createState() => _DayListState();
}

class _DayListState extends State<_DayList> {
  final scrollController = ScrollController();
  DateTime? positionedDate;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final day = controller.schedule!.dayFor(controller.selectedDate);
    _positionNearRelevantLesson(day);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() >= 220) controller.shiftDay(velocity < 0 ? 1 : -1);
      },
      child: ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
        children: [
          _DateHeading(controller: controller),
          const SizedBox(height: 15),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: day == null || !day.hasLessons
                ? _EmptyDay(key: ValueKey(controller.selectedDate))
                : Column(
                    key: ValueKey(day.date),
                    children: [
                      for (final pair in day.occupiedPairs)
                        for (final lesson in pair.lessons)
                          LessonCard(
                            key: ValueKey(
                              '${day.date}-${pair.id}-${lesson.id}',
                            ),
                            pair: pair,
                            lesson: lesson,
                            moment: _moment(day.date, pair),
                            entityKind: controller.selectedEntity!.kind,
                          ),
                    ],
                  ),
          ),
          _SyncFooter(controller: controller),
        ],
      ),
    );
  }

  void _positionNearRelevantLesson(ScheduleDay? day) {
    final selected = widget.controller.selectedDate;
    if (day == null ||
        !day.hasLessons ||
        DateUtils.isSameDay(positionedDate, selected)) {
      return;
    }
    positionedDate = selected;
    final pairs = day.occupiedPairs.toList();
    var relevantIndex = pairs.indexWhere(
      (pair) => _moment(day.date, pair) == LessonMoment.current,
    );
    relevantIndex = relevantIndex >= 0
        ? relevantIndex
        : pairs.indexWhere(
            (pair) => _moment(day.date, pair) == LessonMoment.upcoming,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final target = relevantIndex <= 0
          ? 0.0
          : (relevantIndex * 132.0).clamp(
              0.0,
              scrollController.position.maxScrollExtent,
            );
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final week = controller.schedule!.weekFor(controller.selectedDate);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
      children: [
        _DateHeading(controller: controller),
        const SizedBox(height: 14),
        if (week == null || !week.days.any((day) => day.hasLessons))
          const _EmptyDay()
        else
          for (final day in week.days.where((item) => item.hasLessons)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE', 'ru').format(day.date),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('d MMMM', 'ru').format(day.date),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final pair in day.occupiedPairs)
              for (final lesson in pair.lessons)
                LessonCard(
                  pair: pair,
                  lesson: lesson,
                  moment: _moment(day.date, pair),
                  entityKind: controller.selectedEntity!.kind,
                ),
          ],
        _SyncFooter(controller: controller),
      ],
    );
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final week = controller.schedule?.weekFor(controller.selectedDate);
    return Row(
      children: [
        Expanded(
          child: Text(
            controller.viewMode == ScheduleViewMode.day
                ? DateFormat(
                    'EEEE, d MMMM',
                    'ru',
                  ).format(controller.selectedDate)
                : week?.name ?? 'Неделя',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (controller.syncing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _SyncFooter extends StatelessWidget {
  const _SyncFooter({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text =
        controller.errorMessage ??
        (controller.lastSync == null
            ? null
            : 'Обновлено ${DateFormat('d MMM, HH:mm', 'ru').format(controller.lastSync!)}');
    if (text == null) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            controller.offline || controller.errorMessage != null
                ? Icons.cloud_off_outlined
                : Icons.cloud_done_outlined,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Icon(
            Icons.free_breakfast_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 17),
        Text('Занятий нет', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Можно выдохнуть — этот день свободен.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _LoadingSchedule extends StatelessWidget {
  const _LoadingSchedule({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
    children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 14),
              Text(error!, textAlign: TextAlign.center),
            ],
          ),
        )
      else
        for (var i = 0; i < 4; i++)
          Container(
            height: 112,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
    ],
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.controller, required this.onOpenSearch});
  final AppController controller;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 34, 22, 108),
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ваш день,\nодним взглядом',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 13),
            Text(
              'Выберите группу или преподавателя. Расписание сохранится и останется доступным без интернета.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Найти расписание'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      if (controller.favorites.isNotEmpty) ...[
        const SizedBox(height: 38),
        Text('Избранное', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entity in controller.favorites)
              ActionChip(
                avatar: Icon(
                  entity.kind == EntityKind.group
                      ? Icons.groups_outlined
                      : Icons.person_outline,
                  size: 18,
                ),
                label: Text(entity.name),
                onPressed: () => controller.selectEntity(entity),
              ),
          ],
        ),
      ],
    ],
  );
}

class _FavoriteSidebar extends StatelessWidget {
  const _FavoriteSidebar({
    required this.controller,
    required this.onOpenSearch,
  });
  final AppController controller;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Избранное', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Expanded(
            child: controller.favorites.isEmpty
                ? Text(
                    'Добавьте группу или преподавателя для быстрого доступа.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : ListView(
                    children: [
                      for (final entity in controller.favorites)
                        ListTile(
                          selected:
                              controller.selectedEntity?.key == entity.key,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .09),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            entity.kind == EntityKind.group
                                ? Icons.groups_outlined
                                : Icons.person_outline_rounded,
                          ),
                          title: Text(
                            entity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => controller.selectEntity(entity),
                        ),
                    ],
                  ),
          ),
          FilledButton.tonalIcon(
            onPressed: onOpenSearch,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Найти'),
          ),
        ],
      ),
    ),
  );
}

LessonMoment _moment(DateTime date, SchedulePair pair) =>
    lessonMoment(date, pair, DateTime.now());
