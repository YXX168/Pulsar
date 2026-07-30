import 'emotion.dart';

/// 单条情绪记录。
class EmotionEntry {
  EmotionEntry({
    String? id,
    required this.emotionId,
    required this.intensity,
    required this.timestamp,
    this.note = '',
    this.tags = const [],
  }) : id = id ?? _newId();

  final String id;
  final String emotionId;
  final int intensity; // 1–5
  final DateTime timestamp;
  final String note;
  final List<String> tags;

  /// 快捷获取对应的枚举类型。
  EmotionType? get type => EmotionType.fromId(emotionId);

  /// 日期键 yyyy-MM-dd，用于按天分组。
  String get dateKey =>
      '${timestamp.year.toString().padLeft(4, '0')}-'
      '${timestamp.month.toString().padLeft(2, '0')}-'
      '${timestamp.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'emotionId': emotionId,
        'intensity': intensity,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'tags': tags,
      };

  factory EmotionEntry.fromJson(Map<String, dynamic> json) => EmotionEntry(
        id: json['id'] as String? ?? _newId(),
        emotionId: json['emotionId'] as String? ?? 'calm',
        intensity: (json['intensity'] as num?)?.toInt() ?? 3,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        note: json['note'] as String? ?? '',
        tags: (json['tags'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
      );

  EmotionEntry copyWith({
    String? emotionId,
    int? intensity,
    DateTime? timestamp,
    String? note,
    List<String>? tags,
  }) =>
      EmotionEntry(
        id: id,
        emotionId: emotionId ?? this.emotionId,
        intensity: intensity ?? this.intensity,
        timestamp: timestamp ?? this.timestamp,
        note: note ?? this.note,
        tags: tags ?? this.tags,
      );

  static String _newId() =>
      'emo-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}

/// 按天聚合的情绪摘要，用于历史日历和统计页。
class DailySummary {
  DailySummary({
    required this.dateKey,
    required this.entries,
  });

  final String dateKey;
  final List<EmotionEntry> entries;

  /// 当天主要情绪（出现次数最多的类型）。
  EmotionType? get dominantEmotion {
    if (entries.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.emotionId] = (counts[e.emotionId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return EmotionType.fromId(sorted.first.key);
  }

  /// 当天平均强度（1–5）。
  double get averageIntensity {
    if (entries.isEmpty) return 0;
    final total = entries.fold<int>(0, (sum, e) => sum + e.intensity);
    return total / entries.length;
  }

  /// 当天记录条数。
  int get count => entries.length;
}

/// 统计区间内的情绪分布。
class EmotionStats {
  EmotionStats({
    required this.totalEntries,
    required this.distribution,
    required this.activeDays,
    required this.currentStreak,
    required this.averageIntensity,
  });

  final int totalEntries;
  final Map<EmotionType, int> distribution;
  final int activeDays;
  final int currentStreak;
  final double averageIntensity;

  /// 出现次数最多的情绪。
  EmotionType? get topEmotion {
    if (distribution.isEmpty) return null;
    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}
