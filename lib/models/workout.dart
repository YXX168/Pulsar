class ExercisePlan {
  ExercisePlan({required this.name, required this.target, required this.sets, required this.reps});
  String name;
  String target;
  int sets;
  String reps;
  Map<String, dynamic> toJson() => {'name': name, 'target': target, 'sets': sets, 'reps': reps};
  factory ExercisePlan.fromJson(Map<String, dynamic> json) => ExercisePlan(
    name: json['name'] as String? ?? '训练动作', target: json['target'] as String? ?? '',
    sets: (json['sets'] as num?)?.toInt() ?? 3, reps: json['reps'] as String? ?? '12');
}

class WorkoutDay {
  WorkoutDay({required this.keyName, required this.day, required this.title, required this.subtitle, required this.palette, required this.exercises, this.rest = false});
  final String keyName;
  String day;
  String title;
  String subtitle;
  int palette;
  bool rest;
  List<ExercisePlan> exercises;
  Map<String, dynamic> toJson() => {'key': keyName, 'day': day, 'title': title, 'subtitle': subtitle, 'palette': palette, 'rest': rest, 'exercises': exercises.map((e) => e.toJson()).toList()};
  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    keyName: json['key'] as String? ?? '', day: json['day'] as String? ?? '', title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '', palette: (json['palette'] as num?)?.toInt() ?? 0,
    rest: json['rest'] as bool? ?? false,
    exercises: (json['exercises'] as List? ?? const []).whereType<Map>().map((e) => ExercisePlan.fromJson(Map<String, dynamic>.from(e))).toList());
}

List<WorkoutDay> defaultPlan() => [
  WorkoutDay(keyName:'mon', day:'MON', title:'Upper Push', subtitle:'Chest · Shoulder · Triceps', palette:0, exercises:[
    ExercisePlan(name:'上斜哑铃卧推',target:'上胸',sets:4,reps:'10–12'), ExercisePlan(name:'平板杠铃卧推',target:'胸部厚度',sets:4,reps:'8–10'),
    ExercisePlan(name:'坐姿器械推肩',target:'三角肌',sets:3,reps:'12'), ExercisePlan(name:'哑铃侧平举',target:'中束',sets:4,reps:'15–20'),
    ExercisePlan(name:'面拉',target:'后束',sets:3,reps:'15–20'), ExercisePlan(name:'绳索下压',target:'三头',sets:3,reps:'12–15')]),
  WorkoutDay(keyName:'tue', day:'TUE', title:'Lower Front', subtitle:'Quads · Adductor · Core', palette:1, exercises:[
    ExercisePlan(name:'倒蹬机',target:'股四头 / 臀',sets:4,reps:'12–15'), ExercisePlan(name:'腿屈伸',target:'股四头',sets:3,reps:'15'),
    ExercisePlan(name:'内收机',target:'大腿内侧',sets:3,reps:'15'), ExercisePlan(name:'坡度走',target:'心肺',sets:1,reps:'40 min'), ExercisePlan(name:'卷腹',target:'腹直肌',sets:5,reps:'20')]),
  WorkoutDay(keyName:'wed', day:'WED', title:'Upper Pull', subtitle:'Back · Rear Delt · Biceps', palette:2, exercises:[
    ExercisePlan(name:'助力引体向上',target:'背阔肌',sets:4,reps:'8–12'), ExercisePlan(name:'坐姿器械划船',target:'中背',sets:4,reps:'10–12'),
    ExercisePlan(name:'高位下拉',target:'背部宽度',sets:3,reps:'10–12'), ExercisePlan(name:'反向蝴蝶机',target:'后束',sets:3,reps:'15–20'), ExercisePlan(name:'杠铃弯举',target:'肱二头',sets:4,reps:'12')]),
  WorkoutDay(keyName:'thu', day:'THU', title:'Lower Chain', subtitle:'Glutes · Hamstring · Stability', palette:3, exercises:[
    ExercisePlan(name:'哈克深蹲',target:'股四头 / 臀',sets:4,reps:'12'), ExercisePlan(name:'坐姿腿弯举',target:'腘绳肌',sets:4,reps:'12–15'),
    ExercisePlan(name:'外展机',target:'臀中肌',sets:3,reps:'15'), ExercisePlan(name:'坡度走',target:'心肺',sets:1,reps:'40 min'), ExercisePlan(name:'卷腹',target:'腹直肌',sets:5,reps:'20')]),
  WorkoutDay(keyName:'fri', day:'FRI', title:'Full Circuit', subtitle:'Free Training', palette:4, exercises:[
    ExercisePlan(name:'高脚杯深蹲',target:'下肢 / 核心',sets:3,reps:'12'), ExercisePlan(name:'俯卧撑',target:'胸 / 肩',sets:3,reps:'10–15'),
    ExercisePlan(name:'罗马尼亚硬拉',target:'臀腿后链',sets:3,reps:'12'), ExercisePlan(name:'俯身划船',target:'背阔肌',sets:3,reps:'每侧 10')]),
  WorkoutDay(keyName:'sat', day:'SAT', title:'Silent Recovery', subtitle:'Rest', palette:5, rest:true, exercises:[]),
  WorkoutDay(keyName:'sun', day:'SUN', title:'Active Recovery', subtitle:'Walk · Swim · Stretch', palette:6, exercises:[
    ExercisePlan(name:'低强度心肺',target:'恢复',sets:1,reps:'30–40 min'), ExercisePlan(name:'全身拉伸',target:'活动度',sets:1,reps:'15 min'), ExercisePlan(name:'泡沫轴放松',target:'肌肉恢复',sets:1,reps:'10 min')]),
];
