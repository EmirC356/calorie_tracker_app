import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// The section-change "sweep": a 220ms horizontal band of the incoming
/// section's accent at low alpha that crosses the screen and self-removes.
///
/// Fire with `SectionSweep.show(context, accent)` on tab change (the Phase-2
/// SectionNav owns this). Purely decorative — the overlay ignores pointers
/// and never blocks interaction.
class SectionSweep {
  SectionSweep._();

  static void show(BuildContext context, Color accent) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SweepBand(accent: accent, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _SweepBand extends StatefulWidget {
  final Color accent;
  final VoidCallback onDone;

  const _SweepBand({required this.accent, required this.onDone});

  @override
  State<_SweepBand> createState() => _SweepBandState();
}

class _SweepBandState extends State<_SweepBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.sweepDuration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return FractionalTranslation(
            // Band travels from fully off-screen left to off-screen right.
            translation: Offset(-1 + 2 * t, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.accent.withValues(alpha: 0),
                    widget.accent.withValues(alpha: 0.10),
                    widget.accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}
