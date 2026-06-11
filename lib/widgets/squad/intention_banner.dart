import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';

const _templates = ['Gym 3x', 'Stay under 2200 kcal', 'Log every meal', 'Read 30 min/day'];

/// Top-of-squad banner for this week's public commitment. Amber prompt until
/// set; shows your intention once declared. Always squad-visible.
class IntentionBanner extends StatelessWidget {
  final String squadId;
  final String uid;
  const IntentionBanner({super.key, required this.squadId, required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final week = isoWeekKey(DateTime.now());
    return StreamBuilder<SquadIntention?>(
      stream: service.watchMyIntention(squadId, week, uid),
      builder: (context, snap) {
        final mine = snap.data;
        final set = mine != null && mine.text.isNotEmpty;
        return InkWell(
          onTap: mine?.isGraded == true ? null : () => _showSheet(context, week, mine),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: neonBox(set ? kNavy : kAmber),
            child: Row(children: [
              Icon(set ? Icons.flag : Icons.flag_outlined, color: set ? kNavy : kAmber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  set ? "This week: ${mine.text}" : "Set this week's intention — visible to all squadmates",
                  style: const TextStyle(color: kText, fontSize: 13)),
              ),
              if (mine?.isGraded != true) const Icon(Icons.chevron_right, color: kTextDim, size: 18),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _showSheet(BuildContext context, String week, SquadIntention? current) async {
    final service = context.read<SquadProvider>().service;
    final ctrl = TextEditingController(text: current?.text ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)), side: BorderSide(color: kAmber)),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This week, I will…', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Visible to all squadmates.', style: TextStyle(color: kTextDim, fontSize: 11)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _templates)
                ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  backgroundColor: kCard,
                  side: const BorderSide(color: kNavy),
                  onPressed: () => setState(() => ctrl.text = t),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl, maxLength: 80, style: const TextStyle(color: kText),
              decoration: const InputDecoration(hintText: 'or write your own…'),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  await service.setIntention(squadId, week, SquadIntention(uid: uid, text: text));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('COMMIT'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
