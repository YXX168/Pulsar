import 'dart:math' as math;

import 'package:flutter/material.dart';

class GalaxyScenePainter extends CustomPainter {
  GalaxyScenePainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final theta = phase * math.pi * 2;
    final center = Offset(size.width * .5, size.height * .49);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.28 + math.sin(theta * .35) * .018);
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
          transform: GradientRotation(theta * .08),
          colors: const [
            Colors.transparent,
            Color(0x4057B5FF),
            Color(0x388E73F5),
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
      theta * .16,
      math.pi * 1.32,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .95
        ..color = const Color(0x3D57DDF4),
    );
    canvas.restore();

    for (var index = 0; index < 46; index++) {
      final x = (index * 83 % 103) / 102 * size.width;
      final y = (index * 47 % 101) / 100 * size.height;
      final twinkle =
          .25 + .75 * ((math.sin(theta * .62 + index * 1.73) + 1) * .5);
      final radius = index % 11 == 0
          ? 1.35
          : index % 4 == 0
          ? .75
          : .42;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF4F8FCA),
            const Color(0xFFC3E8FF),
            twinkle,
          )!.withValues(alpha: .28 + twinkle * .48),
      );
    }

    final sweepX = (phase * 1.18 % 1) * size.width;
    canvas.drawCircle(
      Offset(sweepX, size.height * (.18 + math.sin(theta * .43) * .06)),
      2.2,
      Paint()..color = const Color(0xE67FE7FF),
    );
    for (var comet = 0; comet < 2; comet++) {
      final progress = (phase * (.72 + comet * .13) + comet * .41) % 1;
      final point = Offset(
        size.width * (.08 + progress * .84),
        size.height *
            (.36 + comet * .31 + math.sin(theta * .55 + comet * 2.1) * .045),
      );
      canvas.drawCircle(
        point,
        1.25 + comet * .35,
        Paint()..color = const Color(0xBDAEDFFF),
      );
    }
  }

  @override
  bool shouldRepaint(GalaxyScenePainter oldDelegate) => false;
}

class FissionBurstPainter extends CustomPainter {
  FissionBurstPainter({
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
    final maxRadius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );

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

    for (var particle = 0; particle < 30; particle++) {
      final angle = particle * math.pi * 2 / 30 + particle % 4 * .13;
      final distance = maxRadius * expansion * (.18 + (particle % 7) * .031);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final tail =
          point -
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
  bool shouldRepaint(FissionBurstPainter oldDelegate) =>
      origin != oldDelegate.origin || color != oldDelegate.color;
}
