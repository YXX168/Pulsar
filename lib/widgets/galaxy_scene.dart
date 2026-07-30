import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 情绪星海背景绘制器，参考 Pulsar 的 GalaxyScenePainter 设计。
///
/// 绘制旋转的星系环、闪烁的星点和移动的彗星，营造深空氛围。
class GalaxyScenePainter extends CustomPainter {
  GalaxyScenePainter({
    required this.animation,
    this.accentColor = const Color(0xFF57B5FF),
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final theta = phase * math.pi * 2;
    final center = Offset(size.width * .5, size.height * .49);

    // ── 星云层（远景深度） ─────────────────────────────
    for (var nebula = 0; nebula < 3; nebula++) {
      final nebCenter = Offset(
        size.width * (.2 + nebula * .3 + math.sin(theta * .3 + nebula * 2) * .03),
        size.height * (.15 + nebula * .25 + math.cos(theta * .2 + nebula) * .02),
      );
      final nebRadius = size.width * (.18 + nebula * .06);
      final nebColors = [
        [const Color(0xFF1A2B5C), const Color(0xFF0A0E1A)],   // 深蓝
        [const Color(0xFF2A1B4C), const Color(0xFF0A0E1A)],   // 深紫
        [const Color(0xFF1B3A4C), const Color(0xFF0A0E1A)],   // 深青
      ][nebula];
      canvas.drawCircle(
        nebCenter,
        nebRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              nebColors[0].withValues(alpha: .15),
              nebColors[1].withValues(alpha: .05),
              Colors.transparent,
            ],
            stops: const [0, .5, 1],
          ).createShader(Rect.fromCircle(center: nebCenter, radius: nebRadius)),
      );
    }

    // ── 星系环 ──────────────────────────────────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.28 + math.sin(theta) * .018);

    final galaxyRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 1.22,
      height: size.height * .55,
    );
    canvas.drawOval(
      galaxyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(
          transform: GradientRotation(theta),
          colors: [
            Colors.transparent,
            accentColor.withValues(alpha: 0.25),
            Color.lerp(accentColor, Colors.purple, 0.3)!
                .withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(galaxyRect),
    );

    final inner = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .78,
      height: size.height * .34,
    );
    canvas.drawArc(
      inner,
      theta,
      math.pi * 1.32,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .95
        ..color = accentColor.withValues(alpha: 0.24),
    );
    canvas.restore();

    // ── 星点（增加到 80 个，更多层次） ─────────────────
    for (var index = 0; index < 80; index++) {
      final x = (index * 83 % 107) / 106 * size.width;
      final y = (index * 47 % 103) / 102 * size.height;
      // 不同星点用不同频率闪烁，更自然
      final twinkleFreq = index % 3 == 0 ? 1.5 : index % 3 == 1 ? 2.5 : 3.5;
      final twinkle =
          .2 + .8 * ((math.sin(theta * twinkleFreq + index * 1.73) + 1) * .5);
      final radius = index % 13 == 0
          ? 1.6
          : index % 7 == 0
              ? 1.0
              : index % 4 == 0
                  ? .75
                  : .4;
      // 大星点带十字光芒
      if (index % 13 == 0 && twinkle > .6) {
        final sparkleAlpha = (twinkle - .6) * 2.5;
        canvas.drawLine(
          Offset(x - radius * 3, y),
          Offset(x + radius * 3, y),
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = .5
            ..color = const Color(0xFFC3E8FF).withValues(alpha: sparkleAlpha * .3),
        );
        canvas.drawLine(
          Offset(x, y - radius * 3),
          Offset(x, y + radius * 3),
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = .5
            ..color = const Color(0xFFC3E8FF).withValues(alpha: sparkleAlpha * .3),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF4F8FCA),
            const Color(0xFFC3E8FF),
            twinkle,
          )!.withValues(alpha: .25 + twinkle * .5),
      );
    }

    // ── 扫描光点 ────────────────────────────────────
    final sweepX = phase * size.width;
    canvas.drawCircle(
      Offset(sweepX, size.height * (.18 + math.sin(theta) * .06)),
      2.2,
      Paint()..color = const Color(0xE67FE7FF),
    );

    // ── 流星（带渐变拖尾） ────────────────────────────
    for (var comet = 0; comet < 3; comet++) {
      final progress = (phase * (comet * .4 + .8) + comet * .37) % 1;
      if (progress < 0 || progress > .85) continue;
      final cx = size.width * (.08 + progress * .84);
      final cy = size.height *
          (.28 + comet * .22 + math.sin(theta * (comet + 1) + comet * 2.1) * .04);

      // 拖尾（渐变线段）
      final tailLength = 30 + comet * 10;
      final tailDx = -tailLength * .8;
      final tailDy = -tailLength * .5;
      canvas.drawLine(
        Offset(cx + tailDx, cy + tailDy),
        Offset(cx, cy),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: Alignment(
              (tailDx.isNegative ? 1 : -1).toDouble(),
              (tailDy.isNegative ? 1 : -1).toDouble(),
            ),
            end: Alignment.zero,
            colors: [
              Colors.transparent,
              const Color(0xFFAEDFFF).withValues(alpha: .6),
              const Color(0xFFD6F3FF),
            ],
          ).createShader(Rect.fromPoints(
            Offset(cx + tailDx, cy + tailDy),
            Offset(cx, cy),
          )),
      );
      // 流星头部
      canvas.drawCircle(
        Offset(cx, cy),
        1.5 + comet * .3,
        Paint()..color = const Color(0xFFE6F7FF),
      );
    }
  }

  @override
  bool shouldRepaint(GalaxyScenePainter oldDelegate) =>
      accentColor != oldDelegate.accentColor;
}

/// 点击记录时的粒子爆发效果，参考 Pulsar 的 FissionBurstPainter。
class EmotionBurstPainter extends CustomPainter {
  EmotionBurstPainter({
    required this.animation,
    required this.origin,
    this.color = const Color(0xFF8EEBFF),
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Alignment origin;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final raw = animation.value.clamp(0.0, 1.0);
    if (raw <= 0 || raw >= 1) return;

    final center = origin.alongSize(size);
    final expansion = Curves.easeOutExpo.transform(raw);
    final fade = (1 - raw).clamp(0.0, 1.0);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height);

    // 扩散环
    for (var ring = 0; ring < 3; ring++) {
      final delayed = (expansion - ring * .075).clamp(0.0, 1.0);
      if (delayed <= 0) continue;
      canvas.drawCircle(
        center,
        maxRadius * delayed * (.38 + ring * .08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 - ring * .75
          ..color = color.withValues(alpha: fade * (.66 - ring * .15)),
      );
    }

    // 粒子射线
    for (var particle = 0; particle < 30; particle++) {
      final angle = particle * math.pi * 2 / 30 + particle % 4 * .13;
      final distance = maxRadius * expansion * (.18 + (particle % 7) * .031);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final tail = point -
          Offset(math.cos(angle), math.sin(angle)) * (8 + particle % 5 * 3);
      canvas.drawLine(
        tail,
        point,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = particle % 5 == 0 ? 2.2 : 1.15
          ..color = Color.lerp(
            color,
            Colors.white,
            particle % 3 / 3,
          )!.withValues(alpha: fade * .82),
      );
    }
  }

  @override
  bool shouldRepaint(EmotionBurstPainter oldDelegate) =>
      origin != oldDelegate.origin || color != oldDelegate.color;
}

/// 星海背景组件，包裹 GalaxyScenePainter 并提供动画驱动。
class GalaxyScene extends StatelessWidget {
  const GalaxyScene({
    required this.animation,
    this.accentColor = const Color(0xFF57B5FF),
    super.key,
  });

  final Animation<double> animation;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: GalaxyScenePainter(
            animation: animation,
            accentColor: accentColor,
          ),
          child: const SizedBox.expand(),
        ),
      );
}
