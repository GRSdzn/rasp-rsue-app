import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../settings/presentation/settings_screen.dart';
import 'app_controller.dart';
import 'schedule_screen.dart';
import 'search_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    if (!controller.initialized) return const _LaunchView();
    final pages = [
      ScheduleScreen(onOpenSearch: () => setState(() => index = 1)),
      SearchScreen(onSelected: () => setState(() => index = 0)),
      const SettingsScreen(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final content = Column(
          children: [
            _ConnectionBanner(controller: controller),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween(
                          begin: const Offset(0, .025),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                ),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
              ),
            ),
          ],
        );
        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: (value) =>
                        setState(() => index = value),
                    extended: constraints.maxWidth >= 1100,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.view_day_outlined),
                        selectedIcon: Icon(Icons.view_day_rounded),
                        label: Text('Расписание'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_rounded),
                        label: Text('Поиск'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: Text('Настройки'),
                      ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: SafeArea(bottom: false, child: content),
          bottomNavigationBar: _BottomNavigation(
            index: index,
            onSelected: (value) => setState(() => index = value),
          ),
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: controller.offline
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: .12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 15,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Офлайн · показаны сохранённые данные',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _LaunchView extends StatelessWidget {
  const _LaunchView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .82, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/branding/app-icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Расписание РГЭУ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.index, required this.onSelected});
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.calendar_month_outlined, 'Расписание'),
      (Icons.search_rounded, 'Поиск'),
      (Icons.tune_rounded, 'Настройки'),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: index == i,
                    child: Tooltip(
                      message: items[i].$2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelected(i),
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                width: 56,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: index == i
                                      ? scheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  items[i].$1,
                                  size: 23,
                                  color: index == i
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
