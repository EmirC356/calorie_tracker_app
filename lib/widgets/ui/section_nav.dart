import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'section_sweep.dart';

/// The three section "rooms" of the app and their accent identities.
/// Accents are used ONLY for focus borders, CTAs, active indicators, hero
/// stats, progress fills, and the section sweep — never backgrounds or body
/// text (design/system.md).
enum AppSection {
  squads('Squads', AppColors.squadBlue, LucideIcons.users),
  health('Health', AppColors.healthRed, LucideIcons.heartPulse),
  calendar('Calendar', AppColors.calendarAmber, LucideIcons.calendar);

  final String label;
  final Color accent;
  final IconData icon;
  const AppSection(this.label, this.accent, this.icon);
}

/// Threads the active section's accent down the tree. Screens read it via
/// `SectionAccent.of(context)` for their SectionAppBar line, primary CTA, and
/// FAB colors, so a screen hosted in another room recolors automatically.
class SectionAccent extends InheritedWidget {
  final Color color;

  const SectionAccent({super.key, required this.color, required super.child});

  /// The enclosing section accent; falls back to textPrimary so widgets used
  /// outside a section never crash.
  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionAccent>()?.color ??
      AppColors.textPrimary;

  @override
  bool updateShouldNotify(SectionAccent oldWidget) => color != oldWidget.color;
}

/// Custom bottom navigation for the three sections. surface0 background with
/// a 1px divider hairline above; the active tab takes its section accent plus
/// a 2px indicator bar, inactive tabs stay textSecondary. Tab changes haptic-
/// click and fire the SectionSweep in the incoming section's accent.
///
/// Note: lucide is a line-only icon set, so "filled when active" is rendered
/// as accent color + indicator bar instead of a filled glyph.
class SectionNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const SectionNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (i, section) in AppSection.values.indexed)
              Expanded(
                child: _SectionTab(
                  section: section,
                  active: i == currentIndex,
                  onTap: () {
                    if (i == currentIndex) return;
                    HapticFeedback.selectionClick();
                    SectionSweep.show(context, section.accent);
                    onChanged(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final AppSection section;
  final bool active;
  final VoidCallback onTap;

  const _SectionTab({
    required this.section,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? section.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: Spacing.s24,
            height: 2,
            color: active ? section.accent : Colors.transparent,
          ),
          const SizedBox(height: Spacing.s8),
          Icon(section.icon, size: 22, color: color),
          const SizedBox(height: Spacing.s4),
          Text(section.label, style: AppText.bodyS.copyWith(color: color)),
          const SizedBox(height: Spacing.s8),
        ],
      ),
    );
  }
}
