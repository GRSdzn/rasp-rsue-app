import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../domain/schedule_models.dart';
import 'rsue_api.dart';
import 'schedule_mapper.dart';

class CachedScheduleResult {
  const CachedScheduleResult({required this.schedule, required this.syncedAt});
  final EntitySchedule schedule;
  final DateTime syncedAt;
}

class ScheduleRepository {
  ScheduleRepository(this._database, this._api);

  final AppDatabase _database;
  final RsueApi _api;
  final ScheduleMapper _mapper = const ScheduleMapper();

  Future<void> seedIfNeeded() async {
    if ((await _database.allEntities()).isNotEmpty) return;
    final raw = await rootBundle.loadString('api-search-list.json');
    final values = (jsonDecode(raw) as List).whereType<Map>();
    final now = DateTime.now();
    await _database.replaceEntities(
      values
          .map((value) {
            final id = (value['id'] as num).toInt();
            final name = value['name']?.toString().trim() ?? '';
            final kind = _looksLikeGroup(name)
                ? EntityKind.group
                : EntityKind.teacher;
            return CachedEntityWrite(
              key: id.toString(),
              apiId: id,
              name: name,
              kind: kind.name,
              updatedAt: now,
            );
          })
          .where((row) => row.name.isNotEmpty),
    );
  }

  Future<List<ScheduleEntity>> entities() async =>
      (await _database.allEntities())
          .map(
            (row) => ScheduleEntity(
              apiId: row.apiId,
              name: row.name,
              kind: EntityKind.values.byName(row.kind),
            ),
          )
          .toList(growable: false);

  Future<Set<String>> favoriteKeys() async =>
      (await _database.allFavorites()).map((row) => row.entityKey).toSet();

  Future<void> setFavorite(ScheduleEntity entity, bool favorite) =>
      _database.setFavorite(entity.key, favorite: favorite);

  Future<void> syncCatalogue() async {
    final results = await Future.wait([_api.searchItems(), _api.groupNames()]);
    final items = results[0] as List<Map<String, dynamic>>;
    if (items.isEmpty) throw const FormatException('Empty catalogue response');
    final groups = results[1] as Set<String>;
    final now = DateTime.now();
    await _database.replaceEntities(
      items
          .map((item) {
            final id = (item['id'] as num).toInt();
            final name = item['name']?.toString().trim() ?? '';
            final kind = groups.contains(name) || _looksLikeGroup(name)
                ? EntityKind.group
                : EntityKind.teacher;
            return CachedEntityWrite(
              key: id.toString(),
              apiId: id,
              name: name,
              kind: kind.name,
              updatedAt: now,
            );
          })
          .where((row) => row.name.isNotEmpty),
    );
    await _database.saveSetting('lastCatalogueSync', now.toIso8601String());
  }

  Future<CachedScheduleResult?> cachedSchedule(ScheduleEntity entity) async {
    final cached = await _database.scheduleFor(entity.key);
    if (cached == null) return null;
    return CachedScheduleResult(
      schedule: _mapper.fromJson(
        jsonDecode(cached.rawJson) as Map<String, dynamic>,
      ),
      syncedAt: cached.syncedAt,
    );
  }

  Future<CachedScheduleResult> refreshSchedule(ScheduleEntity entity) async {
    final freshJson = await _api.schedule(entity.name);
    if (freshJson['weeks'] is! List || freshJson['instance'] == null) {
      throw const FormatException('Invalid schedule response');
    }
    final cached = await _database.scheduleFor(entity.key);
    final json = _mergeWeeks(
      cached == null
          ? null
          : jsonDecode(cached.rawJson) as Map<String, dynamic>,
      freshJson,
    );
    final parsed = _mapper.fromJson(json);
    final now = DateTime.now();
    await _database.saveSchedule(
      key: entity.key,
      rawJson: jsonEncode(json),
      syncedAt: now,
    );
    return CachedScheduleResult(schedule: parsed, syncedAt: now);
  }

  Map<String, dynamic> _mergeWeeks(
    Map<String, dynamic>? cached,
    Map<String, dynamic> fresh,
  ) {
    if (cached == null || cached['instance'] != fresh['instance']) return fresh;
    final merged = <String, Map<String, dynamic>>{};
    final freshWeekKeys = <String>{};
    String weekKey(Map<String, dynamic> week) {
      final days = week['days'];
      final firstDate = days is List && days.isNotEmpty && days.first is Map
          ? (days.first as Map)['date']?.toString()
          : null;
      return firstDate ?? 'week:${week['id']}:${week['parity']}';
    }

    for (final source in [cached['weeks'], fresh['weeks']]) {
      if (source is! List) continue;
      for (final value in source.whereType<Map>()) {
        final week = Map<String, dynamic>.from(value);
        final key = weekKey(week);
        merged[key] = week;
        if (identical(source, fresh['weeks'])) freshWeekKeys.add(key);
      }
    }
    for (final entry in merged.entries) {
      if (!freshWeekKeys.contains(entry.key)) entry.value['current'] = false;
    }
    final weeks = merged.values.toList()
      ..sort((a, b) {
        DateTime firstDate(Map<String, dynamic> week) {
          final days = week['days'];
          if (days is! List || days.isEmpty || days.first is! Map) {
            return DateTime(1970);
          }
          return _mapper.parseApiDate((days.first as Map)['date'].toString());
        }

        return firstDate(a).compareTo(firstDate(b));
      });
    return {...fresh, 'weeks': weeks};
  }

  Future<String?> setting(String key) => _database.setting(key);
  Future<void> saveSetting(String key, String value) =>
      _database.saveSetting(key, value);

  bool _looksLikeGroup(String name) {
    if (!name.contains('-')) return false;
    return RegExp(
      r'^[\p{L}\d]{2,12}-[\p{L}\d]{2,12}$',
      unicode: true,
    ).hasMatch(name);
  }
}
