import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/training_event.dart';
import '../models/workout.dart';

class PulsarStorage {
  static const _planPrefsKey = 'pulsar_plan_v2';
  static const _legacySetsKey = 'pulsar_sets_v1';
  static const _setsPrefsKey = 'pulsar_sets_v2';
  static const _eventsPrefsKey = 'pulsar_training_events_v2';
  static const _legacyEventsKey = 'pulsar_training_events_v1';
  static const _modeKey = 'pulsar_display_mode_v2';
  static const _effectsKey = 'pulsar_effects_level_v1';

  Database? _database;
  bool _databaseUnavailable = false;

  Future<Database?> _db() async {
    if (_databaseUnavailable) return null;
    if (_database != null) return _database;
    try {
      final root = await getDatabasesPath();
      _database = await openDatabase(
        p.join(root, 'pulsar_v2.db'),
        version: 1,
        onCreate: (db, version) => db.execute(
          'CREATE TABLE pulsar_state ('
          'key TEXT PRIMARY KEY, '
          'value TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        ),
      );
      return _database;
    } catch (_) {
      // Widget tests and unsupported platforms do not register sqflite. The
      // preference fallback keeps those environments functional.
      _databaseUnavailable = true;
      return null;
    }
  }

  Future<String?> _readState(String key) async {
    final db = await _db();
    if (db == null) return null;
    final rows = await db.query(
      'pulsar_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<bool> _writeState(String key, String value) async {
    final db = await _db();
    if (db == null) return false;
    await db.insert('pulsar_state', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<List<WorkoutDay>> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _readState('plan') ?? prefs.getString(_planPrefsKey);
    if (raw == null) {
      final plan = defaultPlan();
      await savePlan(plan);
      return plan;
    }
    try {
      final plan = (jsonDecode(raw) as List)
          .map((e) => WorkoutDay.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (await _readState('plan') == null) await savePlan(plan);
      return plan;
    } catch (_) {
      return defaultPlan();
    }
  }

  Future<Map<String, Map<String, int>>> loadSets(List<WorkoutDay> plan) async {
    final prefs = await SharedPreferences.getInstance();
    final databaseRaw = await _readState('sets');
    final raw = databaseRaw ?? prefs.getString(_setsPrefsKey);
    if (raw != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final parsed = map.map(
          (date, values) => MapEntry(
            date,
            Map<String, dynamic>.from(
              values as Map,
            ).map((id, count) => MapEntry(id, (count as num).toInt())),
          ),
        );
        if (databaseRaw == null) await saveSets(parsed);
        return parsed;
      } catch (_) {
        // Fall through to the legacy migration.
      }
    }

    final legacyRaw = prefs.getString(_legacySetsKey);
    if (legacyRaw == null) {
      await saveSets({});
      return {};
    }
    try {
      final legacy = Map<String, dynamic>.from(jsonDecode(legacyRaw) as Map);
      final migrated = <String, Map<String, int>>{};
      for (final day in plan) {
        final values = legacy[day.keyName];
        if (values is! Map) continue;
        final date = scheduledDateKey(day.keyName);
        final target = migrated.putIfAbsent(date, () => {});
        for (final entry in Map<String, dynamic>.from(values).entries) {
          final index = int.tryParse(entry.key);
          if (index == null || index < 0 || index >= day.exercises.length) {
            continue;
          }
          target[day.exercises[index].id] = (entry.value as num).toInt();
        }
      }
      await saveSets(migrated);
      return migrated;
    } catch (_) {
      return {};
    }
  }

  Future<List<TrainingEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final databaseRaw = await _readState('events');
    final raw =
        databaseRaw ??
        prefs.getString(_eventsPrefsKey) ??
        prefs.getString(_legacyEventsKey);
    if (raw == null) {
      await saveEvents([]);
      return [];
    }
    try {
      final events = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (event) => TrainingEvent.fromJson(Map<String, dynamic>.from(event)),
          )
          .toList();
      if (databaseRaw == null) await saveEvents(events);
      return events;
    } catch (_) {
      return [];
    }
  }

  String _planJson(List<WorkoutDay> plan) =>
      jsonEncode(plan.map((e) => e.toJson()).toList());

  String _setsJson(Map<String, Map<String, int>> sets) => jsonEncode(sets);

  String _eventsJson(List<TrainingEvent> events) =>
      jsonEncode(events.map((event) => event.toJson()).toList());

  Future<void> savePlan(List<WorkoutDay> plan) async {
    final raw = _planJson(plan);
    if (!await _writeState('plan', raw)) {
      await (await SharedPreferences.getInstance()).setString(
        _planPrefsKey,
        raw,
      );
    }
  }

  Future<void> saveSets(Map<String, Map<String, int>> sets) async {
    final raw = _setsJson(sets);
    if (!await _writeState('sets', raw)) {
      await (await SharedPreferences.getInstance()).setString(
        _setsPrefsKey,
        raw,
      );
    }
  }

  Future<void> saveEvents(List<TrainingEvent> events) async {
    final raw = _eventsJson(events);
    if (!await _writeState('events', raw)) {
      await (await SharedPreferences.getInstance()).setString(
        _eventsPrefsKey,
        raw,
      );
    }
  }

  Future<bool> loadGalaxyMode() async =>
      (await SharedPreferences.getInstance()).getBool(_modeKey) ?? true;

  Future<void> saveGalaxyMode(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_modeKey, enabled);

  Future<int> loadEffectsLevel() async =>
      (await SharedPreferences.getInstance()).getInt(_effectsKey) ?? 2;

  Future<void> saveEffectsLevel(int level) async =>
      (await SharedPreferences.getInstance()).setInt(_effectsKey, level);

  Future<void> replaceAll({
    required List<WorkoutDay> plan,
    required Map<String, Map<String, int>> sets,
    required List<TrainingEvent> events,
  }) async {
    final db = await _db();
    if (db == null) {
      await savePlan(plan);
      await saveSets(sets);
      await saveEvents(events);
      return;
    }
    await db.transaction((transaction) async {
      final now = DateTime.now().toIso8601String();
      for (final entry in {
        'plan': _planJson(plan),
        'sets': _setsJson(sets),
        'events': _eventsJson(events),
      }.entries) {
        await transaction.insert('pulsar_state', {
          'key': entry.key,
          'value': entry.value,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static String scheduledDateKey(String dayKey, [DateTime? now]) {
    const keys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final today = now ?? DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final index = keys.indexOf(dayKey);
    final date = monday.add(Duration(days: index < 0 ? 0 : index));
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

String scheduledDateKey(String dayKey, [DateTime? now]) =>
    PulsarStorage.scheduledDateKey(dayKey, now);
