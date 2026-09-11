import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 112),
              children: [
                Text(
                  'Настройки',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 22),
                _Section(
                  title: 'Оформление',
                  children: [
                    _SettingsTile(
                      icon: Icons.brightness_6_outlined,
                      title: 'Тема',
                      stackTrailingOnNarrow: true,
                      trailing: DropdownButton<ThemeMode>(
                        value: controller.themeMode,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Системная'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Светлая'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Тёмная'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setThemeMode(value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.calendar_view_week_outlined,
                      title: 'Начало недели',
                      stackTrailingOnNarrow: true,
                      trailing: DropdownButton<int>(
                        value: controller.firstDayOfWeek,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(
                            value: DateTime.monday,
                            child: Text('Понедельник'),
                          ),
                          DropdownMenuItem(
                            value: DateTime.sunday,
                            child: Text('Воскресенье'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.setFirstDayOfWeek(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Расписание',
                  children: [
                    _SettingsTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'Запоминать выбор',
                      subtitle:
                          'Открывать последнюю группу или преподавателя при запуске',
                      trailing: Switch.adaptive(
                        value: controller.rememberSelection,
                        onChanged: controller.setRememberSelection,
                      ),
                    ),
                    _SettingsTile(
                      icon: controller.offline
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                      title: 'Синхронизация',
                      subtitle: controller.lastSync == null
                          ? 'Расписание ещё не обновлялось'
                          : DateFormat(
                              'd MMMM, HH:mm',
                              'ru',
                            ).format(controller.lastSync!),
                      trailing: IconButton(
                        onPressed: controller.syncing
                            ? null
                            : controller.refreshAll,
                        icon: controller.syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'О приложении',
                  children: [
                    const _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Расписание',
                      subtitle: 'Версия 1.0.0 · данные rasp-api.rsue.ru',
                    ),
                    _SettingsTile(
                      icon: Icons.offline_bolt_outlined,
                      title: 'Доступ без интернета',
                      subtitle:
                          'Каталог, избранное и просмотренные расписания хранятся на устройстве.',
                      trailing: Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 9),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: .6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.stackTrailingOnNarrow = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool stackTrailingOnNarrow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stackTrailing =
          trailing != null &&
          stackTrailingOnNarrow &&
          constraints.maxWidth < 330;
      final scheme = Theme.of(context).colorScheme;
      final titleStyle = Theme.of(context).textTheme.bodyLarge;
      final subtitleStyle = Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

      Widget textContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackTrailing)
            Text(title, style: titleStyle)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(title, style: titleStyle)),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: subtitleStyle),
          ],
          if (stackTrailing) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: trailing!),
            ),
          ],
        ],
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: textContent()),
          ],
        ),
      );
    },
  );
}
