import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/emotion.dart';
import '../models/emotion_entry.dart';
import '../services/storage.dart';
import '../widgets/emotion_orb.dart';

/// 统计页：情绪分布、连续天数、平均强度、活跃热力图、备份恢复。
class StatsPage extends StatefulWidget {
  const StatsPage({required this.storage, super.key});

  final EmotionStorage storage;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  EmotionStats? _stats;
  List<DailySummary> _heatmap = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await widget.storage.loadStats(days: 30);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 83));
    final entries = await widget.storage.loadEntriesInRange(start: start);

    final grouped = <String, List<EmotionEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.dateKey, () => []).add(e);
    }
    final heatmap = grouped.entries
        .map((e) => DailySummary(dateKey: e.key, entries: e.value))
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    if (mounted) {
      setState(() {
        _stats = stats;
        _heatmap = heatmap;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情绪统计')),
      body: _loading || _stats == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF49BCEB)))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF49BCEB),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildDistributionChart(),
                  const SizedBox(height: 24),
                  _buildHeatmap(),
                  const SizedBox(height: 24),
                  _buildBackupSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final stats = _stats!;
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.insights_rounded,
          label: '总记录',
          value: '${stats.totalEntries}',
          color: const Color(0xFF49BCEB),
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.local_fire_department_rounded,
          label: '连续天数',
          value: '${stats.currentStreak}',
          color: const Color(0xFFF5B544),
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.calendar_today_rounded,
          label: '活跃天数',
          value: '${stats.activeDays}',
          color: const Color(0xFF52BEAE),
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.trending_up_rounded,
          label: '平均强度',
          value: stats.averageIntensity.toStringAsFixed(1),
          color: const Color(0xFFA578E5),
        )),
      ],
    );
  }

  Widget _buildDistributionChart() {
    final stats = _stats!;
    if (stats.distribution.isEmpty) {
      return _buildEmptySection('暂无情绪数据');
    }

    final maxCount = stats.distribution.values
        .fold<int>(0, (max, v) => v > max ? v : max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111729),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '情绪分布 · 近30天',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ...stats.distribution.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))
            .map((e) {
              final type = e.key;
              final count = e.value;
              final ratio = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(type.icon, size: 16, color: type.palette.core),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: const Color(0xFF1A2238),
                          valueColor:
                              AlwaysStoppedAnimation(type.palette.edge),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: type.palette.core,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (stats.topEmotion != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF1A2238)),
            const SizedBox(height: 12),
            Row(
              children: [
                EmotionOrb(
                  palette: stats.topEmotion!.palette,
                  intensity: 4,
                  size: 40,
                  icon: stats.topEmotion!.icon,
                  animate: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '最近最常出现的情绪是「${stats.topEmotion!.label}」',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeatmap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111729),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '活跃热力 · 近12周',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeks = 12;
    final startDate = today.subtract(Duration(days: weeks * 7 - 1));

    // 计算每天的主要情绪颜色
    String dateKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final entryMap = <String, DailySummary>{};
    for (final s in _heatmap) {
      entryMap[s.dateKey] = s;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var row = 0; row < 7; row++)
            Row(
              children: [
                for (var col = 0; col < weeks; col++)
                  _buildHeatmapCell(
                    startDate.add(Duration(days: col * 7 + row)),
                    entryMap,
                    dateKey,
                    today,
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '少',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .3)),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF1A2238),
                      const Color(0xFF49BCEB),
                      (i + 1) / 5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '多',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .3)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCell(
    DateTime date,
    Map<String, DailySummary> entryMap,
    String Function(DateTime) dateKeyFn,
    DateTime today,
  ) {
    final key = dateKeyFn(date);
    final summary = entryMap[key];
    final isFuture = date.isAfter(today);

    Color color = const Color(0xFF1A2238);
    if (isFuture) {
      color = Colors.transparent;
    } else if (summary != null && summary.entries.isNotEmpty) {
      final dominant = summary.dominantEmotion;
      if (dominant != null) {
        final intensity = (summary.averageIntensity / 5).clamp(0.2, 1.0);
        color = dominant.palette.edge.withValues(alpha: 0.3 + intensity * 0.6);
      }
    }

    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildBackupSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111729),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据备份',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据保存在本地，卸载前请导出备份。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BackupButton(
                  icon: Icons.upload_rounded,
                  label: '导出备份',
                  onTap: _exportBackup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BackupButton(
                  icon: Icons.download_rounded,
                  label: '恢复备份',
                  onTap: _restoreBackup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) return;
      final path = await widget.storage.exportBackup(dir);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份已导出：$path'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('导出失败：$e');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final count = await widget.storage.restoreBackup(result.files.single.path!);
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已恢复 $count 条记录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('恢复失败：$e');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.withValues(alpha: .3),
        ),
      );
    }
  }

  Widget _buildEmptySection(String text) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF111729),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withValues(alpha: .3)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111729),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: .4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  const _BackupButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2238),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF49BCEB)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF49BCEB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
