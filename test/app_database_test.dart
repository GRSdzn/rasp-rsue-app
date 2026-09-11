import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/core/database/app_database.dart';

void main() {
  test(
    'first launch persists catalogue, favorites, schedules and settings',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime(2026, 9, 11);

      expect(await database.allEntities(), isEmpty);
      await database.replaceEntities([
        CachedEntityWrite(
          key: '42',
          apiId: 42,
          name: 'ПИ-101',
          kind: 'group',
          updatedAt: now,
        ),
      ]);
      final entities = await database.allEntities();
      expect(entities.single.name, 'ПИ-101');
      expect(entities.single.apiId, 42);
      expect(entities.single.updatedAt, now);

      await database.setFavorite('42', favorite: true);
      expect((await database.allFavorites()).single.entityKey, '42');
      await database.setFavorite('42', favorite: false);
      expect(await database.allFavorites(), isEmpty);

      await database.saveSchedule(
        key: '42',
        rawJson: '{"weeks":[]}',
        syncedAt: now,
      );
      final schedule = await database.scheduleFor('42');
      expect(schedule?.rawJson, '{"weeks":[]}');
      expect(schedule?.syncedAt, now);

      await database.saveSetting('themeMode', 'dark');
      expect(await database.setting('themeMode'), 'dark');
      await database.saveSetting('themeMode', 'light');
      expect(await database.setting('themeMode'), 'light');
    },
  );
}
