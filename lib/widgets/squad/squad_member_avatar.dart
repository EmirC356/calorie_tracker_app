import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Streak-aware member avatar. The flame + ring escalate with the streak; a
/// member gone 3+ days (and not paused) is greyed/tarnished; an at-risk member
/// gets a ⚠ overlay; a paused member shows 🌴 instead of any flame chrome.
class SquadMemberAvatar extends StatefulWidget {
  final String? photoURL;
  final double currentStreak;
  final DateTime? lastActiveDate;
  final bool atRiskFlag;
  final bool paused;
  final double radius;

  /// Injected for deterministic tarnish tests; defaults to DateTime.now().
  final DateTime? now;

  const SquadMemberAvatar({
    super.key,
    required this.photoURL,
    required this.currentStreak,
    this.lastActiveDate,
    this.atRiskFlag = false,
    this.paused = false,
    this.radius = 20,
    this.now,
  });

  static String streakLabel(double streak) {
    final s = streak.floor();
    return s > 999 ? '999+' : '$s';
  }

  @override
  State<SquadMemberAvatar> createState() => _SquadMemberAvatarState();
}

class _SquadMemberAvatarState extends State<SquadMemberAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  StreakTier get _tier => streakTierFor(widget.currentStreak);

  @override
  void initState() {
    super.initState();
    if (!widget.paused && _tier.animated) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
        lowerBound: 1.0,
        upperBound: _tier.strong ? 1.28 : 1.15,
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  bool get _tarnished {
    if (widget.paused || widget.lastActiveDate == null) return false;
    final ref = widget.now ?? DateTime.now();
    final days = DateTime(ref.year, ref.month, ref.day)
        .difference(DateTime(widget.lastActiveDate!.year, widget.lastActiveDate!.month, widget.lastActiveDate!.day))
        .inDays;
    return days >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    if (widget.paused) return _circleWithChip('🌴', const Color(0xFF4CC38A));

    final tier = _tier;
    Widget avatar = CircleAvatar(
      radius: r,
      backgroundColor: kSurface,
      backgroundImage: (widget.photoURL?.isNotEmpty ?? false) ? NetworkImage(widget.photoURL!) : null,
      child: (widget.photoURL?.isEmpty ?? true) ? Icon(Icons.person, color: kNavy, size: r) : null,
    );

    if (tier.ringColor != null) {
      avatar = Container(
        padding: EdgeInsets.all(tier.ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tier.ringColor!, width: tier.ringWidth),
        ),
        child: avatar,
      );
    }

    if (_tarnished) {
      avatar = Opacity(
        opacity: 0.7,
        child: ColorFiltered(colorFilter: _desaturate(0.3), child: avatar),
      );
    }

    final overlays = <Widget>[avatar];

    if (tier.flameSize > 0) {
      Widget flame = Text('🔥', style: TextStyle(fontSize: tier.flameSize));
      if (_pulse != null) flame = ScaleTransition(scale: _pulse!, child: flame);
      overlays.add(Positioned(
        right: -2,
        bottom: -2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: kBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            flame,
            const SizedBox(width: 2),
            Text(SquadMemberAvatar.streakLabel(widget.currentStreak),
                style: TextStyle(color: tier.ringColor ?? kAmber, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      ));
    }

    if (widget.atRiskFlag && widget.currentStreak >= 3) {
      overlays.add(const Positioned(
        right: -2,
        top: -2,
        child: Text('⚠', style: TextStyle(fontSize: 14)),
      ));
    }

    return SizedBox(
      width: r * 2 + 12,
      height: r * 2 + 12,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: overlays),
    );
  }

  Widget _circleWithChip(String emoji, Color color) {
    final r = widget.radius;
    return SizedBox(
      width: r * 2 + 12,
      height: r * 2 + 12,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        CircleAvatar(
          radius: r,
          backgroundColor: kSurface,
          backgroundImage: (widget.photoURL?.isNotEmpty ?? false) ? NetworkImage(widget.photoURL!) : null,
          child: (widget.photoURL?.isEmpty ?? true) ? Icon(Icons.person, color: color, size: r) : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ]),
    );
  }

  /// Saturation matrix at [sat] (0 = greyscale, 1 = full colour).
  static ColorFilter _desaturate(double sat) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final inv = 1 - sat;
    return ColorFilter.matrix(<double>[
      lr * inv + sat, lg * inv, lb * inv, 0, 0,
      lr * inv, lg * inv + sat, lb * inv, 0, 0,
      lr * inv, lg * inv, lb * inv + sat, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
}
