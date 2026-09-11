import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
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
  final _bottomBarController = BottomBarController();

  void _selectPage(int value) {
    _bottomBarController.show();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => index = value);
  }

  @override
  void dispose() {
    _bottomBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    if (!controller.initialized) return const _LaunchView();
    final pages = [
      ScheduleScreen(
        onOpenSearch: () => _selectPage(1),
        onScrollDown: _bottomBarController.hide,
        onScrollUp: _bottomBarController.show,
      ),
      SearchScreen(onSelected: () => _selectPage(0)),
      const SettingsScreen(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
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

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: BottomBar(
              controller: _bottomBarController,
              layout: const BottomBarLayout(
                width: 272,
                offset: 16,
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              scrollBehavior: BottomBarScrollBehavior(
                showAtStart: true,
                showOnScrollEnd: false,
                predicate: (_) => index != 0,
              ),
              showIcon: false,
              motion: BottomBarMotion.curved(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutQuart,
                transitionBuilder: (context, animation, child) {
                  final progress = animation.value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: .96 + (.04 * progress),
                      alignment: Alignment.bottomCenter,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - progress)),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
              theme: BottomBarThemeData(
                barDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: .16),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
              body: content,
              child: _BottomNavigation(index: index, onSelected: _selectPage),
            ),
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
            Text('Расписание', style: Theme.of(context).textTheme.titleLarge),
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
    const items = [
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        'Расписание',
      ),
      (Icons.search_outlined, Icons.search_rounded, 'Поиск'),
      (Icons.tune_outlined, Icons.tune_rounded, 'Настройки'),
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final selectedWidth = (constraints.maxWidth - 104).clamp(
              124.0,
              152.0,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i != 0) const SizedBox(width: 4),
                  _NavigationDestination(
                    selected: index == i,
                    selectedWidth: selectedWidth,
                    icon: items[i].$1,
                    selectedIcon: items[i].$2,
                    label: items[i].$3,
                    duration: duration,
                    onPressed: () => onSelected(i),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    required this.selected,
    required this.selectedWidth,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.duration,
    required this.onPressed,
  });

  final bool selected;
  final double selectedWidth;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Duration duration;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeInOutCubicEmphasized,
          width: selected ? selectedWidth : 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(24),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return scheme.primary.withValues(alpha: .14);
                }
                if (states.contains(WidgetState.hovered)) {
                  return scheme.onSurface.withValues(alpha: .06);
                }
                if (states.contains(WidgetState.focused)) {
                  return scheme.primary.withValues(alpha: .08);
                }
                return null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        selected ? selectedIcon : icon,
                        key: ValueKey(selected),
                        size: 21,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            alignment: Alignment.centerLeft,
                            child: child,
                          ),
                        ),
                        child: selected
                            ? Padding(
                                key: ValueKey(label),
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('collapsed')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
