import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/workout.dart';
import 'models/training_event.dart';
import 'services/storage.dart';
import 'widgets/liquid_orb.dart';
import 'widgets/galaxy_scene.dart';

DateTime _startOfWeek(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - 1));

DateTime? _parseDateKey(String value) => DateTime.tryParse(value);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF081126),
    ),
  );
  runApp(const PulsarApp());
}

class PulsarApp extends StatefulWidget {
  const PulsarApp({super.key});

  @override
  State<PulsarApp> createState() => _PulsarAppState();
}

class _PulsarAppState extends State<PulsarApp> {
  late final PulsarController controller;

  @override
  void initState() {
    super.initState();
    controller = PulsarController()..initialize();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) =>
        PulsarMotion(level: controller.effectsLevel, child: child!),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pulsar',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D9FF),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFD5DDF0)),
          bodySmall: TextStyle(color: Color(0xFF8290AA)),
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => controller.ready
            ? PulsarShell(controller: controller)
            : const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
      ),
    ),
  );
}

class PulsarController extends ChangeNotifier {
  final storage = PulsarStorage();
  bool ready = false;
  List<WorkoutDay> plan = [];
  Map<String, Map<String, int>> completed = {};
  List<TrainingEvent> events = [];
  bool galaxyMode = true;
  int effectsLevel = 2;
  DateTime selectedWeekStart = _startOfWeek(DateTime.now());

  Future<void> initialize() async {
    plan = await storage.loadPlan();
    completed = await storage.loadSets(plan);
    events = await storage.loadEvents();
    galaxyMode = await storage.loadGalaxyMode();
    effectsLevel = await storage.loadEffectsLevel();
    ready = true;
    notifyListeners();
  }

  String progressDate(WorkoutDay day) =>
      scheduledDateKey(day.keyName, selectedWeekStart);

  String get weekLabel {
    final end = selectedWeekStart.add(const Duration(days: 6));
    if (selectedWeekStart.month == end.month) {
      return '${selectedWeekStart.month}月${selectedWeekStart.day}—${end.day}日';
    }
    return '${selectedWeekStart.month}月${selectedWeekStart.day}日—'
        '${end.month}月${end.day}日';
  }

  bool get isCurrentWeek => selectedWeekStart == _startOfWeek(DateTime.now());

  void shiftWeek(int delta) {
    selectedWeekStart = selectedWeekStart.add(Duration(days: delta * 7));
    notifyListeners();
  }

  void returnToCurrentWeek() {
    selectedWeekStart = _startOfWeek(DateTime.now());
    notifyListeners();
  }

  int count(WorkoutDay day, int index) {
    if (index < 0 || index >= day.exercises.length) return 0;
    return completed[progressDate(day)]?[day.exercises[index].id] ?? 0;
  }

  int totalSets(WorkoutDay day) =>
      day.exercises.fold(0, (total, exercise) => total + exercise.sets);

  int doneSets(WorkoutDay day) => day.exercises.asMap().entries.fold(
    0,
    (total, entry) => total + count(day, entry.key).clamp(0, entry.value.sets),
  );

  double progress(WorkoutDay day) {
    if (day.rest || isSkipped(day)) return 0;
    final total = totalSets(day);
    return total == 0 ? 0 : doneSets(day) / total;
  }

  Future<void> setCount(
    WorkoutDay day,
    int index,
    int value, {
    bool recordSet = false,
  }) async {
    if (index < 0 || index >= day.exercises.length) return;
    final exercise = day.exercises[index];
    final date = progressDate(day);
    final current = count(day, index);
    final next = value.clamp(0, exercise.sets);
    completed.putIfAbsent(date, () => {});
    completed[date]!.remove('__skipped__');
    completed[date]![exercise.id] = next;

    if (next > current) {
      for (var offset = 0; offset < next - current; offset++) {
        final timestamp = DateTime.now().add(Duration(microseconds: offset));
        events.insert(
          0,
          TrainingEvent(
            timestamp: timestamp,
            dayKey: day.keyName,
            dayLabel: day.day,
            workoutTitle: day.title,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            scheduledDateKey: date,
            kind: exercise.kind,
            reps: exercise.reps,
            weight: exercise.weight,
            note: exercise.note,
          ),
        );
      }
    } else if (next < current) {
      var remaining = current - next;
      events.removeWhere((event) {
        if (remaining <= 0 ||
            event.exerciseId != exercise.id ||
            event.scheduledDateKey != date) {
          return false;
        }
        remaining--;
        return true;
      });
    }
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
  }

  List<TrainingEvent> eventsForSummary(DailyTrainingSummary summary) {
    final date = _dateKey(summary.date);
    return events
        .where(
          (event) => event.dateKey == date && event.dayKey == summary.dayKey,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<bool> addDetailedSet(
    WorkoutDay day,
    int index, {
    required String reps,
    required double weight,
    required double rpe,
    required String note,
  }) async {
    if (index < 0 || index >= day.exercises.length) return false;
    final exercise = day.exercises[index];
    final current = count(day, index);
    if (current >= exercise.sets) return false;
    final date = progressDate(day);
    completed.putIfAbsent(date, () => {})
      ..remove('__skipped__')
      ..[exercise.id] = current + 1;
    events.insert(
      0,
      TrainingEvent(
        timestamp: DateTime.now(),
        dayKey: day.keyName,
        dayLabel: day.day,
        workoutTitle: day.title,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        scheduledDateKey: date,
        kind: exercise.kind,
        reps: reps.trim().isEmpty ? exercise.reps : reps.trim(),
        weight: weight,
        rpe: rpe.clamp(0, 10),
        note: note.trim(),
      ),
    );
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
    return true;
  }

  Future<void> updateEvent(TrainingEvent updated) async {
    final index = events.indexWhere((event) => event.id == updated.id);
    if (index < 0) return;
    events[index] = updated;
    notifyListeners();
    await storage.saveEvents(events);
  }

  Future<void> deleteEvent(TrainingEvent event) async {
    final removed = events.indexWhere((item) => item.id == event.id);
    if (removed < 0) return;
    events.removeAt(removed);
    final values = completed[event.scheduledDateKey];
    final current = values?[event.exerciseId] ?? 0;
    if (current > 0) values![event.exerciseId] = current - 1;
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
  }

  int setsOnDate(DateTime date) =>
      events.where((event) => event.scheduledDateKey == _dateKey(date)).length;

  int get activeDays => events.map((event) => event.dateKey).toSet().length;

  double get totalVolume =>
      events.fold(0, (sum, event) => sum + event.estimatedVolume);

  List<TrainingEvent> get personalBests {
    final best = <String, TrainingEvent>{};
    for (final event in events.where((event) => event.weight > 0)) {
      final current = best[event.exerciseId];
      if (current == null || event.weight > current.weight) {
        best[event.exerciseId] = event;
      }
    }
    final values = best.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return values;
  }

  int get currentStreak {
    final active = events.map((event) => event.dateKey).toSet();
    if (active.isEmpty) return 0;
    var cursor = DateTime.now();
    if (!active.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (active.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<DailyTrainingSummary> get trainingSummaries {
    final grouped = <String, List<TrainingEvent>>{};
    for (final event in events) {
      grouped
          .putIfAbsent('${event.dateKey}|${event.dayKey}', () => [])
          .add(event);
    }
    final summaries = grouped.values.map((items) {
      final first = items.first;
      final scheduled =
          _parseDateKey(first.scheduledDateKey) ?? first.timestamp;
      return DailyTrainingSummary(
        date: DateTime(scheduled.year, scheduled.month, scheduled.day),
        dayKey: first.dayKey,
        dayLabel: first.dayLabel,
        workoutTitle: first.workoutTitle,
        sets: items.length,
        exerciseCount: items.map((event) => event.exerciseName).toSet().length,
        volume: items.fold(0, (sum, event) => sum + event.estimatedVolume),
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> updatePlan() async {
    notifyListeners();
    await storage.savePlan(plan);
  }

  bool isSkipped(WorkoutDay day) =>
      completed[progressDate(day)]?['__skipped__'] == 1;

  Future<void> toggleSkipped(WorkoutDay day) async {
    final date = progressDate(day);
    final values = completed.putIfAbsent(date, () => {});
    if (values['__skipped__'] == 1) {
      values.remove('__skipped__');
    } else {
      values['__skipped__'] = 1;
      for (final exercise in day.exercises) {
        values.remove(exercise.id);
      }
      events.removeWhere((event) => event.scheduledDateKey == date);
    }
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
  }

  Future<void> setGalaxyMode(bool enabled) async {
    if (galaxyMode == enabled) return;
    galaxyMode = enabled;
    notifyListeners();
    await storage.saveGalaxyMode(enabled);
  }

  Future<void> setEffectsLevel(int level) async {
    effectsLevel = level.clamp(0, 2);
    notifyListeners();
    await storage.saveEffectsLevel(effectsLevel);
  }

  String exportBackup() => jsonEncode({
    'schema': 3,
    'exportedAt': DateTime.now().toIso8601String(),
    'plan': plan.map((day) => day.toJson()).toList(),
    'completed': completed,
    'events': events.map((event) => event.toJson()).toList(),
    'settings': {'galaxyMode': galaxyMode, 'effectsLevel': effectsLevel},
  });

  Future<bool> importBackup(String raw) async {
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final restoredPlan = (data['plan'] as List)
          .whereType<Map>()
          .map((item) => WorkoutDay.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final restoredSets =
          Map<String, dynamic>.from(data['completed'] as Map? ?? const {}).map(
            (date, values) => MapEntry(
              date,
              Map<String, dynamic>.from(
                values as Map,
              ).map((id, value) => MapEntry(id, (value as num).toInt())),
            ),
          );
      final restoredEvents = (data['events'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => TrainingEvent.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      if (restoredPlan.length != 7) return false;
      plan = restoredPlan;
      completed = restoredSets;
      events = restoredEvents;
      final settings = data['settings'];
      if (settings is Map) {
        final values = Map<String, dynamic>.from(settings);
        galaxyMode = values['galaxyMode'] as bool? ?? galaxyMode;
        effectsLevel =
            ((values['effectsLevel'] as num?)?.toInt() ?? effectsLevel).clamp(
              0,
              2,
            );
      }
      selectedWeekStart = _startOfWeek(DateTime.now());
      await storage.replaceAll(plan: plan, sets: completed, events: events);
      await storage.saveGalaxyMode(galaxyMode);
      await storage.saveEffectsLevel(effectsLevel);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearRecords() async {
    completed = {};
    events = [];
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
  }

  Future<void> undoLastSet() async {
    if (events.isEmpty) return;
    final event = events.removeAt(0);
    final values = completed[event.scheduledDateKey];
    final current = values?[event.exerciseId] ?? 0;
    if (current > 0) values![event.exerciseId] = current - 1;
    notifyListeners();
    await storage.saveSets(completed);
    await storage.saveEvents(events);
  }
}

class PulsarShell extends StatefulWidget {
  const PulsarShell({required this.controller, super.key});

  final PulsarController controller;

  @override
  State<PulsarShell> createState() => _PulsarShellState();
}

class _PulsarShellState extends State<PulsarShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      widget.controller.galaxyMode
          ? GalaxyScreen(controller: widget.controller)
          : NormalWorkoutScreen(controller: widget.controller),
      RecordsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];
    return PopScope<Object?>(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          HapticFeedback.selectionClick();
          setState(() => index = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: PulsarBackdrop(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: IndexedStack(index: index, children: pages),
            ),
          ),
        ),
        bottomNavigationBar: _PulsarDock(
          height: 68,
          selectedIndex: index,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            setState(() => index = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.blur_circular_outlined),
              selectedIcon: Icon(Icons.blur_circular_rounded),
              label: '训练',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: '记录',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              selectedIcon: Icon(Icons.tune_rounded),
              label: '计划',
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsarDock extends StatelessWidget {
  const _PulsarDock({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.height,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final double height;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.transparent,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 3),
      child: SizedBox(
        key: const ValueKey('orb-navigation'),
        height: height + 4,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: destinations.asMap().entries.map((entry) {
            final index = entry.key;
            final destination = entry.value;
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Semantics(
                selected: selected,
                button: true,
                label: destination.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDestinationSelected(index),
                  child: SizedBox(
                    width: 66,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          scale: selected ? 1.03 : .78,
                          child: LiquidOrb(
                            size: 50,
                            palette: PulsarPalette.values[index + 1],
                            value: selected ? 1 : 0,
                            total: 1,
                            showValue: false,
                            hero: selected,
                          ),
                        ),
                        Positioned(
                          top: 16,
                          child: IconTheme(
                            data: IconThemeData(
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF91A4BF),
                            ),
                            child: selected
                                ? destination.selectedIcon ?? destination.icon
                                : destination.icon,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Text(
                            destination.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? const Color(0xFFDFF9FF)
                                  : const Color(0xFF778AA7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

class PulsarBackdrop extends StatelessWidget {
  const PulsarBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF070B20), Color(0xFF0B1733), Color(0xFF102443)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          top: -170,
          right: -150,
          child: _AmbientGlow(size: 370, color: Color(0xFF593DFF)),
        ),
        const Positioned(
          bottom: -190,
          left: -170,
          child: _AmbientGlow(size: 400, color: Color(0xFF00B9D6)),
        ),
        child,
      ],
    ),
  );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .22), Colors.transparent],
        ),
      ),
    ),
  );
}

class PulsarHeader extends StatelessWidget {
  const PulsarHeader({
    super.key,
    this.title,
    this.progress,
    this.onBack,
    this.energyExpanded = false,
    this.energyLabel,
    this.energyValue,
    this.energyTotal,
  });

  final String? title;
  final double? progress;
  final VoidCallback? onBack;
  final bool energyExpanded;
  final String? energyLabel;
  final int? energyValue;
  final int? energyTotal;

  @override
  Widget build(BuildContext context) {
    final expandedWidth = math.min(
      MediaQuery.sizeOf(context).width - 82,
      310.0,
    );
    return SizedBox(
      height: 78,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 21),
                  )
                else
                  const _Brand(),
                if (title != null)
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 130),
                      opacity: energyExpanded ? 0 : 1,
                      child: Text(
                        title!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (progress != null || onBack != null)
                  const SizedBox(width: 92)
                else
                  const Spacer(),
              ],
            ),
          ),
          if (progress != null)
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: energyExpanded ? 1 : 0),
                  duration: Duration(milliseconds: energyExpanded ? 300 : 360),
                  curve: Curves.easeInOutCubic,
                  builder: (context, t, child) {
                    final itemProgress = (energyTotal ?? 0) > 0
                        ? ((energyValue ?? 0) / energyTotal!).clamp(0.0, 1.0)
                        : progress!;
                    return Container(
                      key: const ValueKey('header-energy-meter'),
                      width: 82 + (expandedWidth - 82) * t,
                      height: 38 + 18 * t,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14 * t,
                        vertical: 2 + 7 * t,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8 + 10 * t),
                        color: Color.lerp(
                          Colors.transparent,
                          const Color(0xF20B1730),
                          t,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFF59DFF4,
                          ).withValues(alpha: .40 * t),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF29CFE8,
                            ).withValues(alpha: .26 * t),
                            blurRadius: 22 * t,
                          ),
                        ],
                      ),
                      child: ClipRect(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 17,
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  Opacity(
                                    opacity: 1 - t,
                                    child: Text(
                                      '${(progress! * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB8C3D8),
                                      ),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: t,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.bolt_rounded,
                                          size: 13,
                                          color: Color(0xFF79E9F7),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            energyLabel ?? '能量同步',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${energyValue ?? 0} / ${energyTotal ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF87EDFA),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4 + 3 * t),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: SizedBox(
                                height: 2 + 2 * t,
                                child: LinearProgressIndicator(
                                  value:
                                      progress! +
                                      (itemProgress - progress!) * t,
                                  backgroundColor: const Color(0xFF182642),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF54E8F5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const LiquidOrb(
        size: 52,
        palette: PulsarPalette(
          Color(0xFFE8FDFF),
          Color(0xFF27D8F5),
          Color(0xFF745EFF),
        ),
        value: 0,
        total: 1,
        showValue: false,
        hero: true,
      ),
      const SizedBox(width: 7),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF8DEAFF), Color(0xFF9B83FF)],
            ).createShader(bounds),
            child: const Text(
              'PULSAR',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.2,
                color: Colors.white,
              ),
            ),
          ),
          const Text(
            'ENERGY MATRIX',
            style: TextStyle(
              fontSize: 7,
              color: Color(0xFF8FA9C8),
              letterSpacing: 1.35,
            ),
          ),
        ],
      ),
    ],
  );
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _weekButton(
          tooltip: '上一周',
          icon: Icons.chevron_left_rounded,
          onTap: () => controller.shiftWeek(-1),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .96, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: GestureDetector(
            key: ValueKey(controller.weekLabel),
            onTap: controller.isCurrentWeek
                ? null
                : controller.returnToCurrentWeek,
            child: Container(
              constraints: const BoxConstraints(minWidth: 146),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0x75121E35),
                border: Border.all(color: const Color(0x30456E93)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.weekLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC8EEFA),
                    ),
                  ),
                  if (!controller.isCurrentWeek)
                    const Text(
                      '轻触回到本周',
                      style: TextStyle(fontSize: 6, color: Color(0xFF718AA7)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _weekButton(
          tooltip: '下一周',
          icon: Icons.chevron_right_rounded,
          onTap: () => controller.shiftWeek(1),
        ),
      ],
    ),
  );

  Widget _weekButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) => Tooltip(
    message: tooltip,
    child: InkResponse(
      radius: 22,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66131F37),
          border: Border.all(color: const Color(0x294A7598)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF91DDEA)),
      ),
    ),
  );
}

class NormalWorkoutScreen extends StatefulWidget {
  const NormalWorkoutScreen({required this.controller, super.key});

  final PulsarController controller;

  @override
  State<NormalWorkoutScreen> createState() => _NormalWorkoutScreenState();
}

class _NormalWorkoutScreenState extends State<NormalWorkoutScreen> {
  late int selectedDay;
  late final PageController _dayController;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now().weekday - 1;
    _dayController = PageController(initialPage: selectedDay);
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            const PulsarHeader(title: '脉冲矩阵'),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                tooltip: '切换至星环模式',
                onPressed: () => widget.controller.setGalaxyMode(true),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              ),
            ),
          ],
        ),
        _WeekNavigator(controller: widget.controller),
        _NormalDaySelector(
          plan: widget.controller.plan,
          selected: selectedDay,
          onSelected: (value) {
            HapticFeedback.selectionClick();
            setState(() => selectedDay = value);
            final current = _dayController.page?.round() ?? selectedDay;
            if ((current - value).abs() > 1) {
              _dayController.jumpToPage(value);
            } else {
              _dayController.animateToPage(
                value,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            }
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PageView.builder(
            key: const ValueKey('matrix-day-pager'),
            controller: _dayController,
            onPageChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => selectedDay = value);
            },
            itemCount: widget.controller.plan.length,
            itemBuilder: (context, page) {
              final pageDay = widget.controller.plan[page];
              return Column(
                children: [
                  _NormalProgressCard(
                    controller: widget.controller,
                    day: pageDay,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: pageDay.exercises.isEmpty
                        ? _NormalRestCard(day: pageDay)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                            itemCount: pageDay.exercises.length,
                            itemBuilder: (context, index) =>
                                _NormalExerciseCard(
                                  day: pageDay,
                                  exercise: pageDay.exercises[index],
                                  index: index,
                                  value: widget.controller.count(
                                    pageDay,
                                    index,
                                  ),
                                  palette:
                                      PulsarPalette.values[(pageDay.palette +
                                              index) %
                                          PulsarPalette.values.length],
                                  onTap: () => _toggle(pageDay, index),
                                  onLongPress: () =>
                                      _recordDetailed(pageDay, index),
                                ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(WorkoutDay day, int index) async {
    final exercise = day.exercises[index];
    final current = widget.controller.count(day, index);
    final completing = current < exercise.sets;
    HapticFeedback.mediumImpact();
    await widget.controller.setCount(
      day,
      index,
      completing ? exercise.sets : 0,
      recordSet: completing,
    );
    if (mounted) setState(() {});
  }

  Future<void> _recordDetailed(WorkoutDay day, int index) async {
    final exercise = day.exercises[index];
    final draft = await _showSetEditor(context, exercise: exercise);
    if (draft == null || !mounted) return;
    final added = await widget.controller.addDetailedSet(
      day,
      index,
      reps: draft.reps,
      weight: draft.weight,
      rpe: draft.rpe,
      note: draft.note,
    );
    if (!mounted) return;
    _showPulsarNotice(
      context,
      icon: added ? Icons.bolt_rounded : Icons.info_outline_rounded,
      title: added ? '详细训练组已记录' : '该项目已经完成',
      detail: added
          ? '${exercise.name} · RPE ${draft.rpe.toStringAsFixed(1)}'
          : '重置后可继续记录',
      error: !added,
    );
  }
}

class _NormalDaySelector extends StatelessWidget {
  const _NormalDaySelector({
    required this.plan,
    required this.selected,
    required this.onSelected,
  });

  final List<WorkoutDay> plan;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      scrollDirection: Axis.horizontal,
      itemCount: plan.length,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (context, index) {
        final active = index == selected;
        return GestureDetector(
          key: ValueKey('matrix-day-$index'),
          onTap: () => onSelected(index),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            scale: active ? 1.06 : .94,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF4667D8), Color(0xFF21B8CF)],
                      )
                    : null,
                color: active ? null : const Color(0x80101A30),
                border: Border.all(
                  color: active
                      ? const Color(0x806FEAFF)
                      : const Color(0x263F567B),
                ),
                boxShadow: active
                    ? const [
                        BoxShadow(color: Color(0x3D48CDE2), blurRadius: 14),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF8798B3),
                ),
                child: Text(plan[index].day),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _NormalProgressCard extends StatelessWidget {
  const _NormalProgressCard({required this.controller, required this.day});

  final PulsarController controller;
  final WorkoutDay day;

  @override
  Widget build(BuildContext context) {
    final progress = controller.progress(day);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xB5142342), Color(0xA00F1B33)],
        ),
        border: Border.all(color: const Color(0x354B7EAA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.subtitle,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8EA2C1),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${controller.doneSets(day)} / ${controller.totalSets(day)} 组',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF85EDFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFF17243E),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF55DFF5)),
            ),
          ),
          if (day.exercises.isNotEmpty) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                key: ValueKey('skip-${day.keyName}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.toggleSkipped(day);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: controller.isSkipped(day)
                        ? const Color(0x334D8FAE)
                        : const Color(0x241B2B45),
                    border: Border.all(
                      color: controller.isSkipped(day)
                          ? const Color(0x605AD7E7)
                          : const Color(0x203D5475),
                    ),
                  ),
                  child: Text(
                    controller.isSkipped(day) ? '恢复本周计划' : '仅本周跳过',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: controller.isSkipped(day)
                          ? const Color(0xFF8BE9F3)
                          : const Color(0xFF7E91AD),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NormalExerciseCard extends StatelessWidget {
  const _NormalExerciseCard({
    required this.day,
    required this.exercise,
    required this.index,
    required this.value,
    required this.palette,
    required this.onTap,
    required this.onLongPress,
  });

  final WorkoutDay day;
  final ExercisePlan exercise;
  final int index;
  final int value;
  final PulsarPalette palette;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final progress = exercise.sets == 0 ? 0.0 : value / exercise.sets;
    final done = value >= exercise.sets;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: done
            ? palette.edge.withValues(alpha: .09)
            : const Color(0xB20D172A),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('normal-exercise-${day.keyName}-$index'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? palette.edge : const Color(0xFF15233D),
                    border: Border.all(
                      color: palette.edge.withValues(alpha: .6),
                    ),
                    boxShadow: done
                        ? [
                            BoxShadow(
                              color: palette.edge.withValues(alpha: .45),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.fitness_center_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: done ? const Color(0xFF8D9CB3) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 2,
                        backgroundColor: const Color(0xFF17243E),
                        valueColor: AlwaysStoppedAnimation(palette.core),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${exercise.sets} 组',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: palette.core,
                      ),
                    ),
                    Text(
                      exercise.reps,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8597B3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NormalRestCard extends StatelessWidget {
  const _NormalRestCard({required this.day});
  final WorkoutDay day;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.nightlight_round, size: 42, color: Color(0xFFB7C9E8)),
        const SizedBox(height: 12),
        Text(
          day.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          '今日恢复，也可在设置中添加训练',
          style: TextStyle(fontSize: 10, color: Color(0xFF879AB8)),
        ),
      ],
    ),
  );
}

class GalaxyScreen extends StatefulWidget {
  const GalaxyScreen({required this.controller, super.key});

  final PulsarController controller;

  @override
  State<GalaxyScreen> createState() => _GalaxyScreenState();
}

class _GalaxyScreenState extends State<GalaxyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fissionController;
  bool expanded = false;
  LocalHistoryEntry? _historyEntry;
  Future<void>? _collapseFuture;

  @override
  void initState() {
    super.initState();
    _fissionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 430),
    );
  }

  @override
  void dispose() {
    _fissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      expanded
          ? PulsarHeader(progress: _weeklyProgress, onBack: _collapseGalaxy)
          : Stack(
              children: [
                const PulsarHeader(),
                Positioned(
                  right: 12,
                  top: 12,
                  child: IconButton(
                    tooltip: '切换至脉冲矩阵',
                    onPressed: () => widget.controller.setGalaxyMode(false),
                    icon: const Icon(Icons.view_agenda_rounded, size: 20),
                  ),
                ),
              ],
            ),
      if (expanded) _WeekNavigator(controller: widget.controller),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: GalaxyScenePainter(
                      animation: PulsarMotion.of(context),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: FissionBurstPainter(
                        animation: _fissionController,
                        origin: Alignment.center,
                      ),
                    ),
                  ),
                ),
                _weeklyCore(context, size),
                if (expanded) ..._nodes(context, size),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _weeklyCore(BuildContext context, Size size) {
    final progress = _weeklyProgress;
    final orbSize = math.min(size.width * .72, 278.0);
    return AnimatedBuilder(
      animation: _fissionController,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(
          (_fissionController.value / .30).clamp(0.0, 1.0),
        );
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: expanded,
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1 - t * .68,
                child: Center(
                  child: GestureDetector(
                    key: const ValueKey('weekly-core-hit'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _expandGalaxy,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            LiquidOrb(
                              size: orbSize,
                              palette: const PulsarPalette(
                                Color(0xFFE8FDFF),
                                Color(0xFF30CFF4),
                                Color(0xFF755DFF),
                              ),
                              value: (progress * 100).round(),
                              total: 100,
                              complete: progress >= 1,
                              hero: true,
                              showValue: false,
                            ),
                            const _PulsarCoreGlyph(size: 88),
                          ],
                        ),
                        const Text(
                          'WEEKLY CORE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.8,
                            color: Color(0xFFC7EDFA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double get _weeklyProgress {
    final activeDays = widget.controller.plan.where((day) => !day.rest);
    final total = activeDays.fold<int>(
      0,
      (sum, day) => sum + widget.controller.totalSets(day),
    );
    if (total == 0) return 0;
    final done = activeDays.fold<int>(
      0,
      (sum, day) => sum + widget.controller.doneSets(day),
    );
    return done / total;
  }

  void _expandGalaxy() {
    if (expanded) return;
    setState(() => expanded = true);
    final route = ModalRoute.of(context);
    if (route != null) {
      _historyEntry = LocalHistoryEntry(
        onRemove: () {
          _historyEntry = null;
          _runCollapse();
        },
      );
      route.addLocalHistoryEntry(_historyEntry!);
    }
    _fissionController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  Future<void> _collapseGalaxy() async {
    if (!expanded) return;
    final entry = _historyEntry;
    if (entry != null) {
      entry.remove();
      final running = _collapseFuture;
      if (running != null) await running;
      return;
    }
    await _runCollapse();
  }

  Future<void> _runCollapse() {
    final running = _collapseFuture;
    if (running != null) return running;
    final future = () async {
      HapticFeedback.mediumImpact();
      await _fissionController.animateBack(
        0,
        duration: const Duration(milliseconds: 430),
        curve: Curves.easeInOutCubic,
      );
      if (mounted) setState(() => expanded = false);
    }();
    _collapseFuture = future.whenComplete(() => _collapseFuture = null);
    return _collapseFuture!;
  }

  IconData _dayGlyph(int index) => const [
    Icons.fitness_center_rounded,
    Icons.directions_run_rounded,
    Icons.sports_gymnastics_rounded,
    Icons.air_rounded,
    Icons.bolt_rounded,
    Icons.nightlight_round,
    Icons.spa_rounded,
  ][index % 7];

  List<Widget> _nodes(BuildContext context, Size size) {
    const alignments = [
      Alignment(-.58, -.78),
      Alignment(.54, -.73),
      Alignment(-.52, -.28),
      Alignment(.50, -.17),
      Alignment(-.48, .32),
      Alignment(.52, .38),
      Alignment(0, .62),
    ];
    const sizes = [154.0, 140.0, 142.0, 164.0, 150.0, 138.0, 146.0];
    final todayIndex = DateTime.now().weekday - 1;
    final launch = Alignment.center.alongSize(size);
    return widget.controller.plan.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final alignment = alignments[index];
      final isToday = widget.controller.isCurrentWeek && index == todayIndex;
      final orbSize = sizes[index] + (isToday ? 10 : 0);
      final left = (alignment.x + 1) / 2 * size.width - orbSize / 2;
      final rawTop = (alignment.y + 1) / 2 * size.height - orbSize / 2;
      final top = rawTop.clamp(4.0, size.height - orbSize - 46.0);
      final target = Offset(left + orbSize / 2, top + orbSize / 2);
      final begin = (index * .035).clamp(0.0, .22);
      final fission = CurvedAnimation(
        parent: _fissionController,
        curve: Interval(
          begin,
          (begin + .72).clamp(0.0, 1.0),
          curve: Curves.easeOutExpo,
        ),
      );
      return Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: fission,
          builder: (context, child) {
            final t = fission.value;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: (launch - target) * (1 - t),
                child: Transform.scale(scale: .08 + t * .92, child: child),
              ),
            );
          },
          child: _DriftingGalaxyNode(
            animation: PulsarMotion.of(context),
            phase: index * .91,
            amplitude: isToday ? 9 : 6 + (index % 3) * 1.4,
            child: GestureDetector(
              key: ValueKey('day-hit-${day.keyName}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDay(context, day, alignment),
              onLongPress: day.exercises.isEmpty
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      widget.controller.toggleSkipped(day);
                    },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      LiquidOrb(
                        key: ValueKey('day-${day.keyName}'),
                        size: orbSize,
                        palette: PulsarPalette.values[day.palette],
                        value: (widget.controller.progress(day) * 100).round(),
                        total: 100,
                        showValue: false,
                        complete:
                            !day.rest && widget.controller.progress(day) >= 1,
                        hero: isToday,
                      ),
                      Icon(
                        _dayGlyph(index),
                        size: orbSize * .145,
                        color: const Color(0xFFF1F8FF),
                        shadows: const [
                          Shadow(color: Color(0xFFB8EAFF), blurRadius: 10),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    isToday ? '${day.day} · 今天' : day.day,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.controller.isSkipped(day) ? '本周已跳过' : day.title,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFA6B9D7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _openDay(BuildContext context, WorkoutDay day, Alignment origin) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 110),
        reverseTransitionDuration: const Duration(milliseconds: 110),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: DayGalaxyScreen(
            controller: widget.controller,
            day: day,
            launchOrigin: origin,
          ),
        ),
      ),
    );
    HapticFeedback.mediumImpact();
  }
}

class _DriftingGalaxyNode extends StatelessWidget {
  const _DriftingGalaxyNode({
    required this.animation,
    required this.phase,
    required this.amplitude,
    required this.child,
  });

  final Animation<double> animation;
  final double phase;
  final double amplitude;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final angle = animation.value * math.pi * 2 + phase;
      final x = math.cos(angle) * amplitude;
      final y = math.sin(angle) * amplitude * .74;
      final scale = 1 + math.sin(angle) * .018;
      return Transform.translate(
        offset: Offset(x, y),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}

class _PulsarCoreGlyph extends StatelessWidget {
  const _PulsarCoreGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _PulsarCoreGlyphPainter()),
    ),
  );
}

class _PulsarCoreGlyphPainter extends CustomPainter {
  const _PulsarCoreGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide / 88;
    canvas.drawCircle(
      center,
      25 * unit,
      Paint()
        ..color = const Color(0xFF56E6F5).withValues(alpha: .30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * unit),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Twin polar beams make the mark read as a pulsar, not a generic app icon.
    final beam = Path()
      ..moveTo(-4 * unit, -13 * unit)
      ..lineTo(-1.4 * unit, -35 * unit)
      ..lineTo(1.4 * unit, -35 * unit)
      ..lineTo(4 * unit, -13 * unit)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xE8FFFFFF), Color(0x0076E8F7)],
            ).createShader(
              Rect.fromLTWH(-5 * unit, -36 * unit, 10 * unit, 24 * unit),
            ),
    );
    canvas.save();
    canvas.scale(1, -1);
    canvas.drawPath(
      beam,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xD8FFFFFF), Color(0x006B8FFF)],
            ).createShader(
              Rect.fromLTWH(-5 * unit, -36 * unit, 10 * unit, 24 * unit),
            ),
    );
    canvas.restore();

    final orbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: 58 * unit,
      height: 25 * unit,
    );
    canvas.save();
    canvas.rotate(-.22);
    canvas.drawArc(
      orbitRect,
      .12,
      math.pi * .78,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2 * unit
        ..shader = const LinearGradient(
          colors: [Color(0xFF8CF3FF), Color(0xFFFFFFFF), Color(0xFF8276FF)],
        ).createShader(orbitRect),
    );
    canvas.drawArc(
      orbitRect,
      math.pi + .12,
      math.pi * .78,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.45 * unit
        ..color = const Color(0xB46FD9F4),
    );
    canvas.drawCircle(
      Offset(orbitRect.right - 3 * unit, -1 * unit),
      2.8 * unit,
      Paint()..color = const Color(0xFFE8FDFF),
    );
    canvas.restore();

    final diamond = Path()
      ..moveTo(0, -13 * unit)
      ..lineTo(11 * unit, 0)
      ..lineTo(0, 13 * unit)
      ..lineTo(-11 * unit, 0)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF8DEFFF), Color(0xFF6570F4)],
              stops: [0, .48, 1],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: 25 * unit,
                height: 27 * unit,
              ),
            ),
    );
    canvas.drawCircle(
      Offset.zero,
      3.4 * unit,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PulsarCoreGlyphPainter oldDelegate) => false;
}

class DayGalaxyScreen extends StatefulWidget {
  const DayGalaxyScreen({
    required this.controller,
    required this.day,
    this.launchOrigin = Alignment.center,
    super.key,
  });

  final PulsarController controller;
  final WorkoutDay day;
  final Alignment launchOrigin;

  @override
  State<DayGalaxyScreen> createState() => _DayGalaxyScreenState();
}

class _DayGalaxyScreenState extends State<DayGalaxyScreen>
    with TickerProviderStateMixin {
  final Map<int, bool> armed = {};
  late final AnimationController _breakController;
  late final AnimationController _pulseController;
  int activeExercise = 0;
  bool showExerciseMeter = false;
  Timer? _meterTimer;
  Timer? _restTimer;
  int restRemaining = 0;
  int restTotal = 0;
  bool restPaused = false;
  bool _allowPop = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _breakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      reverseDuration: const Duration(milliseconds: 400),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
  }

  @override
  void dispose() {
    _breakController.dispose();
    _pulseController.dispose();
    _meterTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final activeItem = day.exercises.isEmpty
        ? null
        : day.exercises[math.min(activeExercise, day.exercises.length - 1)];
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeDay();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PulsarBackdrop(
          child: SafeArea(
            child: Column(
              children: [
                PulsarHeader(
                  title: '${day.day} · ${day.title}',
                  progress: widget.controller.progress(day),
                  onBack: _closeDay,
                  energyExpanded: showExerciseMeter && activeItem != null,
                  energyLabel: activeItem?.name,
                  energyValue: activeItem == null
                      ? null
                      : widget.controller.count(day, activeExercise),
                  energyTotal: activeItem?.sets,
                ),
                Expanded(
                  child: day.exercises.isEmpty
                      ? FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _breakController,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          ),
                          child: ScaleTransition(
                            scale: Tween(begin: .48, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _breakController,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInOutCubic,
                              ),
                            ),
                            child: _RestRecoveryScene(
                              animation: PulsarMotion.of(context),
                              palette: PulsarPalette.values[day.palette],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, box) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: DayLinesPainter(
                                    animation: PulsarMotion.of(context),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: FissionBurstPainter(
                                      animation: _breakController,
                                      origin: widget.launchOrigin,
                                      color: PulsarPalette
                                          .values[day.palette]
                                          .core,
                                    ),
                                  ),
                                ),
                              ),
                              ..._exerciseNodes(box.biggest),
                              if (restRemaining > 0)
                                Positioned(
                                  left: 18,
                                  top: 18,
                                  child: _RestTimerRail(
                                    seconds: restRemaining,
                                    total: restTotal,
                                    paused: restPaused,
                                    onTogglePause: _toggleRestTimer,
                                    onAddTime: _addRestTime,
                                    onClose: _stopRestTimer,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _exerciseNodes(Size size) {
    final day = widget.day;
    const alignments = [
      Alignment(0, -.82),
      Alignment(-.66, -.34),
      Alignment(.64, -.24),
      Alignment(-.58, .26),
      Alignment(.55, .39),
      Alignment(0, .66),
    ];
    const sizes = [146.0, 130.0, 138.0, 126.0, 134.0, 124.0];
    return day.exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      final alignment = alignments[index % alignments.length];
      final orbSize = sizes[index % sizes.length];
      final left = (alignment.x + 1) / 2 * size.width - 75;
      final rawTop = (alignment.y + 1) / 2 * size.height - orbSize / 2;
      final top = rawTop.clamp(2.0, size.height - orbSize - 40.0);
      final launch = widget.launchOrigin.alongSize(size);
      final target = Offset(left + 75, top + orbSize / 2);
      final begin = (index * .055).clamp(0.0, .28);
      final movement = CurvedAnimation(
        parent: _breakController,
        curve: Interval(
          begin,
          (begin + .74).clamp(0.0, 1.0),
          curve: Curves.easeOutExpo,
        ),
      );
      final count = widget.controller.count(day, index);
      final done = count >= exercise.sets;
      return Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: movement,
          child: GestureDetector(
            key: ValueKey('exercise-hit-${day.keyName}-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _tapExercise(index, exercise),
            onLongPress: () => _recordDetailed(index, exercise),
            child: SizedBox(
              width: 150,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (activeExercise == index)
                        Positioned(
                          left: -18,
                          top: -18,
                          child: IgnorePointer(
                            child: SizedBox.square(
                              dimension: orbSize + 36,
                              child: CustomPaint(
                                painter: TapPulsePainter(
                                  animation: _pulseController,
                                  color: PulsarPalette
                                      .values[(day.palette + index) %
                                          PulsarPalette.values.length]
                                      .core,
                                ),
                              ),
                            ),
                          ),
                        ),
                      LiquidOrb(
                        key: ValueKey('exercise-${day.keyName}-$index'),
                        size: orbSize,
                        palette:
                            PulsarPalette.values[(day.palette + index) %
                                PulsarPalette.values.length],
                        value: count.clamp(0, exercise.sets),
                        total: exercise.sets,
                        complete: done,
                        armed: armed[index] ?? false,
                        animate: true,
                      ),
                      if (exercise.kind != 'training')
                        Positioned(
                          top: orbSize * .24,
                          child: Icon(
                            _activityIcon(exercise.kind),
                            size: 13,
                            color: Colors.white.withValues(alpha: .88),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    exercise.reps,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFA0B2CD),
                    ),
                  ),
                ],
              ),
            ),
          ),
          builder: (context, child) {
            final t = movement.value;
            final offset = (launch - target) * (1 - t);
            return Transform.translate(
              offset: offset,
              child: Transform.scale(scale: .04 + t * .96, child: child),
            );
          },
        ),
      );
    }).toList();
  }

  Future<void> _tapExercise(int index, ExercisePlan exercise) async {
    _meterTimer?.cancel();
    if (mounted) {
      setState(() {
        activeExercise = index;
        showExerciseMeter = true;
      });
    }
    _meterTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => showExerciseMeter = false);
    });
    _pulseController.forward(from: 0);
    final current = widget.controller.count(widget.day, index);
    if (current >= exercise.sets) {
      if (armed[index] ?? false) {
        armed[index] = false;
        await widget.controller.setCount(widget.day, index, 0);
        HapticFeedback.mediumImpact();
      } else {
        setState(() => armed[index] = true);
        HapticFeedback.selectionClick();
      }
      return;
    }
    final next = current + 1;
    armed[index] = false;
    await widget.controller.setCount(widget.day, index, next, recordSet: true);
    if (exercise.restSeconds > 0) _startRestTimer(exercise.restSeconds);
    if (next >= exercise.sets) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    if (mounted) setState(() {});
  }

  Future<void> _recordDetailed(int index, ExercisePlan exercise) async {
    HapticFeedback.mediumImpact();
    final draft = await _showSetEditor(context, exercise: exercise);
    if (draft == null || !mounted) return;
    final added = await widget.controller.addDetailedSet(
      widget.day,
      index,
      reps: draft.reps,
      weight: draft.weight,
      rpe: draft.rpe,
      note: draft.note,
    );
    if (!mounted) return;
    if (added) {
      setState(() {
        activeExercise = index;
        showExerciseMeter = true;
      });
      _pulseController.forward(from: 0);
      _meterTimer?.cancel();
      _meterTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => showExerciseMeter = false);
      });
      if (exercise.restSeconds > 0) _startRestTimer(exercise.restSeconds);
    }
    _showPulsarNotice(
      context,
      icon: added ? Icons.bolt_rounded : Icons.info_outline_rounded,
      title: added ? '详细训练组已记录' : '该项目已经完成',
      detail: added
          ? '${exercise.name} · RPE ${draft.rpe.toStringAsFixed(1)}'
          : '重置后可继续记录',
      error: !added,
    );
  }

  Future<void> _closeDay() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.mediumImpact();
    await _breakController.reverse();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() {
      restRemaining = seconds;
      restTotal = seconds;
      restPaused = false;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restPaused) return;
      if (!mounted || restRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            restRemaining = 0;
            restTotal = 0;
            restPaused = false;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        setState(() => restRemaining--);
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      restRemaining = 0;
      restTotal = 0;
      restPaused = false;
    });
  }

  void _toggleRestTimer() {
    setState(() => restPaused = !restPaused);
    HapticFeedback.selectionClick();
  }

  void _addRestTime() {
    setState(() {
      restRemaining += 15;
      restTotal += 15;
    });
    HapticFeedback.lightImpact();
  }
}

class _RestTimerRail extends StatelessWidget {
  const _RestTimerRail({
    required this.seconds,
    required this.total,
    required this.paused,
    required this.onTogglePause,
    required this.onAddTime,
    required this.onClose,
  });

  final int seconds;
  final int total;
  final bool paused;
  final VoidCallback onTogglePause;
  final VoidCallback onAddTime;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      key: const ValueKey('rest-timer'),
      width: 54,
      height: 174,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x4A43E3F4), blurRadius: 18),
                  BoxShadow(color: Color(0x303D5FFF), blurRadius: 30),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 6),
              decoration: BoxDecoration(
                color: const Color(0xF20D1930),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x8058DCEB)),
              ),
              child: Column(
                children: [
                  Icon(
                    paused ? Icons.pause_circle_outline : Icons.timer_outlined,
                    size: 15,
                    color: const Color(0xFF73E6F3),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: total <= 0 ? 0 : seconds / total,
                          backgroundColor: const Color(0xFF182642),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF58E4F2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _TimerRailButton(icon: Icons.add_rounded, onTap: onAddTime),
                  _TimerRailButton(
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap: onTogglePause,
                  ),
                  _TimerRailButton(icon: Icons.close_rounded, onTap: onClose),
                ],
              ),
            ),
          ),
          Positioned(
            top: 1,
            left: 14,
            right: 14,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [
                    Color(0x0058E4F2),
                    Color(0xFFFFFFFF),
                    Color(0x0058E4F2),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xAA58E4F2), blurRadius: 9),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TimerRailButton extends StatelessWidget {
  const _TimerRailButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Icon(icon, size: 11, color: const Color(0xFF9BCAD5)),
    ),
  );
}

class _SetDraft {
  const _SetDraft({
    required this.reps,
    required this.weight,
    required this.rpe,
    required this.note,
  });

  final String reps;
  final double weight;
  final double rpe;
  final String note;
}

Future<_SetDraft?> _showSetEditor(
  BuildContext context, {
  required ExercisePlan exercise,
  TrainingEvent? event,
}) => showModalBottomSheet<_SetDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (context) => _SetEditorSheet(exercise: exercise, event: event),
);

class _SetEditorSheet extends StatefulWidget {
  const _SetEditorSheet({required this.exercise, this.event});

  final ExercisePlan exercise;
  final TrainingEvent? event;

  @override
  State<_SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<_SetEditorSheet> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _note;
  late double _rpe;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _reps = TextEditingController(text: event?.reps ?? widget.exercise.reps);
    final weight = event?.weight ?? widget.exercise.weight;
    _weight = TextEditingController(
      text: weight == 0 ? '' : weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1),
    );
    _note = TextEditingController(text: event?.note ?? widget.exercise.note);
    _rpe = event == null || event.rpe == 0 ? 7.5 : event.rpe;
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF152743), Color(0xFF0B1329)],
        ),
        border: Border(top: BorderSide(color: Color(0x665DE4F2))),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E6F91), Color(0xFF72E5EF)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.event == null ? '记录这一组' : '编辑训练组',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              widget.exercise.name,
              style: const TextStyle(fontSize: 10, color: Color(0xFF89A4C1)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _reps,
                    label: '实际次数 / 时长',
                    hint: widget.exercise.reps,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: _field(
                    controller: _weight,
                    label: '重量 kg',
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '主观强度 RPE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  _rpe.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF81EDF5),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF51DDEB),
                inactiveTrackColor: const Color(0xFF1B2A45),
                thumbColor: const Color(0xFFE9FDFF),
                overlayColor: const Color(0x2451DDEB),
                trackHeight: 3,
              ),
              child: Slider(
                value: _rpe,
                min: 1,
                max: 10,
                divisions: 18,
                onChanged: (value) => setState(() => _rpe = value),
              ),
            ),
            const SizedBox(height: 6),
            _field(controller: _note, label: '本组备注', hint: '状态、动作感受或下一组调整'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(
                    _SetDraft(
                      reps: _reps.text.trim(),
                      weight: double.tryParse(_weight.text.trim()) ?? 0,
                      rpe: _rpe,
                      note: _note.text.trim(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF267D9F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(widget.event == null ? '点亮这一组' : '保存修改'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 9, color: Color(0xFF8098B5)),
      filled: true,
      fillColor: const Color(0x68101B31),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0x303B658A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0x303B658A)),
      ),
    ),
  );
}

class _RestRecoveryScene extends StatelessWidget {
  const _RestRecoveryScene({required this.animation, required this.palette});

  final Animation<double> animation;
  final PulsarPalette palette;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: CustomPaint(painter: DayLinesPainter(animation: animation)),
      ),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                LiquidOrb(
                  size: 220,
                  palette: palette,
                  value: 0,
                  total: 1,
                  showValue: false,
                  hero: true,
                ),
                const Icon(
                  Icons.nightlight_round,
                  size: 34,
                  color: Color(0xFFF0F5FF),
                ),
              ],
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFF9DC4FF)],
              ).createShader(bounds),
              child: const Text(
                'RECOVERY MODE',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '恢复  ·  睡眠  ·  生长',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF9EB1CE),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RecoveryChip(icon: Icons.bedtime_outlined, label: '充足睡眠'),
                SizedBox(width: 8),
                _RecoveryChip(icon: Icons.self_improvement, label: '轻度拉伸'),
                SizedBox(width: 8),
                _RecoveryChip(icon: Icons.water_drop_outlined, label: '补充水分'),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _RecoveryChip extends StatelessWidget {
  const _RecoveryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: const Color(0x4D15213A),
      border: Border.all(color: const Color(0x304F73A6)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFFB8CBEB)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Color(0xFFC7D5EB)),
        ),
      ],
    ),
  );
}

class DayLinesPainter extends CustomPainter {
  DayLinesPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final theta = animation.value * math.pi * 2;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0x125BD9F4), Color(0x475E76FF), Color(0x145BD9F4)],
        transform: GradientRotation(theta),
      ).createShader(Offset.zero & size)
      ..strokeWidth = .85
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .5, size.height * .1)
        ..cubicTo(
          size.width * .12,
          size.height * .2,
          size.width * .14,
          size.height * .38,
          size.width * .32,
          size.height * .5,
        )
        ..cubicTo(
          size.width * .68,
          size.height * .67,
          size.width * .82,
          size.height * .53,
          size.width * .78,
          size.height * .39,
        )
        ..moveTo(size.width * .5, size.height * .1)
        ..cubicTo(
          size.width * .82,
          size.height * .23,
          size.width * .74,
          size.height * .47,
          size.width * .47,
          size.height * .62,
        )
        ..cubicTo(
          size.width * .25,
          size.height * .74,
          size.width * .42,
          size.height * .84,
          size.width * .5,
          size.height * .9,
        ),
      paint,
    );

    final center = Offset(size.width * .5, size.height * .48);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.18 + math.sin(theta) * .035);
    final orbit = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .92,
      height: size.height * .34,
    );
    canvas.drawArc(
      orbit,
      theta,
      math.pi * 1.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0x4454CAE8),
    );
    canvas.restore();

    for (var index = 0; index < 34; index++) {
      final x = (index * 71 % 101) / 100 * size.width;
      final baseY = (index * 43 % 97) / 96 * size.height;
      final y = (baseY + math.sin(theta + index) * 5) % size.height;
      final pulse = (math.sin(theta * 2 + index * 1.9) + 1) * .5;
      canvas.drawCircle(
        Offset(x, y),
        index % 7 == 0 ? 1.35 : .55,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF4B91C7),
            const Color(0xFFD0F7FF),
            pulse,
          )!.withValues(alpha: .22 + pulse * .5),
      );
    }

    for (var comet = 0; comet < 3; comet++) {
      final progress = (animation.value * (comet + 1) + comet * .29) % 1;
      final point = Offset(
        size.width * (.08 + progress * .84),
        size.height *
            (.2 + comet * .29 + math.sin(theta * (comet + 1) + comet) * .055),
      );
      canvas.drawCircle(point, 1.4, Paint()..color = const Color(0xD5A9F4FF));
    }
  }

  @override
  bool shouldRepaint(DayLinesPainter oldDelegate) => false;
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({required this.controller, super.key});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) {
    final summaries = controller.trainingSummaries;
    return Column(
      children: [
        const PulsarHeader(title: '训练记录'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
            children: [
              _RecordHero(controller: controller),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Metric(value: '${controller.events.length}', label: '累计组数'),
                  const SizedBox(width: 9),
                  _Metric(value: '${controller.activeDays}', label: '活跃天数'),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _Metric(value: '${controller.currentStreak}', label: '连续天数'),
                  const SizedBox(width: 9),
                  _Metric(
                    value: controller.totalVolume >= 1000
                        ? '${(controller.totalVolume / 1000).toStringAsFixed(1)}t'
                        : '${controller.totalVolume.toStringAsFixed(0)}kg',
                    label: '训练容量',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _EnergyTrend(controller: controller),
              const SizedBox(height: 14),
              _HeatField(controller: controller),
              if (controller.personalBests.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PersonalBestCard(
                  events: controller.personalBests.take(4).toList(),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    '最近训练',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: controller.events.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            controller.undoLastSet();
                          },
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: const Text('撤销最近一组'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (summaries.isEmpty)
                const _EmptyHistory()
              else
                ...summaries
                    .take(12)
                    .map(
                      (summary) => _HistoryCard(
                        controller: controller,
                        summary: summary,
                        palette: _paletteFor(controller, summary.dayKey),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  static PulsarPalette _paletteFor(PulsarController controller, String dayKey) {
    final index = controller.plan.indexWhere((day) => day.keyName == dayKey);
    return PulsarPalette.values[index < 0 ? 0 : controller.plan[index].palette];
  }
}

class _RecordHero extends StatelessWidget {
  const _RecordHero({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0x294A749C)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xD9172943), Color(0xD20B1124)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -4,
          top: 2,
          child: LiquidOrb(
            size: 138,
            palette: PulsarPalette.values[0],
            value: controller.events.length % 100,
            total: 100,
            showValue: false,
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 145, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ENERGY ARCHIVE',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.6,
                    color: Color(0xFF78CFE4),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${controller.events.length}',
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '每一次点击，都留下能量轨迹',
                  maxLines: 2,
                  style: TextStyle(fontSize: 9, color: Color(0xFF8C9AB0)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 76,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x202C3B5E)),
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x8810182A),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Color(0xFF7C8BA5)),
          ),
        ],
      ),
    ),
  );
}

class _EnergyTrend extends StatelessWidget {
  const _EnergyTrend({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final values = days.map(controller.setsOnDate).toList();
    final maxValue = values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    const week = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      height: 164,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0x99101828),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0x202F4664)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '近 7 天能量',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Spacer(),
              Text(
                '完成组数',
                style: TextStyle(fontSize: 8, color: Color(0xFF74849D)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = values[index];
                final height = 9 + 65 * value / maxValue;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF8CA1BD),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 420),
                        width: 17,
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: value == 0
                                ? const [Color(0x182E4260), Color(0x222E4260)]
                                : const [Color(0xFF335EC3), Color(0xFF6FE5EB)],
                          ),
                          boxShadow: value == 0
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x443DCBEB),
                                    blurRadius: 10,
                                  ),
                                ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        week[days[index].weekday - 1],
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF7C8BA4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatField extends StatelessWidget {
  const _HeatField({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      28,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 27 - index)),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x8A101727),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0x202F4664)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '28 天活跃场',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 14,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final value = controller.setsOnDate(days[index]);
              final strength = (value / 8).clamp(0.0, 1.0);
              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value == 0
                      ? const Color(0x182E405B)
                      : Color.lerp(
                          const Color(0xFF294A87),
                          const Color(0xFF79E5E6),
                          strength,
                        ),
                  boxShadow: value == 0
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFF5BC9E0,
                            ).withValues(alpha: .12 + strength * .22),
                            blurRadius: 7,
                          ),
                        ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PersonalBestCard extends StatelessWidget {
  const _PersonalBestCard({required this.events});

  final List<TrainingEvent> events;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    decoration: BoxDecoration(
      color: const Color(0x94101828),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: const Color(0x293B5C82)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 15,
              color: Color(0xFFFFD68A),
            ),
            SizedBox(width: 7),
            Text(
              '个人纪录',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    event.exerciseName,
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
                Text(
                  '${event.weight.toStringAsFixed(event.weight % 1 == 0 ? 0 : 1)} kg',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8DEAF4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.controller,
    required this.summary,
    required this.palette,
  });

  final PulsarController controller;
  final DailyTrainingSummary summary;
  final PulsarPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: const Color(0x92101827),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _TrainingReportScreen(
                controller: controller,
                summary: summary,
                palette: palette,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.edge.withValues(alpha: .13)),
          ),
          child: Row(
            children: [
              LiquidOrb(
                size: 66,
                palette: palette,
                value: summary.sets,
                total: summary.sets,
                complete: true,
                showValue: false,
                animate: false,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.dayLabel} · ${summary.workoutTitle}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      summary.volume > 0
                          ? '${summary.date.month}月${summary.date.day}日 · ${summary.exerciseCount} 个动作 · ${summary.volume.toStringAsFixed(0)}kg'
                          : '${summary.date.month}月${summary.date.day}日 · ${summary.exerciseCount} 个事项',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF7E8BA1),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.sets}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: palette.core,
                    ),
                  ),
                  const Text(
                    '组',
                    style: TextStyle(fontSize: 8, color: Color(0xFF7A879C)),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Color(0xFF667B99),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrainingReportScreen extends StatelessWidget {
  const _TrainingReportScreen({
    required this.controller,
    required this.summary,
    required this.palette,
  });

  final PulsarController controller;
  final DailyTrainingSummary summary;
  final PulsarPalette palette;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final events = controller.eventsForSummary(summary);
      final volume = events.fold<double>(
        0,
        (total, event) => total + event.estimatedVolume,
      );
      final duration = events.length < 2
          ? Duration.zero
          : events.last.timestamp.difference(events.first.timestamp);
      final grouped = <String, List<TrainingEvent>>{};
      for (final event in events) {
        grouped.putIfAbsent(event.exerciseName, () => []).add(event);
      }
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PulsarBackdrop(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                PulsarHeader(
                  title: '训练报告',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 30),
                    children: [
                      _reportHero(events.length, volume, duration),
                      const SizedBox(height: 18),
                      if (events.isEmpty)
                        const _EmptyHistory()
                      else
                        ...grouped.entries.map(
                          (entry) =>
                              _exerciseGroup(context, entry.key, entry.value),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _reportHero(int sets, double volume, Duration duration) => Container(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.edge.withValues(alpha: .24), const Color(0xD20C162C)],
      ),
      border: Border.all(color: palette.core.withValues(alpha: .25)),
      boxShadow: [
        BoxShadow(color: palette.edge.withValues(alpha: .10), blurRadius: 28),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.date.month}月${summary.date.day}日 · ${summary.dayLabel}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: palette.core,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary.workoutTitle,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _reportMetric('$sets', '训练组'),
            _reportMetric(
              volume >= 1000
                  ? '${(volume / 1000).toStringAsFixed(1)}t'
                  : '${volume.toStringAsFixed(0)}kg',
              '容量',
            ),
            _reportMetric(
              duration.inMinutes == 0 ? '—' : '${duration.inMinutes}m',
              '跨度',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _reportMetric(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Color(0xFF8294AD)),
        ),
      ],
    ),
  );

  Widget _exerciseGroup(
    BuildContext context,
    String name,
    List<TrainingEvent> events,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
    decoration: BoxDecoration(
      color: const Color(0x9A101A2D),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x253D5E80)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...events.asMap().entries.map(
          (entry) => _eventRow(context, entry.key + 1, entry.value),
        ),
      ],
    ),
  );

  Widget _eventRow(
    BuildContext context,
    int setNumber,
    TrainingEvent event,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
    decoration: BoxDecoration(
      color: const Color(0x4219273E),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.edge.withValues(alpha: .18),
          ),
          child: Text(
            '$setNumber',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: palette.core,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (event.weight > 0)
                    '${event.weight.toStringAsFixed(event.weight % 1 == 0 ? 0 : 1)} kg',
                  if (event.reps.isNotEmpty) event.reps,
                  if (event.rpe > 0) 'RPE ${event.rpe.toStringAsFixed(1)}',
                ].join('  ·  '),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (event.note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  event.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, color: Color(0xFF7F93AE)),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: '编辑',
          onPressed: () => _edit(context, event),
          icon: const Icon(Icons.edit_outlined, size: 15),
        ),
        IconButton(
          tooltip: '删除',
          onPressed: () => _delete(context, event),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 15,
            color: Color(0xFFB37A92),
          ),
        ),
      ],
    ),
  );

  ExercisePlan _exerciseFor(TrainingEvent event) {
    for (final day in controller.plan) {
      for (final exercise in day.exercises) {
        if (exercise.id == event.exerciseId) return exercise;
      }
    }
    return ExercisePlan(
      id: event.exerciseId,
      name: event.exerciseName,
      target: '',
      sets: 1,
      reps: event.reps,
      kind: event.kind,
      weight: event.weight,
      note: event.note,
    );
  }

  Future<void> _edit(BuildContext context, TrainingEvent event) async {
    HapticFeedback.selectionClick();
    final draft = await _showSetEditor(
      context,
      exercise: _exerciseFor(event),
      event: event,
    );
    if (draft == null || !context.mounted) return;
    await controller.updateEvent(
      event.copyWith(
        reps: draft.reps,
        weight: draft.weight,
        rpe: draft.rpe,
        note: draft.note,
      ),
    );
  }

  Future<void> _delete(BuildContext context, TrainingEvent event) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111D34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('移除这一组？'),
        content: Text(
          '${event.exerciseName} 的完成度会同步回退一组。',
          style: const TextStyle(fontSize: 11, color: Color(0xFF91A2BA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF74435D),
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteEvent(event);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0x66101827),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x182F4664)),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFF657892)),
        SizedBox(height: 8),
        Text(
          '完成第一组后，能量轨迹会出现在这里',
          style: TextStyle(fontSize: 9, color: Color(0xFF748198)),
        ),
      ],
    ),
  );
}

class _EffectsSettingsCard extends StatelessWidget {
  const _EffectsSettingsCard({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
    decoration: BoxDecoration(
      color: const Color(0xAA10182A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x202F4065)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '动态效果',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _effectOption(context, 0, '静谧'),
            const SizedBox(width: 7),
            _effectOption(context, 1, '流畅'),
            const SizedBox(width: 7),
            _effectOption(context, 2, '极致'),
          ],
        ),
      ],
    ),
  );

  Widget _effectOption(BuildContext context, int value, String label) {
    final selected = controller.effectsLevel == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          HapticFeedback.selectionClick();
          controller.setEffectsLevel(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xA34D64E1), Color(0x8731C7D8)],
                  )
                : null,
            color: selected ? null : const Color(0x39152136),
          ),
          child: Text(label, style: const TextStyle(fontSize: 9)),
        ),
      ),
    );
  }
}

class _BackupSettingsCard extends StatelessWidget {
  const _BackupSettingsCard({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xAA10182A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x202F4065)),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.file_upload_outlined, size: 18),
              title: const Text('导出备份', style: TextStyle(fontSize: 10)),
              subtitle: const Text('长按复制 JSON', style: TextStyle(fontSize: 7)),
              onTap: () => _exportFile(context),
              onLongPress: () => _copyBackup(context),
            ),
          ),
          Container(width: 1, height: 30, color: const Color(0x263F5574)),
          Expanded(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.file_download_outlined, size: 18),
              title: const Text('导入备份', style: TextStyle(fontSize: 10)),
              subtitle: const Text('长按读取剪贴板', style: TextStyle(fontSize: 7)),
              onTap: () => _restoreFile(context),
              onLongPress: () => _restoreClipboard(context),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _exportFile(BuildContext context) async {
    try {
      final now = DateTime.now();
      final fileName =
          'Pulsar-${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.json';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出 Pulsar 完整备份',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(controller.exportBackup())),
      );
      if (path == null || !context.mounted) return;
      _showPulsarNotice(
        context,
        icon: Icons.cloud_done_outlined,
        title: '备份已安全导出',
        detail: '计划、进度与历史均已写入文件',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showPulsarNotice(
        context,
        icon: Icons.error_outline_rounded,
        title: '无法导出备份',
        detail: '请检查系统文件选择器后重试',
        error: true,
      );
    }
  }

  Future<void> _copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: controller.exportBackup()));
    if (!context.mounted) return;
    _showPulsarNotice(
      context,
      icon: Icons.copy_all_rounded,
      title: '完整备份已复制',
      detail: '可长按“导入备份”从剪贴板恢复',
    );
  }

  Future<void> _restoreFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择 Pulsar JSON 备份',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null || !context.mounted) return;
      await _restoreRaw(context, utf8.decode(bytes));
    } catch (_) {
      if (!context.mounted) return;
      _showPulsarNotice(
        context,
        icon: Icons.error_outline_rounded,
        title: '无法读取备份文件',
        detail: '请选择由 Pulsar 导出的 JSON 文件',
        error: true,
      );
    }
  }

  Future<void> _restoreClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim();
    if (raw == null || raw.isEmpty) {
      if (!context.mounted) return;
      _showPulsarNotice(
        context,
        icon: Icons.content_paste_off_rounded,
        title: '剪贴板中没有备份',
        detail: '请先复制完整的 Pulsar JSON 数据',
        error: true,
      );
      return;
    }
    if (!context.mounted) return;
    await _restoreRaw(context, raw);
  }

  Future<void> _restoreRaw(BuildContext context, String raw) async {
    final ok = await controller.importBackup(raw.trim());
    if (!context.mounted) return;
    _showPulsarNotice(
      context,
      icon: ok ? Icons.auto_awesome_rounded : Icons.error_outline_rounded,
      title: ok ? '计划与历史已恢复' : '备份内容无法识别',
      detail: ok ? '训练星图已同步到备份时的状态' : '文件可能损坏或版本不兼容',
      error: !ok,
    );
  }
}

void _showPulsarNotice(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String detail,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      content: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 14, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: error
                ? const [Color(0xF02B1728), Color(0xF01A162B)]
                : const [Color(0xF0122941), Color(0xF00E1B35)],
          ),
          border: Border.all(
            color: error ? const Color(0x709F5476) : const Color(0x7050D9E9),
          ),
          boxShadow: [
            BoxShadow(
              color: error ? const Color(0x303F142A) : const Color(0x3032D6E8),
              blurRadius: 22,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: error
                    ? const Color(0x335F2944)
                    : const Color(0x3332BFD3),
              ),
              child: Icon(
                icon,
                size: 17,
                color: error
                    ? const Color(0xFFE6A4BD)
                    : const Color(0xFF8EF1F7),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF8FA2BD),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClearRecordsCard extends StatelessWidget {
  const _ClearRecordsCard({required this.controller});

  final PulsarController controller;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _confirm(context),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0x8A111D35), Color(0x7217253D)],
          ),
          border: Border.all(color: const Color(0x293B5979)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x332F8AA5),
                border: Border.all(color: const Color(0x3F64D4E8)),
              ),
              child: const Icon(
                Icons.auto_delete_outlined,
                size: 17,
                color: Color(0xFF88C9D7),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '重置能量轨迹',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '保留计划，仅清除进度与历史',
                    style: TextStyle(fontSize: 8, color: Color(0xFF7F91AC)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: Color(0xFF60738F),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirm(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置能量轨迹？'),
        content: const Text('训练计划会保留，所有完成进度与历史记录将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await controller.clearRecords();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final PulsarController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const PulsarHeader(title: '每周训练计划'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            ...widget.controller.plan.map(_dayTile),
            const SizedBox(height: 14),
            _EffectsSettingsCard(controller: widget.controller),
            const SizedBox(height: 10),
            _BackupSettingsCard(controller: widget.controller),
            const SizedBox(height: 10),
            _ClearRecordsCard(controller: widget.controller),
          ],
        ),
      ),
    ],
  );

  Widget _dayTile(WorkoutDay day) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: const Color(0xAA10182A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x202F4065)),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: LiquidOrb(
        size: 48,
        palette: PulsarPalette.values[day.palette],
        value: 0,
        total: 1,
        showValue: false,
        animate: false,
      ),
      title: Text(
        '${day.day} · ${day.title}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        day.rest ? '休息日' : '${day.exercises.length} 个训练动作',
        style: const TextStyle(fontSize: 8),
      ),
      children: [
        ...day.exercises.asMap().entries.map(
          (entry) => _exerciseEditor(day, entry.key, entry.value),
        ),
        if (day.exercises.isNotEmpty)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            onTap: () => _copyDay(day),
            leading: const Icon(Icons.copy_rounded, size: 16),
            title: const Text('复制本日计划到…', style: TextStyle(fontSize: 10)),
          ),
        ListTile(
          key: ValueKey('add-item-${day.keyName}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 22),
          onTap: () => _addActivity(day),
          leading: const Icon(Icons.add_circle_outline_rounded, size: 17),
          title: const Text('添加训练或成长事项', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _exerciseEditor(
    WorkoutDay day,
    int index,
    ExercisePlan exercise,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
    child: Column(
      children: [
        TextFormField(
          initialValue: exercise.name,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: '训练动作',
          ),
          onChanged: (value) {
            exercise.name = value;
            widget.controller.updatePlan();
          },
        ),
        Row(
          children: [
            SizedBox(
              width: 58,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '事项类型',
                initialValue: exercise.kind,
                onSelected: (value) {
                  setState(() => exercise.kind = value);
                  widget.controller.updatePlan();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'training', child: Text('训练')),
                  PopupMenuItem(value: 'reading', child: Text('阅读')),
                  PopupMenuItem(value: 'study', child: Text('学习')),
                  PopupMenuItem(value: 'ai', child: Text('AI 创造')),
                  PopupMenuItem(value: 'recovery', child: Text('恢复')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0x331B3153),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_activityIcon(exercise.kind), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _activityLabel(exercise.kind),
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: exercise.reps,
                style: const TextStyle(fontSize: 9, color: Color(0xFF8996A5)),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '次数或时长',
                ),
                onChanged: (value) {
                  exercise.reps = value;
                  widget.controller.updatePlan();
                },
              ),
            ),
            IconButton(
              tooltip: '上移',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              onPressed: index == 0
                  ? null
                  : () {
                      setState(() {
                        final item = day.exercises.removeAt(index);
                        day.exercises.insert(index - 1, item);
                      });
                      widget.controller.updatePlan();
                    },
              icon: const Icon(Icons.arrow_upward_rounded, size: 13),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              onPressed: () {
                if (exercise.sets > 1) setState(() => exercise.sets--);
                widget.controller.updatePlan();
              },
              icon: const Icon(Icons.remove, size: 14),
            ),
            Text('${exercise.sets} 组', style: const TextStyle(fontSize: 9)),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              onPressed: () {
                setState(() => exercise.sets++);
                widget.controller.updatePlan();
              },
              icon: const Icon(Icons.add, size: 14),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              onPressed: () {
                setState(() => day.exercises.removeAt(index));
                widget.controller.updatePlan();
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 15,
                color: Color(0xFFB26B8A),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: exercise.target,
                style: const TextStyle(fontSize: 9),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '目标或分类',
                ),
                onChanged: (value) {
                  exercise.target = value;
                  widget.controller.updatePlan();
                },
              ),
            ),
            if (exercise.kind == 'training')
              SizedBox(
                width: 84,
                child: TextFormField(
                  initialValue: exercise.weight == 0
                      ? ''
                      : '${exercise.weight}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '重量 kg',
                  ),
                  onChanged: (value) {
                    exercise.weight = double.tryParse(value) ?? 0;
                    widget.controller.updatePlan();
                  },
                ),
              ),
            if (exercise.kind == 'training')
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: '${exercise.restSeconds}',
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '休息秒',
                  ),
                  onChanged: (value) {
                    exercise.restSeconds = int.tryParse(value) ?? 0;
                    widget.controller.updatePlan();
                  },
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: exercise.note,
                style: const TextStyle(fontSize: 9),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '备注（可选）',
                ),
                onChanged: (value) {
                  exercise.note = value;
                  widget.controller.updatePlan();
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _addActivity(WorkoutDay day) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101B31),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ActivityChoice(
              kind: 'training',
              title: '训练事项',
              subtitle: '按组记录力量、有氧或恢复训练',
            ),
            _ActivityChoice(
              kind: 'reading',
              title: '阅读',
              subtitle: '书籍、论文或深度阅读',
            ),
            _ActivityChoice(kind: 'study', title: '学习', subtitle: '课程、复盘或技能练习'),
            _ActivityChoice(
              kind: 'ai',
              title: 'AI 创造',
              subtitle: '模型实验、编程与项目推进',
            ),
            _ActivityChoice(
              kind: 'recovery',
              title: '恢复事项',
              subtitle: '拉伸、冥想或主动恢复',
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final defaults = switch (kind) {
      'reading' => ('阅读 30 分钟', '知识输入', 1, '30 分钟'),
      'study' => ('深度学习', '技能成长', 2, '45 分钟'),
      'ai' => ('AI 项目推进', '创造与实验', 2, '45 分钟'),
      'recovery' => ('主动恢复', '身心恢复', 1, '20 分钟'),
      _ => ('新训练动作', '目标肌群', 3, '12 次'),
    };
    setState(() {
      day.rest = false;
      day.exercises.add(
        ExercisePlan(
          name: defaults.$1,
          target: defaults.$2,
          sets: defaults.$3,
          reps: defaults.$4,
          kind: kind,
          restSeconds: kind == 'training' ? 60 : 0,
        ),
      );
    });
    await widget.controller.updatePlan();
  }

  Future<void> _copyDay(WorkoutDay source) async {
    final target = await showModalBottomSheet<WorkoutDay>(
      context: context,
      backgroundColor: const Color(0xFF101B31),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.controller.plan
              .where((day) => day != source)
              .map(
                (day) => ListTile(
                  leading: Icon(
                    Icons.blur_circular_rounded,
                    color: PulsarPalette.values[day.palette].core,
                  ),
                  title: Text('${day.day} · ${day.title}'),
                  onTap: () => Navigator.of(context).pop(day),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      target
        ..title = source.title
        ..subtitle = source.subtitle
        ..rest = false
        ..exercises = source.exercises
            .map(
              (item) => ExercisePlan(
                name: item.name,
                target: item.target,
                sets: item.sets,
                reps: item.reps,
                kind: item.kind,
                weight: item.weight,
                note: item.note,
                restSeconds: item.restSeconds,
              ),
            )
            .toList();
    });
    await widget.controller.updatePlan();
  }
}

class _ActivityChoice extends StatelessWidget {
  const _ActivityChoice({
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final String kind;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('activity-choice-$kind'),
    leading: Icon(_activityIcon(kind), color: const Color(0xFF76E5F4)),
    title: Text(title),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
    onTap: () => Navigator.of(context).pop(kind),
  );
}

IconData _activityIcon(String kind) => switch (kind) {
  'reading' => Icons.menu_book_rounded,
  'study' => Icons.school_rounded,
  'ai' => Icons.memory_rounded,
  'recovery' => Icons.spa_rounded,
  _ => Icons.fitness_center_rounded,
};

String _activityLabel(String kind) => switch (kind) {
  'reading' => '阅读',
  'study' => '学习',
  'ai' => 'AI',
  'recovery' => '恢复',
  _ => '训练',
};
