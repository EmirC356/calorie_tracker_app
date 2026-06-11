import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart' show StreakTier, streakTierFor;

/// Circular member avatar with the full streak-tier treatment — the one
/// avatar used everywhere a member shows.
///
/// Streak tiers (via [streakTierFor]): flame badge grows 1→30+, ring escalates
/// amber → scarlet (pulse) → gold (strong pulse). Paused members get a 🌴 chip
/// instead of a flame; "tarnished" (no entries 3+ days) renders greyscale at
/// 0.7 opacity; at-risk members get a small ⚠ glyph overlay.
class MemberAvatar extends StatefulWidget {
  final String? photoURL;
  final String displayName;
  final double currentStreak;
  final DateTime? lastActiveDate;
  final bool atRisk;
  final bool paused;
  final double size;

  const MemberAvatar({
    super.key,
    this.photoURL,
    required this.displayName,
    this.currentStreak = 0,
    this.lastActiveDate,
    this.atRisk = false,
    this.paused = false,
    this.size = 48,
  });

  bool get tarnished =>
      lastActiveDate != null &&
      DateTime.now().difference(lastActiveDate!).inDays >= 3;

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  StreakTier get _tier => streakTierFor(widget.currentStreak);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MemberAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (_tier.animated && !widget.paused) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _initials {
    final words =
        widget.displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  // Standard luminance-weighted greyscale matrix.
  static const List<double> _greyscale = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final tier = _tier;

    Widget circle = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
        border: tier.ringColor != null && !widget.paused
            ? Border.all(color: tier.ringColor!, width: tier.ringWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: widget.photoURL != null
          ? Image.network(
              widget.photoURL!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsText(),
            )
          : _initialsText(),
    );

    if (widget.tarnished) {
      circle = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscale),
        child: Opacity(opacity: 0.7, child: circle),
      );
    }

    final badges = <Widget>[];
    if (widget.paused) {
      badges.add(Positioned(
        right: -2,
        bottom: -2,
        child: _emojiBadge('🌴', 12),
      ));
    } else if (tier.flameSize > 0) {
      final scale = tier.strong ? 1.12 : 1.08;
      badges.add(Positioned(
        right: -2,
        bottom: -2,
        child: tier.animated
            ? AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: 1 + (scale - 1) * _pulse.value,
                  child: child,
                ),
                child: Text('🔥', style: TextStyle(fontSize: tier.flameSize)),
              )
            : Text('🔥', style: TextStyle(fontSize: tier.flameSize)),
      ));
    }
    if (widget.atRisk) {
      badges.add(Positioned(
        right: -2,
        top: -2,
        child: _emojiBadge('⚠', 10),
      ));
    }

    return SizedBox(
      width: widget.size + 8,
      height: widget.size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [circle, ...badges],
      ),
    );
  }

  Widget _initialsText() => Text(
        _initials,
        style: AppText.bodyS.copyWith(
          color: AppColors.textSecondary,
          fontSize: widget.size * 0.32,
        ),
      );

  Widget _emojiBadge(String emoji, double size) => Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface3,
        ),
        child: Text(emoji, style: TextStyle(fontSize: size)),
      );
}
