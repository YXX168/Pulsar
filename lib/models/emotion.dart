import 'package:flutter/material.dart';

/// 调色板：核心色 / 边缘色 / 强调色，参考 Pulsar 的 PulsarPalette 设计。
class EmotionPalette {
  const EmotionPalette(this.core, this.edge, this.accent);

  final Color core;
  final Color edge;
  final Color accent;

  /// 在深色背景上用于绘制光团辉光的柔和版本。
  Color get glow => edge.withValues(alpha: 0.18);

  /// 在列表 / 卡片中用于填充的半透明版本。
  Color get fill => core.withValues(alpha: 0.12);
}

/// 情绪类型枚举，每种类型绑定唯一的 id、中文名、图标和调色板。
enum EmotionType {
  joy(
    id: 'joy',
    label: '喜悦',
    icon: Icons.wb_sunny_rounded,
    palette: EmotionPalette(
      Color(0xFFFFE9A8),
      Color(0xFFF5B544),
      Color(0xFFE89B3C),
    ),
  ),
  calm(
    id: 'calm',
    label: '平静',
    icon: Icons.water_drop_rounded,
    palette: EmotionPalette(
      Color(0xFFB8F8FF),
      Color(0xFF49BCEB),
      Color(0xFF7776E8),
    ),
  ),
  love(
    id: 'love',
    label: '爱意',
    icon: Icons.favorite_rounded,
    palette: EmotionPalette(
      Color(0xFFF3C7E8),
      Color(0xFFC178B2),
      Color(0xFFE8559A),
    ),
  ),
  gratitude(
    id: 'gratitude',
    label: '感恩',
    icon: Icons.volunteer_activism_rounded,
    palette: EmotionPalette(
      Color(0xFFB4F5E2),
      Color(0xFF52BEAE),
      Color(0xFF3FAE7E),
    ),
  ),
  excitement(
    id: 'excitement',
    label: '兴奋',
    icon: Icons.bolt_rounded,
    palette: EmotionPalette(
      Color(0xFFFFE1B7),
      Color(0xFFD7A165),
      Color(0xFFFF8F47),
    ),
  ),
  sadness(
    id: 'sadness',
    label: '低落',
    icon: Icons.cloud_rounded,
    palette: EmotionPalette(
      Color(0xFFD8E1F6),
      Color(0xFF8595BB),
      Color(0xFF6B7FAB),
    ),
  ),
  anxiety(
    id: 'anxiety',
    label: '焦虑',
    icon: Icons.psychology_rounded,
    palette: EmotionPalette(
      Color(0xFFC7D4FF),
      Color(0xFF6A8DE8),
      Color(0xFFA578E5),
    ),
  ),
  anger(
    id: 'anger',
    label: '愤怒',
    icon: Icons.local_fire_department_rounded,
    palette: EmotionPalette(
      Color(0xFFFFC2B0),
      Color(0xFFE85D4A),
      Color(0xFFD63B2E),
    ),
  ),
  fatigue(
    id: 'fatigue',
    label: '疲惫',
    icon: Icons.nights_stay_rounded,
    palette: EmotionPalette(
      Color(0xFFD4D0E8),
      Color(0xFF8C79C9),
      Color(0xFF6A5F9E),
    ),
  );

  const EmotionType({
    required this.id,
    required this.label,
    required this.icon,
    required this.palette,
  });

  final String id;
  final String label;
  final IconData icon;
  final EmotionPalette palette;

  /// 根据 id 字符串查找枚举值，找不到时返回 null。
  static EmotionType? fromId(String id) {
    for (final type in EmotionType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// 情绪强度等级 1–5，附带简短中文描述。
class IntensityLevel {
  const IntensityLevel(this.value, this.label);

  final int value;
  final String label;

  static const values = [
    IntensityLevel(1, '微弱'),
    IntensityLevel(2, '轻微'),
    IntensityLevel(3, '适中'),
    IntensityLevel(4, '强烈'),
    IntensityLevel(5, '极强'),
  ];

  /// 将 1–5 映射到 0.0–1.0 的进度值，用于光球进度环。
  double get progress => (value - 1) / 4;
}
