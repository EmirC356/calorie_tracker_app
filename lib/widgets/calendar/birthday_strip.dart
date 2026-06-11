import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A 🎂 strip shown at the top of a calendar day when a squadmate (or you) has a
/// birthday on that month-day. Non-graded — a nice moment, not a ritual.
class BirthdayStrip extends StatelessWidget {
  final String viewerUid;
  final DateTime date;
  const BirthdayStrip({super.key, required this.viewerUid, required this.date});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return StreamBuilder<List<GoalVisible>>(
      stream: service.watchReadableBirthdays(viewerUid),
      builder: (context, snap) {
        final today = (snap.data ?? const <GoalVisible>[])
            .where((g) => g.month == date.month && g.day == date.day)
            .toList();
        if (today.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final g in today)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: Spacing.s8),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.calendarAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Text(
                  g.ownerUid == viewerUid
                      ? '🎂 Your birthday'
                      : "🎂 ${g.displayName ?? 'A squadmate'}'s birthday",
                  style: AppText.bodyM.copyWith(color: AppColors.calendarAmber, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }
}
