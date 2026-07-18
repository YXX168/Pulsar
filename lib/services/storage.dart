import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../models/training_event.dart';

class PulsarStorage {
  // v2 replaces the corrupted legacy default strings with proper Chinese.
  static const _planKey = 'pulsar_plan_v2';
  static const _setsKey = 'pulsar_sets_v1';
  static const _eventsKey = 'pulsar_training_events_v1';
  static const _modeKey = 'pulsar_display_mode_v1';
  Future<List<WorkoutDay>> loadPlan() async {
    final raw = (await SharedPreferences.getInstance()).getString(_planKey);
    if (raw == null) return defaultPlan();
    try {
      return (jsonDecode(raw) as List)
          .map((e) => WorkoutDay.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return defaultPlan();
    }
  }

  Future<Map<String, Map<int, int>>> loadSets() async {
    final raw = (await SharedPreferences.getInstance()).getString(_setsKey);
    if (raw == null) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map(
        (k, v) => MapEntry(
          k,
          Map<String, dynamic>.from(
            v as Map,
          ).map((i, n) => MapEntry(int.parse(i), (n as num).toInt())),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<List<TrainingEvent>> loadEvents() async {
    final raw = (await SharedPreferences.getInstance()).getString(_eventsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (event) => TrainingEvent.fromJson(Map<String, dynamic>.from(event)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlan(List<WorkoutDay> plan) async =>
      (await SharedPreferences.getInstance()).setString(
        _planKey,
        jsonEncode(plan.map((e) => e.toJson()).toList()),
      );
  Future<void> saveSets(Map<String, Map<int, int>> sets) async =>
      (await SharedPreferences.getInstance()).setString(
        _setsKey,
        jsonEncode(
          sets.map((k, v) => MapEntry(k, v.map((i, n) => MapEntry('$i', n)))),
        ),
      );

  Future<void> saveEvents(List<TrainingEvent> events) async =>
      (await SharedPreferences.getInstance()).setString(
        _eventsKey,
        jsonEncode(events.take(2500).map((event) => event.toJson()).toList()),
      );

  Future<bool> loadGalaxyMode() async =>
      (await SharedPreferences.getInstance()).getBool(_modeKey) ?? true;

  Future<void> saveGalaxyMode(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_modeKey, enabled);
}
