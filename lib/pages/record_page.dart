import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../models/emotion_entry.dart';
import '../services/storage.dart';
import '../widgets/emotion_orb.dart';
import '../widgets/emotion_picker.dart';

/// 记录页：选择情绪类型、强度、备注，保存情绪记录。
class RecordPage extends StatefulWidget {
  const RecordPage({
    required this.storage,
    this.editEntry,
    super.key,
  });

  final EmotionStorage storage;
  final EmotionEntry? editEntry;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  EmotionType? _selected;
  int _intensity = 3;
  final _noteController = TextEditingController();
  final List<String> _tags = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editEntry != null) {
      final e = widget.editEntry!;
      _selected = EmotionType.fromId(e.emotionId);
      _intensity = e.intensity;
      _noteController.text = e.note;
      _tags.addAll(e.tags);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一种情绪'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    if (widget.editEntry != null) {
      final updated = widget.editEntry!.copyWith(
        emotionId: _selected!.id,
        intensity: _intensity,
        note: _noteController.text.trim(),
        tags: List.of(_tags),
      );
      await widget.storage.updateEntry(updated);
    } else {
      final entry = EmotionEntry(
        emotionId: _selected!.id,
        intensity: _intensity,
        timestamp: DateTime.now(),
        note: _noteController.text.trim(),
        tags: List.of(_tags),
      );
      await widget.storage.addEntry(entry);
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editEntry != null ? '编辑情绪' : '记录情绪'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xFF49BCEB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 选中情绪预览
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selected != null
                  ? Column(
                      key: ValueKey(_selected),
                      children: [
                        EmotionOrb(
                          palette: _selected!.palette,
                          intensity: _intensity,
                          size: 120,
                          icon: _selected!.icon,
                          hero: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selected!.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _selected!.palette.core,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      key: const ValueKey('placeholder'),
                      height: 150,
                      child: Center(
                        child: Text(
                          '选择一种情绪开始',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .3),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),

            // 情绪选择器
            EmotionPicker(
              selected: _selected,
              onSelected: (type) => setState(() => _selected = type),
              orbSize: 64,
            ),
            const SizedBox(height: 40),

            // 强度选择器
            IntensitySelector(
              value: _intensity,
              palette: _selected?.palette,
              onChanged: (v) => setState(() => _intensity = v),
            ),
            const SizedBox(height: 40),

            // 备注输入
            _buildNoteField(),
            const SizedBox(height: 24),

            // 标签
            _buildTagsSection(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '心情笔记',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .8),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 4,
          maxLength: 200,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: '写下此刻的想法……',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: .25)),
            filled: true,
            fillColor: const Color(0xFF111729),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF49BCEB),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    const presetTags = ['工作', '生活', '社交', '健康', '睡眠', '天气', '家庭', '学习'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .8),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presetTags.map((tag) {
            final isSelected = _tags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _tags.remove(tag);
                  } else {
                    _tags.add(tag);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? const Color(0xFF49BCEB).withValues(alpha: .2)
                      : const Color(0xFF111729),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF49BCEB)
                        : Colors.white.withValues(alpha: .1),
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? const Color(0xFF49BCEB)
                        : Colors.white.withValues(alpha: .5),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
