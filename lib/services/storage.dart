import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/emotion.dart';
import '../models/emotion_entry.dart';

/// 本地存储服务，参考 Pulsar 的 PulsarStorage 设计。
///
/// 优先使用 SQLite 持久化情绪记录；在 SQLite 不可用的环境（如测试）
/// 自动降级到 SharedPreferences，保证功能可用。
class EmotionStorage {
  static const _entriesPrefsKey = 'emotion_galaxy_entries_v1';
  static const _effectsKey = 'emotion_galaxy_effects_level_v1';

  Database? _database;
  bool _databaseUnavailable = false;

  Future<Database?> _db() async {
    if (_databaseUnavailable) return null;
    if (_database != null) return _database;
    try {
      final root = await getDatabasesPath();
      _database = await openDatabase(
        p.join(root, 'emotion_galaxy_v1.db'),
        version: 1,
        onCreate: (db, version) => db.execute(
          'CREATE TABLE emotion_state ('
          'key TEXT PRIMARY KEY, '
          'value TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        ),
      );
      return _database;
    } catch (_) {
      _databaseUnavailable = true;
      return null;
    }
  }

  Future<String?> _readState(String key) async {
    final db = await _db();
    if (db == null) return null;
    final rows = await db.query(
      'emotion_state',
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
    await db.insert(
      'emotion_state',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  // ── 情绪记录 CRUD ──────────────────────────────────────────

  Future<List<EmotionEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final databaseRaw = await _readState('entries');
    final raw = databaseRaw ?? prefs.getString(_entriesPrefsKey);
    if (raw == null) {
      await saveEntries([]);
      return [];
    }
    try {
      final entries = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(EmotionEntry.fromJson)
          .toList();
      if (databaseRaw == null) await saveEntries(entries);
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntries(List<EmotionEntry> entries) async {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    if (!await _writeState('entries', raw)) {
      await (await SharedPreferences.getInstance())
          .setString(_entriesPrefsKey, raw);
    }
  }

  Future<void> addEntry(EmotionEntry entry) async {
    final entries = await loadEntries();
    entries.add(entry);
    await saveEntries(entries);
  }

  Future<void> updateEntry(EmotionEntry entry) async {
    final entries = await loadEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
      await saveEntries(entries);
    }
  }

  Future<void> deleteEntry(String id) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.id == id);
    await saveEntries(entries);
  }

  /// 获取指定日期范围内的所有记录，按时间升序排列。
  Future<List<EmotionEntry>> loadEntriesInRange({
    DateTime? start,
    DateTime? end,
  }) async {
    final entries = await loadEntries();
    return entries.where((e) {
      if (start != null && e.timestamp.isBefore(start)) return false;
      if (end != null && e.timestamp.isAfter(end)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 获取指定日期当天的所有记录。
  Future<List<EmotionEntry>> loadEntriesForDate(DateTime date) async {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final entries = await loadEntries();
    return entries.where((e) => e.dateKey == key).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ── 按天聚合 ──────────────────────────────────────────────

  /// 获取指定月份所有有记录的日期摘要。
  Future<List<DailySummary>> loadDailySummaries(int year, int month) async {
    final entries = await loadEntries();
    final grouped = <String, List<EmotionEntry>>{};
    for (final e in entries) {
      if (e.timestamp.year == year && e.timestamp.month == month) {
        grouped.putIfAbsent(e.dateKey, () => []).add(e);
      }
    }
    final summaries = grouped.entries
        .map((e) => DailySummary(dateKey: e.key, entries: e.value))
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return summaries;
  }

  // ── 统计 ──────────────────────────────────────────────────

  /// 计算最近 N 天的统计信息。
  Future<EmotionStats> loadStats({int days = 30}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final entries = await loadEntriesInRange(start: start);

    final distribution = <EmotionType, int>{};
    for (final e in entries) {
      final type = EmotionType.fromId(e.emotionId);
      if (type != null) {
        distribution[type] = (distribution[type] ?? 0) + 1;
      }
    }

    final activeDateKeys = <String>{};
    for (final e in entries) {
      activeDateKeys.add(e.dateKey);
    }

    final avgIntensity = entries.isEmpty
        ? 0.0
        : entries.fold<int>(0, (sum, e) => sum + e.intensity) /
            entries.length;

    // 计算连续记录天数（从今天往前数）
    final allEntries = await loadEntries();
    final allDateKeys = <String>{};
    for (final e in allEntries) {
      allDateKeys.add(e.dateKey);
    }
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (true) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-'
          '${cursor.month.toString().padLeft(2, '0')}-'
          '${cursor.day.toString().padLeft(2, '0')}';
      if (allDateKeys.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return EmotionStats(
      totalEntries: entries.length,
      distribution: distribution,
      activeDays: activeDateKeys.length,
      currentStreak: streak,
      averageIntensity: avgIntensity,
    );
  }

  // ── 设置 ──────────────────────────────────────────────────

  Future<int> loadEffectsLevel() async =>
      (await SharedPreferences.getInstance()).getInt(_effectsKey) ?? 2;

  Future<void> saveEffectsLevel(int level) async =>
      (await SharedPreferences.getInstance()).setInt(_effectsKey, level);

  // ── 备份与恢复 ────────────────────────────────────────────

  /// 导出全部数据为 JSON 文件，返回文件路径。
  Future<String> exportBackup(String directoryPath) async {
    final entries = await loadEntries();
    final effectsLevel = await loadEffectsLevel();
    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'effectsLevel': effectsLevel,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    final fileName =
        'emotion_galaxy_backup_'
        '${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}'
        '.json';
    final filePath = p.join(directoryPath, fileName);
    final file = File(filePath);
    await file.writeAsString(jsonEncode(backup));
    return filePath;
  }

  /// 从 JSON 文件恢复数据，返回恢复的记录条数。
  Future<int> restoreBackup(String filePath) async {
    final file = File(filePath);
    final raw = await file.readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final entriesList = (data['entries'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EmotionEntry.fromJson)
        .toList();

    await saveEntries(entriesList);

    final effectsLevel = data['effectsLevel'] as int?;
    if (effectsLevel != null) {
      await saveEffectsLevel(effectsLevel);
    }

    return entriesList.length;
  }
}
