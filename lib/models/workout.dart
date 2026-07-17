class ExercisePlan {
  ExercisePlan({
    required this.name,
    required this.target,
    required this.sets,
    required this.reps,
  });

  String name;
  String target;
  int sets;
  String reps;

  Map<String, dynamic> toJson() => {
    'name': name,
    'target': target,
    'sets': sets,
    'reps': reps,
  };

  factory ExercisePlan.fromJson(Map<String, dynamic> json) => ExercisePlan(
    name: json['name'] as String? ?? '训练动作',
    target: json['target'] as String? ?? '',
    sets: (json['sets'] as num?)?.toInt() ?? 3,
    reps: json['reps'] as String? ?? '12 次',
  );
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

List<WorkoutDay> defaultPlan() => [
  WorkoutDay(
    keyName: 'mon',
    day: '周一',
    title: '上肢推力',
    subtitle: '胸部 · 肩部 · 三头肌',
    palette: 0,
    exercises: [
      ExercisePlan(name: '上斜哑铃卧推', target: '上胸', sets: 4, reps: '10–12 次'),
      ExercisePlan(name: '平板杠铃卧推', target: '胸部', sets: 4, reps: '8–10 次'),
      ExercisePlan(name: '坐姿器械推肩', target: '肩部', sets: 3, reps: '12 次'),
      ExercisePlan(name: '哑铃侧平举', target: '三角肌中束', sets: 4, reps: '15–20 次'),
      ExercisePlan(name: '面拉', target: '三角肌后束', sets: 3, reps: '15–20 次'),
      ExercisePlan(name: '绳索下压', target: '肱三头肌', sets: 3, reps: '12–15 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'tue',
    day: '周二',
    title: '下肢前侧',
    subtitle: '股四头肌 · 内收肌 · 核心',
    palette: 1,
    exercises: [
      ExercisePlan(name: '倒蹬机', target: '股四头肌', sets: 4, reps: '12–15 次'),
      ExercisePlan(name: '腿屈伸', target: '股四头肌', sets: 3, reps: '15 次'),
      ExercisePlan(name: '髋内收', target: '大腿内侧', sets: 3, reps: '15 次'),
      ExercisePlan(name: '坡度走', target: '心肺', sets: 1, reps: '40 分钟'),
      ExercisePlan(name: '卷腹', target: '核心', sets: 5, reps: '20 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'wed',
    day: '周三',
    title: '上肢拉力',
    subtitle: '背部 · 后束 · 二头肌',
    palette: 2,
    exercises: [
      ExercisePlan(name: '辅助引体向上', target: '背阔肌', sets: 4, reps: '8–12 次'),
      ExercisePlan(name: '坐姿器械划船', target: '中背', sets: 4, reps: '10–12 次'),
      ExercisePlan(name: '高位下拉', target: '背部宽度', sets: 3, reps: '10–12 次'),
      ExercisePlan(name: '反向蝴蝶机', target: '三角肌后束', sets: 3, reps: '15–20 次'),
      ExercisePlan(name: '杠铃弯举', target: '肱二头肌', sets: 4, reps: '12 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'thu',
    day: '周四',
    title: '下肢后链',
    subtitle: '臀部 · 腘绳肌 · 稳定性',
    palette: 3,
    exercises: [
      ExercisePlan(name: '哈克深蹲', target: '股四头肌', sets: 4, reps: '12 次'),
      ExercisePlan(name: '坐姿腿弯举', target: '腘绳肌', sets: 4, reps: '12–15 次'),
      ExercisePlan(name: '髋外展', target: '臀中肌', sets: 3, reps: '15 次'),
      ExercisePlan(name: '坡度走', target: '心肺', sets: 1, reps: '40 分钟'),
      ExercisePlan(name: '卷腹', target: '核心', sets: 5, reps: '20 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'fri',
    day: '周五',
    title: '全身循环',
    subtitle: '自由训练',
    palette: 4,
    exercises: [
      ExercisePlan(name: '高脚杯深蹲', target: '下肢与核心', sets: 3, reps: '12 次'),
      ExercisePlan(name: '俯卧撑', target: '胸部与肩部', sets: 3, reps: '10–15 次'),
      ExercisePlan(name: '罗马尼亚硬拉', target: '臀腿后链', sets: 3, reps: '12 次'),
      ExercisePlan(name: '俯身划船', target: '背部', sets: 3, reps: '每侧 10 次'),
    ],
  ),
  WorkoutDay(
    keyName: 'sat',
    day: '周六',
    title: '完全休息',
    subtitle: '恢复与睡眠',
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
      ExercisePlan(name: '低强度有氧', target: '恢复', sets: 1, reps: '30–40 分钟'),
      ExercisePlan(name: '全身拉伸', target: '活动度', sets: 1, reps: '15 分钟'),
      ExercisePlan(name: '泡沫轴放松', target: '肌肉恢复', sets: 1, reps: '10 分钟'),
    ],
  ),
];
