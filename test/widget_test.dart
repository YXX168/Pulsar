// 情绪星海 EmotionGalaxy - Widget 与单元测试
//
// 本文件覆盖以下内容：
// 1. EmotionType 枚举的 fromId 方法
// 2. EmotionEntry 的 toJson / fromJson 序列化
// 3. IntensityLevel 的 progress 映射
// 4. EmotionStorage 在无 SQLite 环境下的 SharedPreferences 降级

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emotion_galaxy/models/emotion.dart';
import 'package:emotion_galaxy/models/emotion_entry.dart';
import 'package:emotion_galaxy/services/storage.dart';

void main() {
  // --------------------------------------------------------------------------
  // 1. EmotionType 枚举
  // --------------------------------------------------------------------------
  group('EmotionType', () {
    test('包含 9 种情绪类型', () {
      expect(EmotionType.values.length, 9);
    });

    test('每种情绪类型拥有唯一的 id', () {
      final ids = EmotionType.values.map((e) => e.id).toSet();
      expect(ids.length, EmotionType.values.length);
    });

    test('fromId 能根据 id 字符串正确返回对应的情绪类型', () {
      expect(EmotionType.fromId('joy'), EmotionType.joy);
      expect(EmotionType.fromId('calm'), EmotionType.calm);
      expect(EmotionType.fromId('love'), EmotionType.love);
      expect(EmotionType.fromId('gratitude'), EmotionType.gratitude);
      expect(EmotionType.fromId('excitement'), EmotionType.excitement);
      expect(EmotionType.fromId('sadness'), EmotionType.sadness);
      expect(EmotionType.fromId('anxiety'), EmotionType.anxiety);
      expect(EmotionType.fromId('anger'), EmotionType.anger);
      expect(EmotionType.fromId('fatigue'), EmotionType.fatigue);
    });

    test('fromId 对所有合法 id 均可往返还原', () {
      for (final type in EmotionType.values) {
        expect(EmotionType.fromId(type.id), type,
            reason: 'id=${type.id} 无法还原为 ${type.name}');
      }
    });

    test('fromId 对未知 id 返回 null', () {
      expect(EmotionType.fromId('nonexistent'), isNull);
      expect(EmotionType.fromId(''), isNull);
    });

    test('每种情绪类型具备 label、icon 与 palette', () {
      for (final type in EmotionType.values) {
        expect(type.label, isNotEmpty);
        expect(type.icon, isNotNull);
        expect(type.palette, isNotNull);
      }
    });
  });

  // --------------------------------------------------------------------------
  // 2. IntensityLevel 强度等级
  // --------------------------------------------------------------------------
  group('IntensityLevel', () {
    test('包含 5 级强度', () {
      expect(IntensityLevel.values.length, 5);
    });

    test('progress 将 1–5 正确映射到 0.0–1.0', () {
      expect(IntensityLevel.values[0].progress, 0.0); // value = 1
      expect(IntensityLevel.values[1].progress, 0.25); // value = 2
      expect(IntensityLevel.values[2].progress, 0.5); // value = 3
      expect(IntensityLevel.values[3].progress, 0.75); // value = 4
      expect(IntensityLevel.values[4].progress, 1.0); // value = 5
    });

    test('progress 公式为 (value - 1) / 4', () {
      for (final level in IntensityLevel.values) {
        expect(level.progress, closeTo((level.value - 1) / 4, 1e-9));
      }
    });

    test('progress 随等级递增', () {
      double previous = -1;
      for (final level in IntensityLevel.values) {
        expect(level.progress, greaterThan(previous));
        previous = level.progress;
      }
    });

    test('value 从 1 递增到 5，且 label 非空', () {
      for (var i = 0; i < IntensityLevel.values.length; i++) {
        expect(IntensityLevel.values[i].value, i + 1);
        expect(IntensityLevel.values[i].label, isNotEmpty);
      }
    });

    test('5 级标签为 微弱 / 轻微 / 适中 / 强烈 / 极强', () {
      expect(IntensityLevel.values.map((l) => l.label).toList(),
          ['微弱', '轻微', '适中', '强烈', '极强']);
    });
  });

  // --------------------------------------------------------------------------
  // 3. EmotionEntry 序列化
  // --------------------------------------------------------------------------
  group('EmotionEntry 序列化', () {
    final timestamp = DateTime(2026, 1, 15, 9, 30, 0);

    test('toJson 生成包含全部字段的映射', () {
      final entry = EmotionEntry(
        emotionId: 'joy',
        intensity: 4,
        timestamp: timestamp,
        note: '今天阳光很好',
        tags: const ['周末', '户外'],
      );

      final json = entry.toJson();

      expect(json['id'], entry.id);
      expect(json['emotionId'], 'joy');
      expect(json['intensity'], 4);
      expect(json['timestamp'], timestamp.toIso8601String());
      expect(json['note'], '今天阳光很好');
      expect(json['tags'], ['周末', '户外']);
    });

    test('fromJson 能正确还原对象', () {
      final json = {
        'id': 'emo-test-001',
        'emotionId': 'sadness',
        'intensity': 5,
        'timestamp': timestamp.toIso8601String(),
        'note': '有些低落',
        'tags': ['工作'],
      };

      final entry = EmotionEntry.fromJson(json);

      expect(entry.id, 'emo-test-001');
      expect(entry.emotionId, 'sadness');
      expect(entry.intensity, 5);
      expect(entry.timestamp, timestamp);
      expect(entry.note, '有些低落');
      expect(entry.tags, ['工作']);
    });

    test('toJson / fromJson 可完整往返还原', () {
      final original = EmotionEntry(
        emotionId: 'anger',
        intensity: 3,
        timestamp: timestamp,
        note: '通勤迟到',
        tags: const ['早高峰'],
      );

      final restored = EmotionEntry.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.emotionId, original.emotionId);
      expect(restored.intensity, original.intensity);
      expect(restored.timestamp, original.timestamp);
      expect(restored.note, original.note);
      expect(restored.tags, original.tags);
    });

    test('通过 JSON 字符串序列化后仍可还原', () {
      final original = EmotionEntry(
        emotionId: 'anxiety',
        intensity: 2,
        timestamp: timestamp,
        note: '考试前夜',
      );

      final encoded = jsonEncode(original.toJson());
      final decoded = EmotionEntry.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.emotionId, 'anxiety');
      expect(decoded.intensity, 2);
      expect(decoded.note, '考试前夜');
      expect(decoded.tags, isEmpty);
    });

    test('fromJson 在字段缺失时使用合理默认值', () {
      final entry = EmotionEntry.fromJson({});

      expect(entry.emotionId, 'calm');
      expect(entry.intensity, 3);
      expect(entry.note, isEmpty);
      expect(entry.tags, isEmpty);
      expect(entry.id, isNotEmpty);
    });

    test('type getter 返回对应的 EmotionType', () {
      final entry = EmotionEntry(
        emotionId: 'joy',
        intensity: 5,
        timestamp: timestamp,
      );
      expect(entry.type, EmotionType.joy);
    });

    test('所有情绪类型均能被正确序列化与还原', () {
      for (final type in EmotionType.values) {
        final entry = EmotionEntry(
          emotionId: type.id,
          intensity: 3,
          timestamp: timestamp,
        );
        final restored = EmotionEntry.fromJson(entry.toJson());
        expect(restored.emotionId, type.id, reason: '${type.name} 还原失败');
        expect(restored.type, type);
      }
    });

    test('copyWith 正确更新指定字段且保留其余字段', () {
      final original = EmotionEntry(
        emotionId: 'calm',
        intensity: 2,
        timestamp: timestamp,
        note: '原始',
      );
      final updated = original.copyWith(emotionId: 'anger', intensity: 5);

      expect(updated.id, original.id);
      expect(updated.emotionId, 'anger');
      expect(updated.intensity, 5);
      expect(updated.note, '原始');
    });

    test('dateKey 格式为 yyyy-MM-dd', () {
      final entry = EmotionEntry(
        emotionId: 'joy',
        intensity: 1,
        timestamp: DateTime(2026, 7, 9, 14, 30),
      );
      expect(entry.dateKey, '2026-07-09');
    });
  });

  // --------------------------------------------------------------------------
  // 4. EmotionStorage — 无 SQLite 环境下的 SharedPreferences 降级
  // --------------------------------------------------------------------------
  group('EmotionStorage SharedPreferences 降级', () {
    setUp(() {
      // 初始化 SharedPreferences mock，清空旧数据。
      // flutter test 运行环境（桌面端）不存在 sqflite 平台实现，
      // EmotionStorage 内部打开数据库会失败并自动降级到 SharedPreferences。
      SharedPreferences.setMockInitialValues({});
    });

    test('空存储时 loadEntries 返回空列表', () async {
      final storage = EmotionStorage();
      final entries = await storage.loadEntries();
      expect(entries, isEmpty);
    });

    test('addEntry 后 loadEntries 返回该记录（降级到 SharedPreferences）', () async {
      final storage = EmotionStorage();
      final entry = EmotionEntry(
        emotionId: 'joy',
        intensity: 4,
        timestamp: DateTime(2026, 1, 15, 9, 30),
        note: '降级测试',
      );

      await storage.addEntry(entry);

      final entries = await storage.loadEntries();
      expect(entries.length, 1);
      expect(entries.first.emotionId, 'joy');
      expect(entries.first.intensity, 4);
      expect(entries.first.note, '降级测试');
    });

    test('多次 addEntry 后 loadEntries 返回全部记录且顺序正确', () async {
      final storage = EmotionStorage();
      await storage.addEntry(EmotionEntry(
        emotionId: 'calm',
        intensity: 2,
        timestamp: DateTime(2026, 1, 1),
      ));
      await storage.addEntry(EmotionEntry(
        emotionId: 'sadness',
        intensity: 3,
        timestamp: DateTime(2026, 1, 2),
      ));
      await storage.addEntry(EmotionEntry(
        emotionId: 'anger',
        intensity: 5,
        timestamp: DateTime(2026, 1, 3),
      ));

      final entries = await storage.loadEntries();

      expect(entries.length, 3);
      expect(entries[0].emotionId, 'calm');
      expect(entries[1].emotionId, 'sadness');
      expect(entries[2].emotionId, 'anger');
    });

    test('数据确实持久化于 SharedPreferences（验证降级路径）', () async {
      final storage = EmotionStorage();
      await storage.addEntry(EmotionEntry(
        emotionId: 'anxiety',
        intensity: 3,
        timestamp: DateTime(2026, 2, 1),
        note: '持久化验证',
      ));

      // 直接读取 SharedPreferences，验证底层数据确实写入降级存储
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('emotion_galaxy_entries_v1');

      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List;
      expect(list.length, 1);

      final decoded =
          EmotionEntry.fromJson(list.first as Map<String, dynamic>);
      expect(decoded.emotionId, 'anxiety');
      expect(decoded.note, '持久化验证');
    });

    test('重建存储实例后仍能读取之前写入的数据', () async {
      final first = EmotionStorage();
      await first.addEntry(EmotionEntry(
        emotionId: 'excitement',
        intensity: 5,
        timestamp: DateTime(2026, 3, 1),
      ));

      // 模拟应用重启：新建实例，共享同一 SharedPreferences mock
      final second = EmotionStorage();
      final entries = await second.loadEntries();

      expect(entries.length, 1);
      expect(entries.first.emotionId, 'excitement');
    });

    test('deleteEntry 正确删除指定记录', () async {
      final storage = EmotionStorage();
      final entry = EmotionEntry(
        emotionId: 'joy',
        intensity: 5,
        timestamp: DateTime(2026, 1, 1),
      );
      await storage.addEntry(entry);
      expect((await storage.loadEntries()).length, 1);

      await storage.deleteEntry(entry.id);

      expect(await storage.loadEntries(), isEmpty);
    });

    test('updateEntry 正确更新指定记录', () async {
      final storage = EmotionStorage();
      final entry = EmotionEntry(
        emotionId: 'calm',
        intensity: 2,
        timestamp: DateTime(2026, 1, 1),
      );
      await storage.addEntry(entry);

      final updated = entry.copyWith(emotionId: 'anger', intensity: 5);
      await storage.updateEntry(updated);

      final entries = await storage.loadEntries();
      expect(entries.length, 1);
      expect(entries.first.emotionId, 'anger');
      expect(entries.first.intensity, 5);
    });

    test('saveEntries / loadEntries 与 JSON 往返一致', () async {
      final storage = EmotionStorage();
      final entries = [
        EmotionEntry(
          emotionId: 'joy',
          intensity: 1,
          timestamp: DateTime(2026, 1, 1),
          note: 'a',
          tags: const ['t1'],
        ),
        EmotionEntry(
          emotionId: 'calm',
          intensity: 5,
          timestamp: DateTime(2026, 1, 2),
          note: 'b',
        ),
      ];
      await storage.saveEntries(entries);

      final loaded = await storage.loadEntries();

      expect(loaded.length, 2);
      expect(loaded[0].emotionId, 'joy');
      expect(loaded[0].tags, ['t1']);
      expect(loaded[1].emotionId, 'calm');
    });

    test('loadEntriesForDate 仅返回指定日期的记录', () async {
      final storage = EmotionStorage();
      await storage.addEntry(EmotionEntry(
        emotionId: 'joy',
        intensity: 3,
        timestamp: DateTime(2026, 5, 10, 8, 0),
      ));
      await storage.addEntry(EmotionEntry(
        emotionId: 'calm',
        intensity: 2,
        timestamp: DateTime(2026, 5, 10, 20, 0),
      ));
      await storage.addEntry(EmotionEntry(
        emotionId: 'anger',
        intensity: 4,
        timestamp: DateTime(2026, 5, 11, 9, 0),
      ));

      final day1 = await storage.loadEntriesForDate(DateTime(2026, 5, 10));
      expect(day1.length, 2);
      expect(day1.every((e) => e.dateKey == '2026-05-10'), isTrue);

      final day2 = await storage.loadEntriesForDate(DateTime(2026, 5, 11));
      expect(day2.length, 1);
      expect(day2.first.emotionId, 'anger');
    });
  });
}
