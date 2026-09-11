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

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Найти расписание',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<EntityKind>(
                        style: const ButtonStyle(
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: EntityKind.group,
                            icon: Icon(Icons.groups_outlined, size: 18),
                            label: Text('Группы'),
                          ),
                          ButtonSegment(
                            value: EntityKind.teacher,
                            icon: Icon(Icons.person_outline_rounded, size: 18),
                            label: Text('Преподаватели'),
                          ),
                        ],
                        selected: {controller.searchKind},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) {
                          searchController.clear();
                          controller.setSearchKind(value.first);
                        },
                      ),
                      const SizedBox(height: 14),
                      SearchBar(
                        controller: searchController,
                        hintText: controller.searchKind == EntityKind.group
                            ? 'Название группы'
                            : 'Фамилия преподавателя',
                        leading: const Icon(Icons.search_rounded),
                        trailing: [
                          if (query.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: WidgetStatePropertyAll(
                          Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              maxLines: 2,
                              query.isEmpty
                                  ? 'Избранное в начале · ${matches.length}'
                                  : 'Найдено: ${matches.length}',
                              style: Theme.of(context).textTheme.labelLarge
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              tooltip: 'Обновить каталог',
                              onPressed: controller.refreshCatalogue,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (controller.catalogueError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      controller.catalogueError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: matches.isEmpty
                        ? _NoResults(query: query)
                        : ListView.separated(
                            key: ValueKey(
                              '${controller.searchKind.name}:$query',
                            ),
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 3),
                            itemBuilder: (context, index) {
                              final entity = matches[index];
                              final favorite = controller.favoriteKeys.contains(
                                entity.key,
                              );
                              return ListTile(
                                key: ValueKey(entity.key),
                                tileColor: favorite
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: .45)
                                    : null,
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
                                    color: Theme.of(context).colorScheme.primary
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
                                    duration: const Duration(milliseconds: 160),
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
