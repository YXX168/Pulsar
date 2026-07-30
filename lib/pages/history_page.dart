import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../models/emotion_entry.dart';
import '../services/storage.dart';
import '../widgets/emotion_orb.dart';
import 'record_page.dart';

/// 历史页：月历视图 + 选中日期的情绪记录列表。
class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.storage, super.key});

  final EmotionStorage storage;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  Map<String, List<EmotionEntry>> _monthEntries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final summaries =
        await widget.storage.loadDailySummaries(_focusedMonth.year, _focusedMonth.month);
    final map = <String, List<EmotionEntry>>{};
    for (final s in summaries) {
      map[s.dateKey] = s.entries;
    }
    if (mounted) {
      setState(() {
        _monthEntries = map;
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
    _loadMonth();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final selectedEntries = _selectedDate != null
        ? _monthEntries[_dateKey(_selectedDate!)] ?? <EmotionEntry>[]
        : <EmotionEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text('情绪历史')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF49BCEB)))
          : Column(
              children: [
                _buildMonthHeader(),
                _buildCalendar(),
                const Divider(height: 1, color: Color(0xFF1A2238)),
                Expanded(child: _buildDayDetail(selectedEntries)),
              ],
            ),
    );
  }

  Widget _buildMonthHeader() {
    const monthNames = [
      '', '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${_focusedMonth.year}年 ${monthNames[_focusedMonth.month]}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstOfMonth.weekday % 7; // 周日 = 0
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final today = DateTime.now();
    const weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: weekLabels.map((w) {
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .4),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final day = index - firstWeekday + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final key = _dateKey(date);
              final entries = _monthEntries[key] ?? [];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selectedDate != null &&
                  date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;

              // 主要情绪颜色
              Color? dotColor;
              if (entries.isNotEmpty) {
                final counts = <String, int>{};
                for (final e in entries) {
                  counts[e.emotionId] = (counts[e.emotionId] ?? 0) + 1;
                }
                counts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final type = EmotionType.fromId(counts.entries.first.key);
                dotColor = type?.palette.core;
              }

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF49BCEB).withValues(alpha: .15)
                        : null,
                    border: isToday
                        ? Border.all(color: const Color(0xFF49BCEB), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? const Color(0xFF49BCEB)
                              : Colors.white.withValues(alpha: .7),
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (dotColor != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                      ] else if (entries.isEmpty)
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetail(List<EmotionEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: .15),
            ),
            const SizedBox(height: 12),
            Text(
              '这一天没有情绪记录',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        final type = e.type;
        if (type == null) return const SizedBox.shrink();

        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
          onDismissed: (_) async {
            await widget.storage.deleteEntry(e.id);
            _loadMonth();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除 ${type.label} 记录'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: _EntryCard(
            entry: e,
            type: type,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RecordPage(storage: widget.storage, editEntry: e),
                ),
              );
              _loadMonth();
            },
          ),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.type,
    this.onTap,
  });

  final EmotionEntry entry;
  final EmotionType type;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final h = entry.timestamp.hour.toString().padLeft(2, '0');
    final m = entry.timestamp.minute.toString().padLeft(2, '0');

    return Card(
      color: const Color(0xFF111729),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: EmotionOrb(
          palette: type.palette,
          intensity: entry.intensity,
          size: 48,
          icon: type.icon,
          animate: false,
        ),
        title: Row(
          children: [
            Text(
              type.label,
              style: TextStyle(
                color: type.palette.core,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '强度 ${entry.intensity}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: .4),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: .55),
                ),
              ),
            ],
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: entry.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: type.palette.fill,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: type.palette.core,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '$h:$m',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: .3),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: .2),
          size: 20,
        ),
      ),
    );
  }
}
