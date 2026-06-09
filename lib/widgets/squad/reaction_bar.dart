import 'package:flutter/material.dart';
import '../../models/squad_reaction.dart';
import '../../theme/app_theme.dart';

/// Row of 🔥 💪 👏 with counts. Tapping toggles your own reaction (adds if you
/// haven't reacted with it, removes if you have). Shows who reacted.
class ReactionBar extends StatelessWidget {
  final List<SquadReaction> reactions; // already filtered to one member's day
  final String myUid;
  final void Function(ReactionEmoji emoji) onTap;

  const ReactionBar({super.key, required this.reactions, required this.myUid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kNavy),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CHEER THEM ON', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 10),
        Row(children: ReactionEmoji.values.map((e) {
          final forEmoji = reactions.where((r) => r.emoji == e).toList();
          final mine = forEmoji.any((r) => r.fromUid == myUid);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onTap(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: mine ? kNavy.withValues(alpha: 0.22) : kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: mine ? kNavy : kBorderDim),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.glyph, style: const TextStyle(fontSize: 18)),
                  if (forEmoji.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('${forEmoji.length}',
                        style: TextStyle(color: mine ? kNavy : kText, fontWeight: FontWeight.bold)),
                  ],
                ]),
              ),
            ),
          );
        }).toList()),
        if (reactions.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...ReactionEmoji.values.map((e) {
            final names = reactions.where((r) => r.emoji == e).map((r) => r.fromName).toList();
            if (names.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${e.glyph}  ${names.join(', ')}',
                  style: const TextStyle(color: kTextDim, fontSize: 12)),
            );
          }),
        ] else
          const Text('Be the first to react', style: TextStyle(color: kTextDim, fontSize: 12)),
      ]),
    );
  }
}
