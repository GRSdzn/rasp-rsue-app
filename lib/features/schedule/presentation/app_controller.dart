import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/schedule_repository.dart';
import '../domain/schedule_models.dart';

enum ScheduleViewMode { day, week }

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController(this._repository, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  Timer? _clockTimer;
  Timer? _retryTimer;
  Timer? _connectionDebounce;
  bool _disposed = false;
  int _selectionVersion = 0;
  int _connectionVersion = 0;
  Future<void> _selectionWrite = Future.value();
  Future<void>? _catalogueRefresh;
  Future<void>? _scheduleRefresh;
  int? _scheduleRefreshVersion;
  DateTime now = DateTime.now();

  final ScheduleRepository _repository;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool initialized = false;
  bool _catalogueSyncing = false;
  bool _scheduleSyncing = false;
  bool offline = false;
  String? errorMessage;
  List<ScheduleEntity> entities = const [];
  Set<String> favoriteKeys = {};
  ScheduleEntity? selectedEntity;
  EntitySchedule? schedule;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime? lastSync;
  EntityKind searchKind = EntityKind.group;
  ScheduleViewMode viewMode = ScheduleViewMode.day;
  ThemeMode themeMode = ThemeMode.system;
  int firstDayOfWeek = DateTime.monday;
  bool rememberSelection = true;
  String? catalogueError;

  bool get syncing => _catalogueSyncing || _scheduleSyncing;

  List<ScheduleEntity> get favorites => entities
      .where((entity) => favoriteKeys.contains(entity.key))
      .toList(growable: false);

  Future<void> initialize() async {
    await _repository.seedIfNeeded();
    await _reloadLocal();
    themeMode = _themeFromString(await _repository.setting('themeMode'));
    firstDayOfWeek =
        int.tryParse(await _repository.setting('firstDayOfWeek') ?? '') ??
        DateTime.monday;
    rememberSelection =
        await _repository.setting('rememberSelection') != 'false';
    if (rememberSelection) {
      final saved = await _repository.setting('selectedEntity');
      if (saved != null && saved.isNotEmpty) {
        try {
          final value = jsonDecode(saved) as Map<String, dynamic>;
          selectedEntity = ScheduleEntity(
            apiId: value['id'] as int,
            name: value['name'] as String,
            kind: EntityKind.values.byName(value['kind'] as String),
          );
          searchKind = selectedEntity!.kind;
          final cached = await _repository.cachedSchedule(selectedEntity!);
          schedule = cached?.schedule;
          lastSync = cached?.syncedAt;
        } catch (_) {
          selectedEntity = null;
        }
      }
    }
    if (_disposed) return;
    initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      now = DateTime.now();
      notifyListeners();
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (offline || errorMessage != null || catalogueError != null) {
        unawaited(checkConnection());
      }
    });
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _connectionDebounce?.cancel();
        _connectionDebounce = Timer(const Duration(milliseconds: 500), () {
          unawaited(checkConnection());
        });
      },
      onError: (Object _) {
        unawaited(checkConnection());
      },
    );
    notifyListeners();
    unawaited(checkConnection());
  }

  Future<void> checkConnection() async {
    final version = ++_connectionVersion;
    try {
      final results = await _connectivity.checkConnectivity();
      if (_disposed || version != _connectionVersion) return;
      offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      notifyListeners();
      if (offline) return;
    } catch (_) {
      // If the platform status is unavailable, let the actual API request decide.
    }
    if (!_disposed) await refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshCatalogue(), refreshSchedule()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      now = DateTime.now();
      notifyListeners();
      unawaited(checkConnection());
    }
  }

  Future<void> _reloadLocal() async {
    entities = await _repository.entities();
    favoriteKeys = await _repository.favoriteKeys();
  }

  Future<void> refreshCatalogue() {
    final active = _catalogueRefresh;
    if (active != null) return active;

    late final Future<void> refresh;
    refresh = _runCatalogueRefresh().whenComplete(() {
      if (identical(_catalogueRefresh, refresh)) _catalogueRefresh = null;
    });
    _catalogueRefresh = refresh;
    return refresh;
  }

  Future<void> _runCatalogueRefresh() async {
    _catalogueSyncing = true;
    catalogueError = null;
    notifyListeners();
    try {
      await _repository.syncCatalogue();
      await _reloadLocal();
    } catch (_) {
      catalogueError = 'Каталог не обновлён. Доступны сохранённые данные.';
    } finally {
      _catalogueSyncing = false;
      notifyListeners();
    }
  }

  Future<void> selectEntity(ScheduleEntity entity) async {
    final version = ++_selectionVersion;
    _scheduleSyncing = false;
    selectedEntity = entity;
    selectedDate = DateUtils.dateOnly(DateTime.now());
    schedule = null;
    lastSync = null;
    errorMessage = null;
    HapticFeedback.selectionClick();
    notifyListeners();

    await _persistSelection();
    if (_disposed || version != _selectionVersion) return;
    final cached = await _repository.cachedSchedule(entity);
    if (_disposed || version != _selectionVersion) return;
    if (cached != null) {
      schedule = cached.schedule;
      lastSync = cached.syncedAt;
      notifyListeners();
    }
    await refreshSchedule();
  }

  Future<void> refreshSchedule() {
    final entity = selectedEntity;
    if (entity == null) return Future.value();
    final version = _selectionVersion;
    final active = _scheduleRefresh;
    if (active != null && _scheduleRefreshVersion == version) return active;

    late final Future<void> refresh;
    refresh = _runScheduleRefresh(entity, version).whenComplete(() {
      if (identical(_scheduleRefresh, refresh)) {
        _scheduleRefresh = null;
        _scheduleRefreshVersion = null;
      }
    });
    _scheduleRefreshVersion = version;
    _scheduleRefresh = refresh;
    return refresh;
  }

  Future<void> _runScheduleRefresh(ScheduleEntity entity, int version) async {
    _scheduleSyncing = true;
    errorMessage = null;
    notifyListeners();
    try {
      final fresh = await _repository.refreshSchedule(entity);
      if (!_disposed && version == _selectionVersion) {
        schedule = fresh.schedule;
        lastSync = fresh.syncedAt;
      }
    } catch (_) {
      if (_disposed || version != _selectionVersion) return;
      errorMessage = schedule == null
          ? 'Расписание пока не сохранено. Проверьте подключение и повторите.'
          : 'Не удалось связаться с сервером. Показано сохранённое расписание.';
    } finally {
      if (version == _selectionVersion) {
        _scheduleSyncing = false;
        notifyListeners();
      }
    }
  }

  void selectDate(DateTime date) {
    selectedDate = DateUtils.dateOnly(date);
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void shiftDay(int days) => selectDate(selectedDate.add(Duration(days: days)));
  void shiftWeek(int weeks) =>
      selectDate(selectedDate.add(Duration(days: weeks * 7)));
  void goToday() => selectDate(DateTime.now());

  void setViewMode(ScheduleViewMode mode) {
    viewMode = mode;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void setSearchKind(EntityKind kind) {
    searchKind = kind;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  Future<void> toggleFavorite(ScheduleEntity entity) async {
    final favorite = !favoriteKeys.contains(entity.key);
    favorite ? favoriteKeys.add(entity.key) : favoriteKeys.remove(entity.key);
    HapticFeedback.lightImpact();
    notifyListeners();
    await _repository.setFavorite(entity, favorite);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await _repository.saveSetting('themeMode', value.name);
  }

  Future<void> setFirstDayOfWeek(int value) async {
    firstDayOfWeek = value;
    notifyListeners();
    await _repository.saveSetting('firstDayOfWeek', value.toString());
  }

  Future<void> setRememberSelection(bool value) async {
    rememberSelection = value;
    notifyListeners();
    await _repository.saveSetting('rememberSelection', value.toString());
    await _persistSelection();
  }

  Future<void> _persistSelection() {
    final entity = selectedEntity;
    final value = rememberSelection && entity != null
        ? jsonEncode({
            'id': entity.apiId,
            'name': entity.name,
            'kind': entity.kind.name,
          })
        : '';
    _selectionWrite = _selectionWrite
        .catchError((Object _) {})
        .then((_) => _repository.saveSetting('selectedEntity', value));
    return _selectionWrite;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ThemeMode _themeFromString(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _retryTimer?.cancel();
    _connectionDebounce?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
