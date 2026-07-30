import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../services/haptics.dart';
import 'emotion_orb.dart';

/// 情绪选择器，展示 9 种情绪类型的光球网格。
///
/// 点击光球选择对应情绪类型，选中状态会高亮显示。
class EmotionPicker extends StatelessWidget {
  const EmotionPicker({
    this.selected,
    this.onSelected,
    this.orbSize = 72,
    super.key,
  });

  final EmotionType? selected;
  final ValueChanged<EmotionType>? onSelected;
  final double orbSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '此刻的感受',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: .9),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: EmotionType.values.map((type) {
            final isSelected = type == selected;
            return AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmotionOrb(
                    palette: type.palette,
                    intensity: selected == null ? 3 : (isSelected ? 5 : 1),
                    size: orbSize,
                    icon: type.icon,
                    selected: isSelected,
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(type),
                    entryDelay: Duration(
                      milliseconds:
                          EmotionType.values.indexOf(type) * 50,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 12 : 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? type.palette.core
                          : Colors.white.withValues(alpha: .6),
                    ),
                    child: Text(type.label),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 强度选择器，5 个等级横排，选中等级高亮。
class IntensitySelector extends StatelessWidget {
  const IntensitySelector({
    required this.value,
    this.onChanged,
    this.palette,
    super.key,
  });

  final int value; // 1–5
  final ValueChanged<int>? onChanged;
  final EmotionPalette? palette;

  @override
  Widget build(BuildContext context) {
    final activePalette = palette ?? _fallbackPalette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '情绪强度',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: .9),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: IntensityLevel.values.map((level) {
            final isActive = level.value <= value;
            final isCurrent = level.value == value;
            return GestureDetector(
              onTap: onChanged == null
                  ? null
                  : () {
                      Haptics.tap();
                      onChanged!(level.value);
                    },
              child: AnimatedScale(
                scale: isCurrent ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? RadialGradient(
                          colors: [
                            activePalette.core
                                .withValues(alpha: .8),
                            activePalette.edge
                                .withValues(alpha: .4),
                            Colors.transparent,
                          ],
                          stops: const [0, .5, 1],
                        )
                      : null,
                  border: Border.all(
                    color: isActive
                        ? activePalette.core.withValues(alpha: .8)
                        : Colors.white.withValues(alpha: .15),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${level.value}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: .4),
                    ),
                  ),
                ),
              ), // AnimatedContainer
              ), // AnimatedScale
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          IntensityLevel.values
              .firstWhere((l) => l.value == value,
                  orElse: () => const IntensityLevel(3, '适中'))
              .label,
          style: TextStyle(
            fontSize: 13,
            color: activePalette.core.withValues(alpha: .9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 用于回退的默认调色板。
const _fallbackPalette = EmotionPalette(
  Color(0xFFB8F8FF),
  Color(0xFF49BCEB),
  Color(0xFF7776E8),
);
