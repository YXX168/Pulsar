import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/workout.dart';
import 'models/training_event.dart';
import 'services/storage.dart';
import 'widgets/liquid_orb.dart';
import 'widgets/galaxy_scene.dart';

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
  Widget build(BuildContext context) => PulsarMotion(
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
  Map<String, Map<int, int>> completed = {};
  List<TrainingEvent> events = [];

  Future<void> initialize() async {
    plan = await storage.loadPlan();
    completed = await storage.loadSets();
    events = await storage.loadEvents();
    ready = true;
    notifyListeners();
  }

  int count(WorkoutDay day, int index) => completed[day.keyName]?[index] ?? 0;

  int totalSets(WorkoutDay day) =>
      day.exercises.fold(0, (total, exercise) => total + exercise.sets);

  int doneSets(WorkoutDay day) => day.exercises.asMap().entries.fold(
    0,
    (total, entry) => total + count(day, entry.key).clamp(0, entry.value.sets),
  );

  double progress(WorkoutDay day) {
    if (day.rest) return 0;
    final total = totalSets(day);
    return total == 0 ? 0 : doneSets(day) / total;
  }

  Future<void> setCount(
    WorkoutDay day,
    int index,
    int value, {
    bool recordSet = false,
  }) async {
    completed.putIfAbsent(day.keyName, () => {});
    completed[day.keyName]![index] = value;
    if (recordSet && index >= 0 && index < day.exercises.length) {
      events.insert(
        0,
        TrainingEvent(
          timestamp: DateTime.now(),
          dayKey: day.keyName,
          dayLabel: day.day,
          workoutTitle: day.title,
          exerciseName: day.exercises[index].name,
        ),
      );
    }
    notifyListeners();
    await storage.saveSets(completed);
    if (recordSet) await storage.saveEvents(events);
  }

  int setsOnDate(DateTime date) => events.where((event) {
    final time = event.timestamp;
    return time.year == date.year &&
        time.month == date.month &&
        time.day == date.day;
  }).length;

  int get activeDays => events.map((event) => event.dateKey).toSet().length;

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
      return DailyTrainingSummary(
        date: DateTime(
          first.timestamp.year,
          first.timestamp.month,
          first.timestamp.day,
        ),
        dayKey: first.dayKey,
        dayLabel: first.dayLabel,
        workoutTitle: first.workoutTitle,
        sets: items.length,
        exerciseCount: items.map((event) => event.exerciseName).toSet().length,
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

  Future<void> clearRecords() async {
    completed = {};
    events = [];
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
      GalaxyScreen(controller: widget.controller),
      RecordsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];
    return Scaffold(
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
            label: '星系',
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
  const PulsarHeader({super.key, this.title, this.progress, this.onBack});

  final String? title;
  final double? progress;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 78,
    child: Padding(
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
          if (progress != null)
            SizedBox(
              width: 82,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress! * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8C3D8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: const Color(0x192A3854),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF00DBFF),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (onBack != null)
            const SizedBox(width: 48)
          else
            const Spacer(),
        ],
      ),
    ),
  );
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

  @override
  void initState() {
    super.initState();
    _fissionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
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
      const PulsarHeader(),
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
    final activeDays = widget.controller.plan.where((day) => !day.rest);
    final total = activeDays.fold<int>(
      0,
      (sum, day) => sum + widget.controller.totalSets(day),
    );
    final done = activeDays.fold<int>(
      0,
      (sum, day) => sum + widget.controller.doneSets(day),
    );
    final progress = total == 0 ? 0.0 : done / total;
    final orbSize = math.min(size.width * .72, 278.0);
    return AnimatedBuilder(
      animation: _fissionController,
      builder: (context, child) {
        final t = Curves.easeInCubic.transform(_fissionController.value);
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

  void _expandGalaxy() {
    if (expanded) return;
    setState(() => expanded = true);
    _fissionController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

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
      final isToday = index == todayIndex;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidOrb(
                    key: ValueKey('day-${day.keyName}'),
                    size: orbSize,
                    palette: PulsarPalette.values[day.palette],
                    value: (widget.controller.progress(day) * 100).round(),
                    total: 100,
                    showValue: !day.rest,
                    complete: !day.rest && widget.controller.progress(day) >= 1,
                    hero: isToday,
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
                    day.title,
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
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 300),
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
      final x = math.cos(angle * .72) * amplitude;
      final y = math.sin(angle) * amplitude * .74;
      final scale = 1 + math.sin(angle * .83) * .018;
      return Transform.translate(
        offset: Offset(x, y),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
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
    with SingleTickerProviderStateMixin {
  final Map<int, bool> armed = {};
  late final AnimationController _breakController;

  @override
  void initState() {
    super.initState();
    _breakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();
  }

  @override
  void dispose() {
    _breakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PulsarBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              PulsarHeader(
                title: '${day.day} · ${day.title}',
                progress: widget.controller.progress(day),
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: day.rest
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              color: Color(0xFF8390B3),
                              size: 32,
                            ),
                            SizedBox(height: 14),
                            Text(
                              '今天休息',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '让身体完成恢复与生长',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF78859D),
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) => Stack(
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
                                    color:
                                        PulsarPalette.values[day.palette].core,
                                  ),
                                ),
                              ),
                            ),
                            ..._exerciseNodes(box.biggest),
                          ],
                        ),
                      ),
              ),
            ],
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
    const sizes = [130.0, 114.0, 122.0, 110.0, 118.0, 108.0];
    return day.exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      final alignment = alignments[index % alignments.length];
      final orbSize = sizes[index % sizes.length];
      final left = (alignment.x + 1) / 2 * size.width - 66;
      final rawTop = (alignment.y + 1) / 2 * size.height - orbSize / 2;
      final top = rawTop.clamp(2.0, size.height - orbSize - 40.0);
      final launch = widget.launchOrigin.alongSize(size);
      final target = Offset(left + 66, top + orbSize / 2);
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
            child: SizedBox(
              width: 132,
              child: Column(
                children: [
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
    if (next >= exercise.sets) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    if (mounted) setState(() {});
  }
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
        transform: GradientRotation(theta * .12),
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
    canvas.rotate(-.18 + math.sin(theta * .31) * .035);
    final orbit = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .92,
      height: size.height * .34,
    );
    canvas.drawArc(
      orbit,
      theta * .18,
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
      final y = (baseY + math.sin(theta * .44 + index) * 5) % size.height;
      final pulse = (math.sin(theta * .73 + index * 1.9) + 1) * .5;
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
      final progress =
          (animation.value * (.55 + comet * .11) + comet * .29) % 1;
      final point = Offset(
        size.width * (.08 + progress * .84),
        size.height * (.2 + comet * .29 + math.sin(theta * .6 + comet) * .055),
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
                  const SizedBox(width: 9),
                  _Metric(value: '${controller.currentStreak}', label: '连续天数'),
                ],
              ),
              const SizedBox(height: 16),
              _EnergyTrend(controller: controller),
              const SizedBox(height: 14),
              _HeatField(controller: controller),
              const SizedBox(height: 24),
              const Text(
                '最近训练',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (summaries.isEmpty)
                const _EmptyHistory()
              else
                ...summaries
                    .take(12)
                    .map(
                      (summary) => _HistoryCard(
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.summary, required this.palette});

  final DailyTrainingSummary summary;
  final PulsarPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.fromLTRB(8, 8, 15, 8),
    decoration: BoxDecoration(
      color: const Color(0x92101827),
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
                '${summary.date.month}月${summary.date.day}日 · ${summary.exerciseCount} 个动作',
                style: const TextStyle(fontSize: 8, color: Color(0xFF7E8BA1)),
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
      ],
    ),
  );
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
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0x202C3B5E)),
              ),
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('清空训练记录', style: TextStyle(fontSize: 12)),
              subtitle: const Text(
                '保留训练计划，只清除完成次数',
                style: TextStyle(fontSize: 9),
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.controller.clearRecords();
              },
            ),
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
        if (!day.rest)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            onTap: () {
              setState(
                () => day.exercises.add(
                  ExercisePlan(
                    name: '新训练动作',
                    target: '目标肌群',
                    sets: 3,
                    reps: '12 次',
                  ),
                ),
              );
              widget.controller.updatePlan();
            },
            leading: const Icon(Icons.add_circle_outline_rounded, size: 17),
            title: const Text('添加训练动作', style: TextStyle(fontSize: 10)),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _exerciseEditor(WorkoutDay day, int index, ExercisePlan exercise) =>
      Padding(
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
                  width: 110,
                  child: TextFormField(
                    initialValue: exercise.reps,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8996A5),
                    ),
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
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (exercise.sets > 1) setState(() => exercise.sets--);
                    widget.controller.updatePlan();
                  },
                  icon: const Icon(Icons.remove, size: 14),
                ),
                Text('${exercise.sets} 组', style: const TextStyle(fontSize: 9)),
                IconButton(
                  onPressed: () {
                    setState(() => exercise.sets++);
                    widget.controller.updatePlan();
                  },
                  icon: const Icon(Icons.add, size: 14),
                ),
                IconButton(
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
          ],
        ),
      );
}
