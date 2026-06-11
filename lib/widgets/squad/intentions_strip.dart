import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../ui/member_avatar.dart';

const _intentionTemplates = ['Gym 3x', 'Stay under 2200 kcal', 'Log every meal', 'Read 30 min/day'];

/// "THIS WEEK" — a horizontal strip of each member's weekly intention. Your own
/// chip is squadBlue when set, an amber "Set yours" CTA when not. Hidden when no
/// one (including you) has set one.
class IntentionsStrip extends StatelessWidget {
  final String squadId;
  final String? myUid;
  const IntentionsStrip({super.key, required this.squadId, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final week = isoWeekKey(DateTime.now());
    return StreamBuilder<List<SquadIntention>>(
      stream: service.watchIntentions(squadId, week),
      builder: (context, iSnap) {
        final byUid = {for (final i in (iSnap.data ?? const <SquadIntention>[])) i.uid: i};
        final mine = myUid != null ? byUid[myUid] : null;
        if (byUid.isEmpty && mine == null) return const SizedBox.shrink();
        return StreamBuilder<List<SquadMember>>(
          stream: service.watchMembers(squadId),
          builder: (context, mSnap) {
            final members = mSnap.data ?? const <SquadMember>[];
            // Members with an intention, plus you (for the "Set yours" CTA).
            final shown = members
                .where((m) => byUid.containsKey(m.uid) || m.uid == myUid)
                .toList()
              ..sort((a, b) => (a.uid == myUid ? 0 : 1).compareTo(b.uid == myUid ? 0 : 1));
            if (shown.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s12, Spacing.s16, Spacing.s8),
                child: Text('THIS WEEK', style: AppText.caption),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
                  children: [
                    for (final m in shown)
                      _chip(context, service, week, m, byUid[m.uid], m.uid == myUid),
                  ],
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  Widget _chip(BuildContext context, SquadService service, String week, SquadMember m,
      SquadIntention? intention, bool isMine) {
    final hasIntention = intention != null && intention.text.isNotEmpty;
    final emptyMine = isMine && !hasIntention;
    final borderColor = emptyMine
        ? AppColors.calendarAmber
        : (isMine ? AppColors.squadBlue : AppColors.surface2);
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.s8),
      child: GestureDetector(
        onTap: () => emptyMine
            ? _setSheet(context, service, week)
            : _viewSheet(context, m, intention!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: borderColor, width: isMine ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            MemberAvatar(photoURL: m.photoURL, displayName: m.displayName, size: 24),
            const SizedBox(width: Spacing.s8),
            Text(
              emptyMine ? 'Set yours' : _truncate(intention!.text),
              style: AppText.bodyS.copyWith(
                  color: emptyMine ? AppColors.calendarAmber : AppColors.textPrimary),
            ),
          ]),
        ),
      ),
    );
  }

  static String _truncate(String s) => s.length <= 28 ? s : '${s.substring(0, 27)}…';

  void _viewSheet(BuildContext context, SquadMember m, SquadIntention intention) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              MemberAvatar(photoURL: m.photoURL, displayName: m.displayName, size: 32),
              const SizedBox(width: Spacing.s12),
              Text(m.displayName, style: AppText.titleM),
            ]),
            const SizedBox(height: Spacing.s16),
            Text('"${intention.text}"', style: AppText.titleL),
            if (intention.declaredAt != null) ...[
              const SizedBox(height: Spacing.s8),
              Text('Declared ${DateFormat('EEE, MMM d').format(intention.declaredAt!)}',
                  style: AppText.caption.copyWith(color: AppColors.textTertiary)),
            ],
          ]),
        ),
      ),
    );
  }

  void _setSheet(BuildContext context, SquadService service, String week) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            left: Spacing.s20, right: Spacing.s20, top: Spacing.s20,
            bottom: Spacing.s20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheet, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This week, I will…', style: AppText.titleM),
            const SizedBox(height: Spacing.s12),
            Wrap(spacing: Spacing.s8, runSpacing: Spacing.s8, children: [
              for (final t in _intentionTemplates)
                ActionChip(
                  label: Text(t, style: AppText.bodyS),
                  backgroundColor: AppColors.surface2,
                  onPressed: () => setState(() => ctrl.text = t),
                ),
            ]),
            const SizedBox(height: Spacing.s12),
            TextField(
              controller: ctrl, maxLength: 80, style: AppText.bodyL,
              decoration: const InputDecoration(hintText: 'or write your own…'),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.squadBlue, foregroundColor: AppColors.surface0),
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty || myUid == null) return;
                  await service.setIntention(squadId, week, SquadIntention(uid: myUid!, text: text));
                  if (sheet.mounted) Navigator.pop(sheet);
                },
                child: const Text('Commit'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
