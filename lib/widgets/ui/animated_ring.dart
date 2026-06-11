import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Circular progress ring. Fills from 0 to [progress] with the overshoot
/// spring on first build and re-animates from the previous value on change.
///
/// Stroke 8, background ring surface2, foreground in [accent] (a section
/// accent or status color — the only sanctioned accent uses). Optional
/// [child] renders centered inside the ring (e.g. a HeroStat).
class AnimatedRing extends StatefulWidget {
  final double progress; // 0..1
  final Color accent;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const AnimatedRing({
    super.key,
    required this.progress,
    required this.accent,
    this.size = 120,
    this.strokeWidth = 8,
    this.child,
  });

  @override
  State<AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<AnimatedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.value = 0;
    _animateTo(widget.progress);
  }

  @override
  void didUpdateWidget(AnimatedRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) _animateTo(widget.progress);
  }

  void _animateTo(double target) {
    _controller.animateWith(AppMotion.springSimulation(
      spring: AppMotion.overshootSpring,
      from: _controller.value,
      to: target,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            progress: _controller.value,
            accent: widget.accent,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.accent,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.surface2;
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.strokeWidth != strokeWidth;
}
