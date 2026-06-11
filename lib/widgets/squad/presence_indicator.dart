import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum PresenceTier { activeNow, recent, today, thisWeek, quiet }

/// A member's recency, derived from `members/{uid}.lastActivityAt`.
class Presence {
  final String label;
  final PresenceTier tier;
  const Presence(this.label, this.tier);

  bool get activeNow => tier == PresenceTier.activeNow;

  Color get color => switch (tier) {
        PresenceTier.activeNow => AppColors.statusHit,
        PresenceTier.recent => AppColors.statusHit,
        PresenceTier.today => AppColors.textSecondary,
        PresenceTier.thisWeek => AppColors.textSecondary,
        PresenceTier.quiet => AppColors.textTertiary,
      };
}

/// Pure recency formatter:
///   < 5 min  → "Active now"   (green, pulsing)
///   < 1 hour → "{N} min ago"
///   < 24 h   → "{N} hours ago"
///   < 7 days → "{N} days ago"
///   >= 7 days→ "Quiet {N} days" (textTertiary)
Presence presenceFor(DateTime? lastActive, {DateTime? now}) {
  if (lastActive == null) return const Presence('No activity yet', PresenceTier.quiet);
  final d = (now ?? DateTime.now()).difference(lastActive);
  if (d.isNegative || d.inMinutes < 5) return const Presence('Active now', PresenceTier.activeNow);
  if (d.inMinutes < 60) return Presence('${d.inMinutes} min ago', PresenceTier.recent);
  if (d.inHours < 24) {
    final h = d.inHours;
    return Presence('$h hour${h == 1 ? '' : 's'} ago', PresenceTier.today);
  }
  if (d.inDays < 7) {
    final n = d.inDays;
    return Presence('$n day${n == 1 ? '' : 's'} ago', PresenceTier.thisWeek);
  }
  return Presence('Quiet ${d.inDays} days', PresenceTier.quiet);
}

/// A small dot + recency label, reused across every member surface. The
/// "active now" dot pulses; quieter states are static.
class PresenceIndicator extends StatelessWidget {
  final DateTime? lastActive;
  final double dotSize;
  final bool showLabel;
  final TextStyle? labelStyle;
  const PresenceIndicator({
    super.key,
    required this.lastActive,
    this.dotSize = 8,
    this.showLabel = true,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final p = presenceFor(lastActive);
    final dot = p.activeNow
        ? _PulseDot(size: dotSize, color: p.color)
        : Container(
            width: dotSize, height: dotSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.color));
    if (!showLabel) return dot;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      dot,
      const SizedBox(width: 6),
      Flexible(
        child: Text(p.label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: (labelStyle ?? AppText.caption).copyWith(color: p.color)),
      ),
    ]);
  }
}

class _PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  const _PulseDot({required this.size, required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Center(
        child: Stack(alignment: Alignment.center, children: [
          // Expanding halo.
          FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 0.0).animate(_c),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 2.0).animate(
                  CurvedAnimation(parent: _c, curve: Curves.easeOut)),
              child: Container(
                  width: widget.size, height: widget.size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
            ),
          ),
          Container(
              width: widget.size, height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}
