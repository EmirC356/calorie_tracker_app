import 'package:flutter/material.dart';
import '../../models/squad_reaction.dart';
import '../../theme/app_theme.dart';

/// "Send a nudge" bar: tap an emoji to send it to a squadmate. No counts —
/// it's a poke. Sends are rate-limited by the caller; the recipient sees the
/// emoji next to their name on the squad page (and, once Phase 7 lands, a push).
class ReactionBar extends StatelessWidget {
  final void Function(ReactionEmoji emoji) onSend;
  const ReactionBar({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kNavy),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SEND A NUDGE', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 10),
        Row(
          children: ReactionEmoji.values.map((e) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => onSend(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kNavy),
                  ),
                  child: Text(e.glyph, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Text('Sends an emoji to their squad page. You can nudge each member once every few minutes.',
            style: TextStyle(color: kTextDim, fontSize: 11)),
      ]),
    );
  }
}
