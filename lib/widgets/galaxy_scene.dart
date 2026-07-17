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
        ..strokeWidth = .65
        ..shader = SweepGradient(
          transform: GradientRotation(theta * .08),
          colors: const [
            Colors.transparent,
            Color(0x264C8BD7),
            Color(0x1C8A63CF),
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
        ..strokeWidth = .45
        ..color = const Color(0x1F4FB5D5),
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
          )!.withValues(alpha: .18 + twinkle * .38),
      );
    }

    final sweepX = (phase * 1.18 % 1) * size.width;
    canvas.drawCircle(
      Offset(sweepX, size.height * (.18 + math.sin(theta * .43) * .06)),
      1.8,
      Paint()..color = const Color(0xB47FE7FF),
    );
  }

  @override
  bool shouldRepaint(GalaxyScenePainter oldDelegate) => false;
}
