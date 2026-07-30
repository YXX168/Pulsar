import 'package:flutter/material.dart';

import 'services/haptics.dart';
import 'services/storage.dart';
import 'widgets/emotion_orb.dart';
import 'pages/home_page.dart';
import 'pages/record_page.dart';
import 'pages/history_page.dart';
import 'pages/stats_page.dart';

/// 情绪星海应用入口。
///
/// 参考 Pulsar 的设计：深空背景、Material 3 暗色主题、
/// 底部导航切换四个主页面，全局共享动画时钟。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmotionGalaxyApp());
}

class EmotionGalaxyApp extends StatelessWidget {
  const EmotionGalaxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '情绪星海',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF49BCEB),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0E1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111729),
          selectedItemColor: Color(0xFF49BCEB),
          unselectedItemColor: Color(0xFF5A6B8C),
          type: BottomNavigationBarType.fixed,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white54),
        ),
      ),
      home: const EmotionGalaxyShell(),
    );
  }
}

/// 主框架，管理底部导航和页面切换。
class EmotionGalaxyShell extends StatefulWidget {
  const EmotionGalaxyShell({super.key});

  @override
  State<EmotionGalaxyShell> createState() => _EmotionGalaxyShellState();
}

class _EmotionGalaxyShellState extends State<EmotionGalaxyShell> {
  final EmotionStorage _storage = EmotionStorage();
  final ValueNotifier<int> _refreshSignal = ValueNotifier(0);
  int _currentIndex = 0;
  int _effectsLevel = 2;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadEffectsLevel();
    _pages = [
      HomePage(
        storage: _storage,
        effectsLevel: _effectsLevel,
        refreshSignal: _refreshSignal,
      ),
      RecordPage(
        storage: _storage,
        popOnSave: false,
        onSaved: () {
          _refreshSignal.value++;
          setState(() => _currentIndex = 0);
        },
      ),
      HistoryPage(storage: _storage, refreshSignal: _refreshSignal),
      StatsPage(storage: _storage, refreshSignal: _refreshSignal),
    ];
  }

  @override
  void dispose() {
    _refreshSignal.dispose();
    super.dispose();
  }

  Future<void> _loadEffectsLevel() async {
    final level = await _storage.loadEffectsLevel();
    if (mounted && level != _effectsLevel) {
      setState(() => _effectsLevel = level);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmotionMotion(
      level: _effectsLevel,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index != _currentIndex) {
              Haptics.selection();
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: '星海',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_rounded),
              label: '记录',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded),
              label: '历史',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded),
              label: '统计',
            ),
          ],
        ),
      ),
    );
  }
}
