import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class PulsarPalette {
  const PulsarPalette(this.core, this.edge, this.accent);

  final Color core;
  final Color edge;
  final Color accent;

  static const values = [
    PulsarPalette(Color(0xFFB8F8FF), Color(0xFF49BCEB), Color(0xFF7776E8)),
    PulsarPalette(Color(0xFFC7D4FF), Color(0xFF6A8DE8), Color(0xFFA578E5)),
    PulsarPalette(Color(0xFFB4F5E2), Color(0xFF52BEAE), Color(0xFF6A83DE)),
    PulsarPalette(Color(0xFFF3C7E8), Color(0xFFC178B2), Color(0xFF7779DF)),
    PulsarPalette(Color(0xFFFFE1B7), Color(0xFFD7A165), Color(0xFFB178C9)),
    PulsarPalette(Color(0xFFD8E1F6), Color(0xFF8595BB), Color(0xFF8C79C9)),
    PulsarPalette(Color(0xFFB7F2D5), Color(0xFF55B89A), Color(0xFF608AD7)),
  ];
}

/// A single slow clock shared by every orb. Only CustomPainter repaints while
/// the widget tree stays still.
class PulsarMotion extends StatefulWidget {
  const PulsarMotion({required this.child, super.key});

  final Widget child;

  static Animation<double> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_PulsarMotionInherited>()
          ?.animation ??
      const AlwaysStoppedAnimation<double>(0.16);

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
      duration: const Duration(seconds: 16),
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
      duration: const Duration(milliseconds: 460),
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
    final motion = widget.animate
        ? PulsarMotion.of(context)
        : const AlwaysStoppedAnimation<double>(0.16);

    final visual = ScaleTransition(
      scale: _entry,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: LightClusterPainter(
                  animation: motion,
                  palette: widget.palette,
                  progress: progress,
                  complete: widget.complete,
                  hero: widget.hero,
                ),
              ),
            ),
            if (widget.showValue) _reading(),
          ],
        ),
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label: '已完成 ${widget.value} 组，共 ${widget.total} 组',
      child: widget.onTap == null
          ? visual
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: visual,
            ),
    );
  }

  Widget _reading() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: widget.armed
        ? Text(
            '再点一次',
            key: const ValueKey('armed'),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: widget.palette.core,
            ),
          )
        : widget.complete
        ? Icon(
            Icons.check_rounded,
            key: const ValueKey('done'),
            size: widget.size * .16,
            color: Colors.white.withValues(alpha: .94),
          )
        : RichText(
            key: ValueKey(widget.value),
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${widget.value}',
                  style: TextStyle(
                    fontSize: widget.size * .15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .95),
                    shadows: [
                      Shadow(
                        color: widget.palette.edge.withValues(alpha: .7),
                        blurRadius: 9,
                      ),
                    ],
                  ),
                ),
                TextSpan(
                  text: '/${widget.total}',
                  style: TextStyle(
                    fontSize: widget.size * .06,
                    color: const Color(0xFF9AA7BC),
                  ),
                ),
              ],
            ),
          ),
  );
}

/// A soft light mass, not a glass sphere. The cluster is built from radial
/// falloffs with no hard boundary, while two fine rings orbit independently.
class LightClusterPainter extends CustomPainter {
  LightClusterPainter({
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
    final theta = phase * math.pi * 2;
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width * (hero ? .30 : .28);
    final breath = 1 + math.sin(theta) * .045;
    final clusterRadius = base * breath;

    _drawSoftCircle(
      canvas,
      center,
      clusterRadius * 1.86,
      [
        palette.core.withValues(alpha: complete ? .31 : .23),
        palette.edge.withValues(alpha: .13),
        Colors.transparent,
      ],
      const [.0, .42, 1],
    );

    _drawOrbit(
      canvas,
      center,
      theta * .34,
      width: clusterRadius * 3.35,
      height: clusterRadius * 1.42,
      tilt: -.22,
      alpha: .58,
      nodeRadius: 2.15,
    );
    _drawOrbit(
      canvas,
      center,
      -theta * .24 + 1.9,
      width: clusterRadius * 2.48,
      height: clusterRadius * 2.12,
      tilt: .68,
      alpha: .34,
      nodeRadius: 1.45,
    );
    _drawOrbit(
      canvas,
      center,
      theta * .19 + 3.4,
      width: clusterRadius * 2.9,
      height: clusterRadius * .78,
      tilt: .24,
      alpha: .26,
      nodeRadius: 1.05,
    );

    // The main light mass has a diffuse boundary and a warm-white center.
    _drawSoftCircle(
      canvas,
      center,
      clusterRadius * 1.12,
      [
        Colors.white.withValues(alpha: .98),
        palette.core.withValues(alpha: .88),
        palette.edge.withValues(alpha: .55),
        palette.accent.withValues(alpha: .18),
        Colors.transparent,
      ],
      const [0, .16, .48, .76, 1],
    );

    final mistA =
        center +
        Offset(
          math.cos(theta * .53) * clusterRadius * .31,
          math.sin(theta * .41) * clusterRadius * .22,
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

    final mistB =
        center +
        Offset(
          math.sin(theta * .37 + 1.2) * clusterRadius * .28,
          math.cos(theta * .49 + .8) * clusterRadius * .24,
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

    // A fine broken ring doubles as progress without enclosing a hard sphere.
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
        ..strokeWidth = complete ? 2.2 : 1.35
        ..strokeCap = StrokeCap.round
        ..color = palette.core.withValues(alpha: complete ? .96 : .68),
    );
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
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
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
        ..strokeWidth = .95
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
          ..strokeWidth = segment == 0 ? 1.35 : .72
          ..strokeCap = StrokeCap.round
          ..color = palette.core.withValues(alpha: alpha * (1 - segment * .2)),
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
          ..color = palette.edge.withValues(alpha: .10 + (3 - trail) * .08),
      );
    }
    canvas.drawCircle(
      node,
      nodeRadius,
      Paint()..color = palette.core.withValues(alpha: .98),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LightClusterPainter oldDelegate) =>
      palette != oldDelegate.palette ||
      progress != oldDelegate.progress ||
      complete != oldDelegate.complete ||
      hero != oldDelegate.hero;
}
