import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/squad_reaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// "Send a nudge" bar: tap an emoji to send it to a squadmate. No counts —
/// it's a poke. Sends are rate-limited by the caller; the recipient sees the
/// emoji next to their name on the squad page (and, once Phase 7 lands, a push).
/// The nudge emojis (🔥 💪 👏) are data/celebration, so they stay.
class ReactionBar extends StatelessWidget {
  final void Function(ReactionEmoji emoji) onSend;
  const ReactionBar({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SEND A NUDGE', style: AppText.caption),
      const SizedBox(height: Spacing.s12),
      Row(
        children: ReactionEmoji.values.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: Spacing.s12),
            child: Material(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSend(e);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.s16, vertical: Spacing.s8),
                  child: Text(e.glyph, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: Spacing.s8),
      Text(
        'Sends an emoji to their squad page. You can nudge each member once every few minutes.',
        style: AppText.bodyM.copyWith(color: AppColors.textTertiary),
      ),
    ]);
  }
}
