import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/database/app_database.dart';
import '../features/schedule/data/rsue_api.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/presentation/app_controller.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final apiProvider = Provider<RsueApi>((ref) => RsueApi());

final repositoryProvider = Provider<ScheduleRepository>(
  (ref) =>
      ScheduleRepository(ref.watch(databaseProvider), ref.watch(apiProvider)),
);

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final controller = AppController(ref.watch(repositoryProvider));
  Future.microtask(controller.initialize);
  return controller;
});
