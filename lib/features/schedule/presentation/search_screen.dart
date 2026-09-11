import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/schedule_models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.onSelected});
  final VoidCallback onSelected;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final searchController = TextEditingController();
  final _topHeaderKey = GlobalKey();
  final _bottomHeaderKey = GlobalKey();
  late final AnimationController _headerController;
  late final Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _headerController.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
  }

  @override
  void dispose() {
    _headerController.dispose();
    searchController.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <=
        notification.metrics.minScrollExtent + 1) {
      _showHeader();
      return false;
    }
    if (notification case ScrollUpdateNotification(:final scrollDelta)) {
      final delta = scrollDelta ?? 0;
      if (delta > 3 && _canKeepScrollingAfterCollapse(notification.metrics)) {
        _headerController.reverse();
      } else if (delta < -3) {
        _showHeader();
      }
    }
    return false;
  }

  bool _canKeepScrollingAfterCollapse(ScrollMetrics metrics) {
    double heightOf(GlobalKey key) =>
        (key.currentContext?.findRenderObject() as RenderBox?)?.size.height ??
        0;
    final collapsibleHeight =
        heightOf(_topHeaderKey) + heightOf(_bottomHeaderKey);
    final scrollRange = metrics.maxScrollExtent - metrics.minScrollExtent;
    return scrollRange > collapsibleHeight + 8;
  }

  void _showHeader() {
    if (!_headerController.isCompleted) _headerController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final query = searchController.text.trim().toLowerCase();
    final matches =
        controller.entities
            .where((entity) => entity.kind == controller.searchKind)
            .where(
              (entity) =>
                  query.isEmpty || entity.name.toLowerCase().contains(query),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final favoriteOrder =
                (controller.favoriteKeys.contains(b.key) ? 1 : 0).compareTo(
                  controller.favoriteKeys.contains(a.key) ? 1 : 0,
                );
            return favoriteOrder != 0
                ? favoriteOrder
                : a.name.compareTo(b.name);
          });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizeTransition(
                        sizeFactor: _headerAnimation,
                        alignment: Alignment.topCenter,
                        child: FadeTransition(
                          opacity: _headerAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -.12),
                              end: Offset.zero,
                            ).animate(_headerAnimation),
                            child: Padding(
                              key: _topHeaderKey,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Найти расписание',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  SegmentedButton<EntityKind>(
                                    style: const ButtonStyle(
                                      padding: WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                    ),
                                    segments: const [
                                      ButtonSegment(
                                        value: EntityKind.group,
                                        icon: Icon(
                                          Icons.groups_outlined,
                                          size: 18,
                                        ),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Группы'),
                                        ),
                                      ),
                                      ButtonSegment(
                                        value: EntityKind.teacher,
                                        icon: Icon(
                                          Icons.person_outline_rounded,
                                          size: 18,
                                        ),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Преподаватели'),
                                        ),
                                      ),
                                    ],
                                    selected: {controller.searchKind},
                                    showSelectedIcon: false,
                                    onSelectionChanged: (value) {
                                      searchController.clear();
                                      _showHeader();
                                      controller.setSearchKind(value.first);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _headerAnimation,
                        builder: (context, child) {
                          final value = _headerAnimation.value;
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              8 * (1 - value),
                              20,
                              8,
                            ),
                            child: SearchBar(
                              controller: searchController,
                              constraints: BoxConstraints.tightFor(
                                height: 48 + (8 * value),
                              ),
                              hintText:
                                  controller.searchKind == EntityKind.group
                                  ? 'Название группы'
                                  : 'Фамилия преподавателя',
                              leading: const Icon(Icons.search_rounded),
                              trailing: [
                                if (query.isNotEmpty)
                                  IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      _showHeader();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                              ],
                              elevation: const WidgetStatePropertyAll(0),
                              backgroundColor: WidgetStatePropertyAll(
                                Theme.of(context).colorScheme.surfaceContainer,
                              ),
                              onChanged: (_) {
                                _showHeader();
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                      SizeTransition(
                        sizeFactor: _headerAnimation,
                        alignment: Alignment.topCenter,
                        child: FadeTransition(
                          opacity: _headerAnimation,
                          child: Padding(
                            key: _bottomHeaderKey,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        maxLines: 2,
                                        query.isEmpty
                                            ? 'Избранное в начале · ${matches.length}'
                                            : 'Найдено: ${matches.length}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    if (controller.syncing)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        tooltip: 'Обновить каталог',
                                        onPressed: controller.refreshCatalogue,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                                if (controller.catalogueError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      controller.catalogueError!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScroll,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: matches.isEmpty
                          ? _NoResults(query: query)
                          : ListView.separated(
                              key: ValueKey(
                                '${controller.searchKind.name}:$query',
                              ),
                              physics: const BouncingScrollPhysics(),
                              clipBehavior: Clip.hardEdge,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                102,
                              ),
                              itemCount: matches.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 3),
                              itemBuilder: (context, index) {
                                final entity = matches[index];
                                final favorite = controller.favoriteKeys
                                    .contains(entity.key);
                                return ListTile(
                                  key: ValueKey(entity.key),
                                  contentPadding: const EdgeInsets.only(
                                    left: 12,
                                    right: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .09),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      entity.kind == EntityKind.group
                                          ? Icons.groups_outlined
                                          : Icons.person_outline_rounded,
                                      size: 21,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    entity.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    entity.kind == EntityKind.group
                                        ? 'Группа'
                                        : 'Преподаватель',
                                  ),
                                  trailing: IconButton(
                                    tooltip: favorite
                                        ? 'Убрать из избранного'
                                        : 'В избранное',
                                    onPressed: () =>
                                        controller.toggleFavorite(entity),
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      child: Icon(
                                        favorite
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        key: ValueKey(favorite),
                                        color: favorite
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.secondary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    controller.selectEntity(entity);
                                    widget.onSelected();
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 46,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            query.isEmpty ? 'Список пока пуст' : 'Ничего не найдено',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Потяните вниз или обновите каталог.'
                : 'Проверьте написание имени.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
