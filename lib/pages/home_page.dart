import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../models/emotion_entry.dart';
import '../services/storage.dart';
import '../widgets/emotion_orb.dart';
import '../widgets/galaxy_scene.dart';
import 'record_page.dart';

/// 首页：星海背景 + 今日情绪光球 + 快速记录入口。
class HomePage extends StatefulWidget {
  const HomePage({
    required this.storage,
    this.effectsLevel = 2,
    super.key,
  });

  final EmotionStorage storage;
  final int effectsLevel;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<EmotionEntry> _todayEntries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayEntries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTodayEntries();
  }

  Future<void> _loadTodayEntries() async {
    final entries = await widget.storage.loadEntriesForDate(DateTime.now());
    if (mounted) {
      setState(() {
        _todayEntries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final animation = EmotionMotion.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 星海背景
          Positioned.fill(
            child: GalaxyScene(animation: animation),
          ),
          // 内容
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF49BCEB),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTodayEntries,
                    color: const Color(0xFF49BCEB),
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          title: const Text('情绪星海'),
                          floating: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        SliverToBoxAdapter(
                          child: _buildHeader(),
                        ),
                        SliverToBoxAdapter(
                          child: _buildTodayEntries(),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
          ),
          // 浮动记录按钮
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RecordPage(storage: widget.storage),
                  ),
                );
                _loadTodayEntries();
              },
              backgroundColor: const Color(0xFF49BCEB),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 6) {
      greeting = '深夜了，还好吗？';
    } else if (hour < 12) {
      greeting = '早安，新的一天';
    } else if (hour < 18) {
      greeting = '午后时光';
    } else {
      greeting = '晚上好';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '今天记录了 ${_todayEntries.length} 次情绪',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayEntries() {
    if (_todayEntries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_outline_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: .2),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有记录今天的情绪',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮开始记录',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .25),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 20,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: _todayEntries.asMap().entries.map((entry) {
          final e = entry.value;
          final type = e.type;
          if (type == null) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmotionOrb(
                palette: type.palette,
                intensity: e.intensity,
                size: 72,
                icon: type.icon,
                entryDelay: Duration(milliseconds: entry.key * 60),
              ),
              const SizedBox(height: 6),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 11,
                  color: type.palette.core,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatTime(e.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: .35),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
