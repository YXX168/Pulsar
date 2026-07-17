class TrainingEvent {
  TrainingEvent({
    required this.timestamp,
    required this.dayKey,
    required this.dayLabel,
    required this.workoutTitle,
    required this.exerciseName,
  });

  final DateTime timestamp;
  final String dayKey;
  final String dayLabel;
  final String workoutTitle;
  final String exerciseName;

  String get dateKey {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'dayKey': dayKey,
    'dayLabel': dayLabel,
    'workoutTitle': workoutTitle,
    'exerciseName': exerciseName,
  };

  factory TrainingEvent.fromJson(Map<String, dynamic> json) => TrainingEvent(
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    dayKey: json['dayKey'] as String? ?? '',
    dayLabel: json['dayLabel'] as String? ?? '',
    workoutTitle: json['workoutTitle'] as String? ?? '训练',
    exerciseName: json['exerciseName'] as String? ?? '训练动作',
  );
}

class DailyTrainingSummary {
  const DailyTrainingSummary({
    required this.date,
    required this.dayKey,
    required this.dayLabel,
    required this.workoutTitle,
    required this.sets,
    required this.exerciseCount,
  });

  final DateTime date;
  final String dayKey;
  final String dayLabel;
  final String workoutTitle;
  final int sets;
  final int exerciseCount;
}
