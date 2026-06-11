import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Full-width app bar for a section "room": large displayM title, optional
/// uppercase caption above, optional trailing actions, and a 2px accent line
/// under the title in the section accent. No Material elevation, ever.
///
/// Title/accent changes animate with a fade + slide (used by the tab-switch
/// sweep when sections change).
class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? caption;
  final Color accent;
  final List<Widget>? actions;

  const SectionAppBar({
    super.key,
    required this.title,
    required this.accent,
    this.caption,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(caption != null ? 104 : 88);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
          child: AnimatedSwitcher(
            duration: AppMotion.enter,
            reverseDuration: AppMotion.exit,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('$title-${accent.toARGB32()}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (caption != null) ...[
                  Text(caption!.toUpperCase(), style: AppText.caption),
                  const SizedBox(height: Spacing.s4),
                ],
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppText.displayM)),
                    ...?actions,
                  ],
                ),
                const SizedBox(height: Spacing.s8),
                Container(width: Spacing.s48, height: 2, color: accent),
                const SizedBox(height: Spacing.s8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
