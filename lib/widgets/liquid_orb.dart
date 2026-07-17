import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class PulsarPalette {
  const PulsarPalette(this.core, this.edge, this.accent);

  final Color core;
  final Color edge;
  final Color accent;

  static const values = [
    PulsarPalette(Color(0xFF00E7FF), Color(0xFF176BFF), Color(0xFF794CFF)),
    PulsarPalette(Color(0xFF68A8FF), Color(0xFF3155FF), Color(0xFFB337FF)),
    PulsarPalette(Color(0xFF5CF4D5), Color(0xFF008BEA), Color(0xFF715CFF)),
    PulsarPalette(Color(0xFFFF6FCA), Color(0xFF7B3CFF), Color(0xFF26C7FF)),
    PulsarPalette(Color(0xFFFFC46B), Color(0xFFFF5F8F), Color(0xFF8A4DFF)),
    PulsarPalette(Color(0xFFB5C9FF), Color(0xFF596BFF), Color(0xFF8E58FF)),
    PulsarPalette(Color(0xFF53F2B8), Color(0xFF00A6C8), Color(0xFF426CFF)),
  ];
}

/// Provides one slow animation clock for every visible energy orb.
/// The old implementation created a controller and rebuilt a widget tree for
/// every orb on every frame. This scope keeps motion synchronized and confines
/// frame work to CustomPainter only.
class PulsarMotion extends StatefulWidget {
  const PulsarMotion({required this.child, super.key});

  final Widget child;

  static Animation<double> of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PulsarMotionInherited>()!
        .animation;
  }

  @override
  State<PulsarMotion> createState() => _PulsarMotionState();
}

class _PulsarMotionState extends State<PulsarMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PulsarMotionInherited(animation: _controller, child: widget.child);
}

class _PulsarMotionInherited extends InheritedWidget {
  const _PulsarMotionInherited({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_PulsarMotionInherited oldWidget) => false;
}

class LiquidOrb extends StatefulWidget {
  const LiquidOrb({
    required this.size,
    required this.palette,
    required this.value,
    required this.total,
    super.key,
    this.onTap,
    this.showValue = true,
    this.complete = false,
    this.armed = false,
    this.hero = false,
    this.animate = true,
    this.entryDelay = Duration.zero,
  });

  final double size;
  final PulsarPalette palette;
  final int value;
  final int total;
  final VoidCallback? onTap;
  final bool showValue;
  final bool complete;
  final bool armed;
  final bool hero;
  final bool animate;
  final Duration entryDelay;

  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entry;
  Timer? _entryTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _entry = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
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
    final progress = widget.total <= 0
        ? 0.0
        : (widget.value / widget.total).clamp(0.0, 1.0);
    final sharedMotion = PulsarMotion.of(context);
    final motion = widget.animate
        ? sharedMotion
        : const AlwaysStoppedAnimation<double>(0.18);

    return Semantics(
      button: widget.onTap != null,
      label: '已完成 ${widget.value} 组，共 ${widget.total} 组',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _entry,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size.square(widget.size),
                    painter: EnergyOrbPainter(
                      animation: motion,
                      palette: widget.palette,
                      progress: progress,
                      complete: widget.complete,
                      hero: widget.hero,
                    ),
                  ),
                ),
                if (widget.showValue)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.armed
                        ? const Text(
                            '再点一次',
                            key: ValueKey('armed'),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFD5EC),
                            ),
                          )
                        : widget.complete
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('done'),
                            size: widget.size * .17,
                            color: Colors.white,
                          )
                        : RichText(
                            key: ValueKey(widget.value),
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${widget.value}',
                                  style: TextStyle(
                                    fontSize: widget.size * .16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: widget.palette.core,
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                                TextSpan(
                                  text: '/${widget.total}',
                                  style: TextStyle(
                                    fontSize: widget.size * .062,
                                    color: const Color(0xFF9AA9C2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnergyOrbPainter extends CustomPainter {
  EnergyOrbPainter({
    required this.animation,
    required this.palette,
    required this.progress,
    required this.complete,
    required this.hero,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final PulsarPalette palette;
  final double progress;
  final bool complete;
  final bool hero;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final angle = phase * math.pi * 2;
    final pulse = (math.sin(angle) + 1) * .5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * (hero ? .315 : .29) + pulse * .8;

    // Soft aura: gradients are substantially cheaper than per-frame blur layers.
    canvas.drawCircle(
      center,
      radius * 1.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.core.withValues(alpha: complete ? .27 : .19),
            palette.edge.withValues(alpha: .09),
            Colors.transparent,
          ],
          stops: const [0, .48, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.62)),
    );

    _drawOrbit(
      canvas,
      center,
      radius,
      angle * .42,
      width: radius * 3.15,
      height: radius * 1.28,
      tilt: -.22,
      alpha: .42,
    );
    _drawOrbit(
      canvas,
      center,
      radius,
      -angle * .28 + 1.8,
      width: radius * 2.35,
      height: radius * 2.02,
      tilt: .72,
      alpha: .18,
      small: true,
    );

    final sphere = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.42),
          radius: 1.08,
          colors: [
            Colors.white.withValues(alpha: .96),
            palette.core.withValues(alpha: .95),
            palette.edge.withValues(alpha: .92),
            const Color(0xFF080A24),
          ],
          stops: const [0, .12, .55, 1],
        ).createShader(sphere),
    );

    // Two moving translucent bodies create a restrained liquid-light effect.
    final bodyA =
        center +
        Offset(
          math.cos(angle * .63) * radius * .28,
          math.sin(angle * .47) * radius * .22,
        );
    canvas.drawCircle(
      bodyA,
      radius * .72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.accent.withValues(alpha: .52),
            palette.accent.withValues(alpha: .12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: bodyA, radius: radius * .72)),
    );
    final bodyB =
        center +
        Offset(
          math.sin(angle * .39 + 2) * radius * .34,
          math.cos(angle * .52 + 1) * radius * .26,
        );
    canvas.drawCircle(
      bodyB,
      radius * .62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .23),
            palette.core.withValues(alpha: .08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: bodyB, radius: radius * .62)),
    );

    final streamY = center.dy + math.sin(angle * .55) * radius * .13;
    final stream = Path()
      ..moveTo(center.dx - radius * 1.2, streamY)
      ..cubicTo(
        center.dx - radius * .42,
        streamY - radius * .34,
        center.dx + radius * .3,
        streamY + radius * .31,
        center.dx + radius * 1.2,
        streamY - radius * .08,
      );
    canvas.drawPath(
      stream,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .11
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: .08),
            palette.core.withValues(alpha: .32),
            Colors.transparent,
          ],
        ).createShader(sphere),
    );

    // Glass falloff restores a crisp edge and avoids the muddy appearance.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.42, -.5),
          radius: 1.15,
          colors: [
            Colors.white.withValues(alpha: .28),
            Colors.transparent,
            Colors.black.withValues(alpha: .52),
          ],
          stops: const [0, .4, 1],
        ).createShader(sphere),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(
          transform: GradientRotation(angle * .12),
          colors: [
            palette.core.withValues(alpha: .9),
            Colors.white.withValues(alpha: .18),
            palette.accent.withValues(alpha: .58),
            palette.core.withValues(alpha: .9),
          ],
        ).createShader(sphere),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.19),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = complete ? 2.2 : 1.35
        ..strokeCap = StrokeCap.round
        ..color = palette.core.withValues(alpha: complete ? .95 : .68),
    );
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    double motion, {
    required double width,
    required double height,
    required double tilt,
    required double alpha,
    bool small = false,
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
        ..strokeWidth = small ? .55 : .9
        ..shader = SweepGradient(
          transform: GradientRotation(motion * .18),
          colors: [
            Colors.transparent,
            palette.core.withValues(alpha: alpha),
            palette.accent.withValues(alpha: alpha * .8),
            Colors.transparent,
          ],
        ).createShader(bounds),
    );
    final node = Offset(
      math.cos(motion) * width / 2,
      math.sin(motion) * height / 2,
    );
    canvas.drawCircle(
      node,
      small ? 1.2 : 2.1,
      Paint()..color = small ? palette.accent : palette.core,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(EnergyOrbPainter oldDelegate) {
    return palette != oldDelegate.palette ||
        progress != oldDelegate.progress ||
        complete != oldDelegate.complete ||
        hero != oldDelegate.hero;
  }
}
