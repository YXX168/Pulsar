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
        ..strokeWidth = .9
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
        ..strokeWidth = .7
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
