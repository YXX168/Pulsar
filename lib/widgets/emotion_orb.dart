import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/emotion.dart';

/// 共享动画时钟，参考 Pulsar 的 PulsarMotion 设计。
///
/// 全局只有一个 AnimationController 驱动所有光球，
/// level 0 = 静止，1 = 慢速（16 秒），2 = 正常（11 秒）。
class EmotionMotion extends StatefulWidget {
  const EmotionMotion({
    required this.child,
    this.level = 2,
    super.key,
  });

  final Widget child;
  final int level;

  static Animation<double> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_EmotionMotionInherited>()
          ?.animation ??
      const AlwaysStoppedAnimation<double>(0.16);

  static int levelOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_EmotionMotionInherited>()
          ?.level ??
      2;

  @override
  State<EmotionMotion> createState() => _EmotionMotionState();
}

class _EmotionMotionState extends State<EmotionMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(EmotionMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) _syncMotion();
  }

  void _syncMotion() {
    if (widget.level == 0) {
      _controller.stop();
      _controller.value = .16;
    } else {
      _controller.duration =
          Duration(seconds: widget.level == 1 ? 16 : 11);
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EmotionMotionInherited(
        animation: _controller,
        level: widget.level,
        child: widget.child,
      );
}

class _EmotionMotionInherited extends InheritedWidget {
  const _EmotionMotionInherited({
    required this.animation,
    required this.level,
    required super.child,
  });

  final Animation<double> animation;
  final int level;

  @override
  bool updateShouldNotify(_EmotionMotionInherited oldWidget) =>
      level != oldWidget.level;
}

/// 液态情绪光球，参考 Pulsar 的 LiquidOrb 设计。
///
/// 一个柔和的光团而非玻璃球体，通过径向渐变绘制，
/// 两条细环独立轨道运行，进度环显示情绪强度。
class EmotionOrb extends StatefulWidget {
  const EmotionOrb({
    required this.palette,
    required this.intensity,
    this.size = 80,
    this.onTap,
    this.label,
    this.icon,
    this.hero = false,
    this.animate = true,
    this.entryDelay = Duration.zero,
    this.selected = false,
    super.key,
  });

  final EmotionPalette palette;
  final int intensity; // 1–5
  final double size;
  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final bool hero;
  final bool animate;
  final Duration entryDelay;
  final bool selected;

  @override
  State<EmotionOrb> createState() => _EmotionOrbState();
}

class _EmotionOrbState extends State<EmotionOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entry;
  Timer? _entryTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _entry = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    if (widget.entryDelay == Duration.zero) {
      _entryController.forward();
    } else {
      _entryTimer = Timer(widget.entryDelay, () {
        if (mounted) _entryController.forward();
      });
    }
  }

  @override
  void dispose() {
    _entryTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        ((widget.intensity - 1) / 4).clamp(0.0, 1.0);
    final motion = widget.animate
        ? EmotionMotion.of(context)
        : const AlwaysStoppedAnimation<double>(0.16);
    final quality = widget.animate ? EmotionMotion.levelOf(context) : 0;

    final visual = ScaleTransition(
      scale: _entry,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: EmotionLightPainter(
                  animation: motion,
                  palette: widget.palette,
                  progress: progress,
                  hero: widget.hero,
                  quality: quality,
                  selected: widget.selected,
                ),
              ),
            ),
            if (widget.icon != null)
              Icon(
                widget.icon,
                size: widget.size * .16,
                color:
                    Colors.white.withValues(alpha: .92),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label: widget.label != null
          ? '${widget.label}，强度 ${widget.intensity}'
          : '情绪光球，强度 ${widget.intensity}',
      child: widget.onTap == null
          ? visual
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: visual,
            ),
    );
  }
}

/// 柔和光团绘制器，参考 Pulsar 的 LightClusterPainter。
///
/// 绘制径向渐变光团、轨道环、能量螺旋和进度环。
class EmotionLightPainter extends CustomPainter {
  EmotionLightPainter({
    required this.animation,
    required this.palette,
    required this.progress,
    required this.hero,
    required this.quality,
    required this.selected,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final EmotionPalette palette;
  final double progress;
  final bool hero;
  final int quality;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final theta = phase * math.pi * 2;
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width * (hero ? .30 : .28);
    final breath = 1 + math.sin(theta) * .045;
    final clusterRadius = base * breath;
    final energy = .62 + progress * .38;

    // 外层辉光
    _drawSoftCircle(
      canvas,
      center,
      clusterRadius * 1.86,
      [
        palette.core.withValues(alpha: .12 + progress * .23),
        palette.edge.withValues(alpha: .08 + progress * .12),
        Colors.transparent,
      ],
      const [.0, .42, 1],
    );

    // 轨道环 1
    _drawOrbit(
      canvas,
      center,
      theta,
      width: clusterRadius * 3.35,
      height: clusterRadius * 1.42,
      tilt: -.22,
      alpha: .58,
      nodeRadius: 2.15,
    );

    // 轨道环 2
    _drawOrbit(
      canvas,
      center,
      -theta + 1.9,
      width: clusterRadius * 2.48,
      height: clusterRadius * 2.12,
      tilt: .68,
      alpha: .34,
      nodeRadius: 1.45,
    );

    // 高质量模式下额外轨道
    if (quality >= 2) {
      _drawOrbit(
        canvas,
        center,
        theta * 2 + 3.4,
        width: clusterRadius * 2.9,
        height: clusterRadius * .78,
        tilt: .24,
        alpha: .26,
        nodeRadius: 1.05,
      );
    }

    // 主光团
    _drawSoftCircle(
      canvas,
      center,
      clusterRadius * 1.12,
      [
        Colors.white.withValues(alpha: .68 + progress * .30),
        palette.core.withValues(alpha: .56 + progress * .32),
        palette.edge.withValues(alpha: .30 + progress * .28),
        palette.accent.withValues(alpha: .10 + progress * .12),
        Colors.transparent,
      ],
      const [0, .16, .48, .76, 1],
    );

    // 能量螺旋
    _drawEnergySpiral(canvas, center, clusterRadius, theta, energy);

    // 雾团 A
    final mistA = center +
        Offset(
          math.cos(theta) * clusterRadius * .31,
          math.sin(theta * 2) * clusterRadius * .22,
        );
    _drawSoftCircle(
      canvas,
      mistA,
      clusterRadius * .76,
      [
        palette.core.withValues(alpha: .36),
        palette.edge.withValues(alpha: .16),
        Colors.transparent,
      ],
      const [0, .48, 1],
    );

    // 雾团 B
    final mistB = center +
        Offset(
          math.sin(theta * 2 + 1.2) * clusterRadius * .28,
          math.cos(theta + .8) * clusterRadius * .24,
        );
    _drawSoftCircle(
      canvas,
      mistB,
      clusterRadius * .66,
      [
        palette.accent.withValues(alpha: .30),
        palette.accent.withValues(alpha: .10),
        Colors.transparent,
      ],
      const [0, .5, 1],
    );

    // 强度进度环
    final progressRect = Rect.fromCircle(
      center: center,
      radius: clusterRadius * 1.34,
    );
    canvas.drawArc(
      progressRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.35
        ..strokeCap = StrokeCap.round
        ..color =
            palette.core.withValues(alpha: selected ? .96 : .68),
    );

    // 选中状态外环
    if (selected) {
      final selRect = Rect.fromCircle(
        center: center,
        radius: clusterRadius * 1.6,
      );
      canvas.drawCircle(
        center,
        clusterRadius * 1.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = palette.core.withValues(alpha: .48),
      );
      canvas.drawArc(
        selRect,
        theta,
        math.pi * 1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round
          ..color = palette.edge.withValues(alpha: .3),
      );
    }
  }

  void _drawSoftCircle(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    List<double> stops,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: stops,
        ).createShader(
            Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double motion, {
    required double width,
    required double height,
    required double tilt,
    required double alpha,
    required double nodeRadius,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.drawOval(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..shader = SweepGradient(
          transform: GradientRotation(motion * .12),
          colors: [
            Colors.transparent,
            palette.edge.withValues(alpha: alpha),
            palette.accent.withValues(alpha: alpha * .7),
            Colors.transparent,
          ],
          stops: const [0, .26, .68, 1],
        ).createShader(bounds),
    );
    for (var segment = 0; segment < 3; segment++) {
      canvas.drawArc(
        bounds,
        motion + segment * 2.08,
        .28 + segment * .05,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = segment == 0 ? 1.9 : 1.05
          ..strokeCap = StrokeCap.round
          ..color = palette.core
              .withValues(alpha: alpha * (1 - segment * .2)),
      );
    }
    final node = Offset(
      math.cos(motion) * width / 2,
      math.sin(motion) * height / 2,
    );
    for (var trail = 3; trail >= 1; trail--) {
      final trailAngle = motion - trail * .045;
      canvas.drawCircle(
        Offset(
          math.cos(trailAngle) * width / 2,
          math.sin(trailAngle) * height / 2,
        ),
        nodeRadius * (.28 + (3 - trail) * .12),
        Paint()
          ..color = palette.edge
              .withValues(alpha: .10 + (3 - trail) * .08),
      );
    }
    canvas.drawCircle(
      node,
      nodeRadius,
      Paint()..color = palette.core.withValues(alpha: .98),
    );
    canvas.restore();
  }

  void _drawEnergySpiral(
    Canvas canvas,
    Offset center,
    double radius,
    double theta,
    double energy,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final streamCount = quality >= 2
        ? 6
        : quality == 1
            ? 4
            : 3;
    for (var stream = 0; stream < streamCount; stream++) {
      final streamRadius = radius * (.30 + stream * .105);
      final bounds =
          Rect.fromCircle(center: Offset.zero, radius: streamRadius);
      final direction = stream.isEven ? 1.0 : -1.0;
      canvas.drawArc(
        bounds,
        theta * direction + stream * 1.07,
        .82 + stream * .105,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.1 - stream * .14
          ..color = Color.lerp(
            palette.core,
            palette.accent,
            stream / 7,
          )!.withValues(alpha: (.72 - stream * .065) * energy),
      );
    }
    final needle =
        Rect.fromCircle(center: Offset.zero, radius: radius * .92);
    canvas.drawArc(
      needle,
      -theta * 2,
      .48,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .76 * energy),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(EmotionLightPainter oldDelegate) =>
      palette != oldDelegate.palette ||
      progress != oldDelegate.progress ||
      hero != oldDelegate.hero ||
      quality != oldDelegate.quality ||
      selected != oldDelegate.selected;
}
