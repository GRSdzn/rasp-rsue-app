import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedEntityRow {
  const CachedEntityRow({
    required this.key,
    required this.apiId,
    required this.name,
    required this.kind,
    required this.updatedAt,
  });

  final String key;
  final int apiId;
  final String name;
  final String kind;
  final DateTime updatedAt;
}

class CachedEntityWrite {
  const CachedEntityWrite({
    required this.key,
    required this.apiId,
    required this.name,
    required this.kind,
    required this.updatedAt,
  });

  final String key;
  final int apiId;
  final String name;
  final String kind;
  final DateTime updatedAt;
}

class FavoriteEntityRow {
  const FavoriteEntityRow({required this.entityKey, required this.createdAt});
  final String entityKey;
  final DateTime createdAt;
}

class ScheduleCacheRow {
  const ScheduleCacheRow({
    required this.entityKey,
    required this.rawJson,
    required this.syncedAt,
  });

  final String entityKey;
  final String rawJson;
  final DateTime syncedAt;
}

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE entities ('
        'entity_key TEXT PRIMARY KEY NOT NULL, '
        'api_id INTEGER NOT NULL, '
        'name TEXT NOT NULL, '
        'kind TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      );
      await customStatement(
        'CREATE INDEX entities_name ON entities(name COLLATE NOCASE)',
      );
      await customStatement(
        'CREATE TABLE favorites ('
        'entity_key TEXT PRIMARY KEY NOT NULL, '
        'created_at INTEGER NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE schedule_cache ('
        'entity_key TEXT PRIMARY KEY NOT NULL, '
        'raw_json TEXT NOT NULL, '
        'synced_at INTEGER NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE app_settings ('
        'setting_key TEXT PRIMARY KEY NOT NULL, '
        'setting_value TEXT NOT NULL)',
      );
    },
  );

  Future<List<CachedEntityRow>> allEntities() async {
    final rows = await customSelect(
      'SELECT * FROM entities ORDER BY name COLLATE NOCASE',
    ).get();
    return rows
        .map(
          (row) => CachedEntityRow(
            key: row.read<String>('entity_key'),
            apiId: row.read<int>('api_id'),
            name: row.read<String>('name'),
            kind: row.read<String>('kind'),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('updated_at'),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> replaceEntities(Iterable<CachedEntityWrite> rows) => transaction(
    () async {
      await customStatement('DELETE FROM entities');
      for (final row in rows) {
        await customStatement(
          'INSERT OR REPLACE INTO entities '
          '(entity_key, api_id, name, kind, updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            row.key,
            row.apiId,
            row.name,
            row.kind,
            row.updatedAt.millisecondsSinceEpoch,
          ],
        );
      }
    },
  );

  Future<List<FavoriteEntityRow>> allFavorites() async {
    final rows = await customSelect(
      'SELECT * FROM favorites ORDER BY created_at DESC',
    ).get();
    return rows
        .map(
          (row) => FavoriteEntityRow(
            entityKey: row.read<String>('entity_key'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('created_at'),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> setFavorite(String key, {required bool favorite}) => favorite
      ? customStatement(
          'INSERT OR REPLACE INTO favorites (entity_key, created_at) VALUES (?, ?)',
          [key, DateTime.now().millisecondsSinceEpoch],
        )
      : customStatement('DELETE FROM favorites WHERE entity_key = ?', [key]);

  Future<ScheduleCacheRow?> scheduleFor(String key) async {
    final row = await customSelect(
      'SELECT * FROM schedule_cache WHERE entity_key = ? LIMIT 1',
      variables: [Variable<String>(key)],
    ).getSingleOrNull();
    if (row == null) return null;
    return ScheduleCacheRow(
      entityKey: row.read<String>('entity_key'),
      rawJson: row.read<String>('raw_json'),
      syncedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('synced_at')),
    );
  }

  Future<void> saveSchedule({
    required String key,
    required String rawJson,
    required DateTime syncedAt,
  }) => customStatement(
    'INSERT OR REPLACE INTO schedule_cache (entity_key, raw_json, synced_at) VALUES (?, ?, ?)',
    [key, rawJson, syncedAt.millisecondsSinceEpoch],
  );

  Future<String?> setting(String key) async => (await customSelect(
    'SELECT setting_value FROM app_settings WHERE setting_key = ? LIMIT 1',
    variables: [Variable<String>(key)],
  ).getSingleOrNull())?.read<String>('setting_value');

  Future<void> saveSetting(String key, String value) => customStatement(
    'INSERT OR REPLACE INTO app_settings (setting_key, setting_value) VALUES (?, ?)',
    [key, value],
  );
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(directory.path, 'rsue_schedule.sqlite')),
  );
});
