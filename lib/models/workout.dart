String _stableId(String source) {
  var hash = 0x811c9dc5;
  for (final unit in source.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return 'legacy-${hash.toRadixString(36)}';
}

String newExerciseId() =>
    'item-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

class ExercisePlan {
  ExercisePlan({
    String? id,
    required this.name,
    required this.target,
    required this.sets,
    required this.reps,
    this.kind = 'training',
    this.weight = 0,
    this.note = '',
    this.restSeconds = 60,
  }) : id = id ?? newExerciseId();

  String id;
  String name;
  String target;
  int sets;
  String reps;
  String kind;
  double weight;
  String note;
  int restSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'sets': sets,
    'reps': reps,
    'kind': kind,
    'weight': weight,
    'note': note,
    'restSeconds': restSeconds,
  };

  factory ExercisePlan.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '训练事项';
    final target = json['target'] as String? ?? '';
    final reps = json['reps'] as String? ?? '12 次';
    return ExercisePlan(
      id:
          json['id'] as String? ??
          _stableId('$name|$target|$reps|${json['sets']}'),
      name: name,
      target: target,
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: reps,
      kind: json['kind'] as String? ?? 'training',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String? ?? '',
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 60,
    );
  }
}

class WorkoutDay {
  WorkoutDay({
    required this.keyName,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.exercises,
    this.rest = false,
  });

  final String keyName;
  String day;
  String title;
  String subtitle;
  int palette;
  bool rest;
  List<ExercisePlan> exercises;

  Map<String, dynamic> toJson() => {
    'key': keyName,
    'day': day,
    'title': title,
    'subtitle': subtitle,
    'palette': palette,
    'rest': rest,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    keyName: json['key'] as String? ?? '',
    day: json['day'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    palette: (json['palette'] as num?)?.toInt() ?? 0,
    rest: json['rest'] as bool? ?? false,
    exercises: (json['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ExercisePlan.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

ExercisePlan _exercise(
  String id,
  String name,
  String target,
  int sets,
  String reps, {
  double weight = 0,
  int restSeconds = 60,
}) => ExercisePlan(
  id: id,
  name: name,
  target: target,
  sets: sets,
  reps: reps,
  weight: weight,
  restSeconds: restSeconds,
);

List<WorkoutDay> defaultPlan() => [
  WorkoutDay(
    keyName: 'mon',
    day: '周一',
    title: '上肢推力',
    subtitle: '胸部 · 肩部 · 三头肌',
    palette: 0,
    exercises: [
      _exercise('mon-incline-press', '上斜哑铃卧推', '上胸', 4, '10–12 次'),
      _exercise('mon-bench-press', '平板杠铃卧推', '胸部', 4, '8–10 次'),
      _exercise('mon-shoulder-press', '坐姿器械推肩', '肩部', 3, '12 次'),
      _exercise('mon-lateral-raise', '哑铃侧平举', '三角肌中束', 4, '15–20 次'),
      _exercise('mon-face-pull', '面拉', '三角肌后束', 3, '15–20 次'),
      _exercise('mon-rope-pushdown', '绳索下压', '肱三头肌', 3, '12–15 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'tue',
    day: '周二',
    title: '下肢前侧',
    subtitle: '股四头肌 · 内收肌 · 核心',
    palette: 1,
    exercises: [
      _exercise('tue-leg-press', '倒蹬机', '股四头肌', 4, '12–15 次'),
      _exercise('tue-leg-extension', '腿屈伸', '股四头肌', 3, '15 次'),
      _exercise('tue-adduction', '髋内收', '大腿内侧', 3, '15 次'),
      _exercise('tue-incline-walk', '坡度走', '心肺', 1, '40 分钟'),
      _exercise('tue-crunch', '卷腹', '核心', 5, '20 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'wed',
    day: '周三',
    title: '上肢拉力',
    subtitle: '背部 · 后束 · 二头肌',
    palette: 2,
    exercises: [
      _exercise('wed-pullup', '辅助引体向上', '背阔肌', 4, '8–12 次'),
      _exercise('wed-row', '坐姿器械划船', '中背', 4, '10–12 次'),
      _exercise('wed-pulldown', '高位下拉', '背部宽度', 3, '10–12 次'),
      _exercise('wed-reverse-fly', '反向蝴蝶机', '三角肌后束', 3, '15–20 次'),
      _exercise('wed-curl', '杠铃弯举', '肱二头肌', 4, '12 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'thu',
    day: '周四',
    title: '下肢后链',
    subtitle: '臀部 · 腘绳肌 · 稳定性',
    palette: 3,
    exercises: [
      _exercise('thu-hack-squat', '哈克深蹲', '股四头肌', 4, '12 次'),
      _exercise('thu-leg-curl', '坐姿腿弯举', '腘绳肌', 4, '12–15 次'),
      _exercise('thu-abduction', '髋外展', '臀中肌', 3, '15 次'),
      _exercise('thu-incline-walk', '坡度走', '心肺', 1, '40 分钟'),
      _exercise('thu-crunch', '卷腹', '核心', 5, '20 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'fri',
    day: '周五',
    title: '全身循环',
    subtitle: '自由训练',
    palette: 4,
    exercises: [
      _exercise('fri-goblet-squat', '高脚杯深蹲', '下肢与核心', 3, '12 次'),
      _exercise('fri-pushup', '俯卧撑', '胸部与肩部', 3, '10–15 次'),
      _exercise('fri-rdl', '罗马尼亚硬拉', '臀腿后链', 3, '12 次'),
      _exercise('fri-row', '俯身划船', '背部', 3, '每侧 10 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'sat',
    day: '周六',
    title: '自由探索',
    subtitle: '阅读 · 学习 · AI 创造',
    palette: 5,
    rest: true,
    exercises: [],
  ),
  WorkoutDay(
    keyName: 'sun',
    day: '周日',
    title: '主动恢复',
    subtitle: '步行 · 游泳 · 拉伸',
    palette: 6,
    exercises: [
      _exercise('sun-cardio', '低强度有氧', '恢复', 1, '30–40 分钟'),
      _exercise('sun-stretch', '全身拉伸', '活动度', 1, '15 分钟'),
      _exercise('sun-foam-roll', '泡沫轴放松', '肌肉恢复', 1, '10 分钟'),
    ],
  ),
];
