import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart' show StreakTier, streakTierFor;

/// Legacy streak-aware member avatar, kept as a stable public API (its render
/// tree — flame + count chip, ScaleTransition pulse, single tarnish
/// ColorFiltered/Opacity — is pinned by widget tests). New code should prefer
/// the `MemberAvatar` primitive in `lib/widgets/ui/`; this widget shares the
/// same streak-tier system ([streakTierFor]) and design tokens.
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
    if (widget.paused) return _circleWithChip('🌴', AppColors.statusPaused);

    final tier = _tier;
    Widget avatar = CircleAvatar(
      radius: r,
      backgroundColor: AppColors.surface2,
      backgroundImage: (widget.photoURL?.isNotEmpty ?? false) ? NetworkImage(widget.photoURL!) : null,
      child: (widget.photoURL?.isEmpty ?? true)
          ? Icon(Icons.person, color: AppColors.textTertiary, size: r)
          : null,
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
            color: AppColors.surface0.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            flame,
            const SizedBox(width: 2),
            Text(
              SquadMemberAvatar.streakLabel(widget.currentStreak),
              style: AppText.tabular(AppText.caption.copyWith(
                color: tier.ringColor ?? AppColors.calendarAmber,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
            ),
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
          backgroundColor: AppColors.surface2,
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
