class TrainingEvent {
  TrainingEvent({
    String? id,
    required this.timestamp,
    required this.dayKey,
    required this.dayLabel,
    required this.workoutTitle,
    required this.exerciseId,
    required this.exerciseName,
    required this.scheduledDateKey,
    this.kind = 'training',
    this.reps = '',
    this.weight = 0,
    this.note = '',
  }) : id =
           id ??
           'set-${timestamp.microsecondsSinceEpoch.toRadixString(36)}-'
               '${exerciseId.hashCode.abs().toRadixString(36)}';

  final String id;
  final DateTime timestamp;
  final String dayKey;
  final String dayLabel;
  final String workoutTitle;
  final String exerciseId;
  final String exerciseName;
  final String scheduledDateKey;
  final String kind;
  final String reps;
  final double weight;
  final String note;

  String get dateKey {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int get estimatedReps {
    final match = RegExp(r'\d+').firstMatch(reps);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  double get estimatedVolume => weight * estimatedReps;

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'dayKey': dayKey,
    'dayLabel': dayLabel,
    'workoutTitle': workoutTitle,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'scheduledDateKey': scheduledDateKey,
    'kind': kind,
    'reps': reps,
    'weight': weight,
    'note': note,
  };

  factory TrainingEvent.fromJson(Map<String, dynamic> json) {
    final timestamp =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final exerciseName = json['exerciseName'] as String? ?? '训练事项';
    return TrainingEvent(
      id: json['id'] as String?,
      timestamp: timestamp,
      dayKey: json['dayKey'] as String? ?? '',
      dayLabel: json['dayLabel'] as String? ?? '',
      workoutTitle: json['workoutTitle'] as String? ?? '训练',
      exerciseId:
          json['exerciseId'] as String? ??
          'legacy-${exerciseName.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff).toRadixString(36)}',
      exerciseName: exerciseName,
      scheduledDateKey:
          json['scheduledDateKey'] as String? ?? _dateKey(timestamp),
      kind: json['kind'] as String? ?? 'training',
      reps: json['reps'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String? ?? '',
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class DailyTrainingSummary {
  const DailyTrainingSummary({
    required this.date,
    required this.dayKey,
    required this.dayLabel,
    required this.workoutTitle,
    required this.sets,
    required this.exerciseCount,
    required this.volume,
  });

  final DateTime date;
  final String dayKey;
  final String dayLabel;
  final String workoutTitle;
  final int sets;
  final int exerciseCount;
  final double volume;
}
