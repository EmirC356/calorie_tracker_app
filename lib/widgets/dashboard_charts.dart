import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A dashboard section with an uppercase caption header that collapses its
/// chart child. No card chrome — charts breathe directly on surface0
/// (design/system.md: restraint everywhere except where data lives).
class CollapsibleChartSection extends StatelessWidget {
  final String title;

  /// Retained for call-site compatibility; headers are monochrome captions.
  final Color accent;
  final Widget child;
  final bool initiallyExpanded;

  const CollapsibleChartSection({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textTertiary,
          title: Text(title.toUpperCase(), style: AppText.caption),
          childrenPadding: const EdgeInsets.only(
              top: Spacing.s8, bottom: Spacing.s16),
          children: [SizedBox(height: 200, child: child)],
        ),
      ),
    );
  }
}

Widget _emptyHint(String text) => Center(
      child: Text(text,
          style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
    );

/// Axis label style shared by every chart: textTertiary caption, tabular.
final TextStyle _axisStyle = AppText.tabular(
    AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 9));

FlGridData _gridData({bool vertical = true}) => FlGridData(
      show: true,
      drawVerticalLine: vertical,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: AppColors.surface1, strokeWidth: 1),
      getDrawingVerticalLine: (_) =>
          const FlLine(color: AppColors.surface1, strokeWidth: 1),
    );

/// Weight over the last 90 days with a 7-day moving-average overlay.
class WeightLineChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const WeightLineChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final recent = entries.where((e) => e.timestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (recent.length < 2) {
      return _emptyHint('Log at least 2 weights in the last 90 days');
    }

    final base = recent.first.timestamp;
    double xOf(DateTime t) => t.difference(base).inHours / 24.0;

    final rawSpots = recent.map((e) => FlSpot(xOf(e.timestamp), e.weight)).toList();

    // 7-day trailing moving average, by date window.
    final maSpots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      final windowStart = recent[i].timestamp.subtract(const Duration(days: 7));
      final window = recent.where((e) =>
          !e.timestamp.isAfter(recent[i].timestamp) &&
          e.timestamp.isAfter(windowStart));
      final avg = window.map((e) => e.weight).reduce((a, b) => a + b) / window.length;
      maSpots.add(FlSpot(xOf(recent[i].timestamp), avg));
    }

    final weights = recent.map((e) => e.weight).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 1.5).clamp(0.0, double.infinity);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 1.5;

    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: _gridData(),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: _axisStyle),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          interval: 15,
          getTitlesWidget: (v, _) {
            final d = base.add(Duration(hours: (v * 24).toInt()));
            return Text(DateFormat('d/M').format(d), style: _axisStyle);
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        // Raw entries — the data line, in the Health room accent.
        LineChartBarData(
          spots: rawSpots,
          isCurved: false,
          color: AppColors.healthRed,
          barWidth: 1.5,
          dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
            FlDotCirclePainter(radius: 2.5, color: AppColors.healthRed,
                strokeWidth: 0, strokeColor: AppColors.surface0)),
        ),
        // 7-day moving average — quiet context line.
        LineChartBarData(
          spots: maSpots,
          isCurved: true,
          color: AppColors.textTertiary,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}

/// Daily calories for the last 14 days as bars, with a goal line overlay.
class CaloriesBarChart extends StatelessWidget {
  final List<DayTotal> totals;
  final double? goal;
  const CaloriesBarChart({super.key, required this.totals, this.goal});

  @override
  Widget build(BuildContext context) {
    if (totals.every((t) => t.value == 0)) {
      return _emptyHint('No meals logged in the last 14 days');
    }
    final maxVal = totals.map((t) => t.value).reduce((a, b) => a > b ? a : b);
    final maxY = ([maxVal, goal ?? 0].reduce((a, b) => a > b ? a : b)) * 1.2 + 1;

    return BarChart(BarChartData(
      maxY: maxY,
      gridData: _gridData(vertical: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 38,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: _axisStyle),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= totals.length || i % 2 != 0) return const SizedBox.shrink();
            return Text(DateFormat('d/M').format(totals[i].day), style: _axisStyle);
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      extraLinesData: goal != null && goal! > 0
          ? ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: goal!,
                color: AppColors.statusHit,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppText.caption.copyWith(color: AppColors.statusHit, fontSize: 9),
                  labelResolver: (_) => 'GOAL',
                ),
              ),
            ])
          : const ExtraLinesData(),
      barGroups: [
        for (var i = 0; i < totals.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: totals[i].value,
              color: (goal != null && totals[i].value > goal!)
                  ? AppColors.statusMissed
                  : AppColors.healthRed,
              width: 7,
              borderRadius: BorderRadius.zero,
            ),
          ]),
      ],
    ));
  }
}

/// Donut of today's protein/carb/fat split: surface2 background ring, three
/// tinted segments (healthRed / calendarAmber / squadBlue) with thin 1.5px
/// accent outlines, legend labels in caption style.
class MacrosDonut extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  const MacrosDonut({super.key, required this.protein, required this.carbs, required this.fat});

  static const double _centerSpace = 48;
  static const double _ringWidth = 18;

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total <= 0) return _emptyHint('No macros logged today');

    double pct(double g) => g / total * 100;
    final sections = [
      _section(protein, AppColors.healthRed),
      _section(carbs, AppColors.calendarAmber),
      _section(fat, AppColors.squadBlue),
    ];

    const donutSize = (_centerSpace + _ringWidth) * 2;
    return Row(children: [
      Expanded(
        flex: 3,
        child: Center(
          child: SizedBox(
            width: donutSize,
            height: donutSize,
            child: Stack(alignment: Alignment.center, children: [
              // Background ring on the surface ladder.
              Container(
                width: donutSize,
                height: donutSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.surface2, width: _ringWidth),
                ),
              ),
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: _centerSpace,
                startDegreeOffset: -90,
                sections: sections,
              )),
            ]),
          ),
        ),
      ),
      Expanded(
        flex: 2,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend('PROTEIN', protein, pct(protein), AppColors.healthRed),
          const SizedBox(height: Spacing.s8),
          _legend('CARBS', carbs, pct(carbs), AppColors.calendarAmber),
          const SizedBox(height: Spacing.s8),
          _legend('FAT', fat, pct(fat), AppColors.squadBlue),
        ]),
      ),
    ]);
  }

  PieChartSectionData _section(double grams, Color color) =>
      PieChartSectionData(
        value: grams,
        color: color.withValues(alpha: 0.18),
        borderSide: BorderSide(color: color, width: 1.5),
        showTitle: false,
        radius: _ringWidth,
      );

  Widget _legend(String label, double grams, double pct, Color color) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: Spacing.s8),
      Expanded(
        child: Text(
          '$label  ${grams.toStringAsFixed(0)}g',
          style: AppText.tabular(AppText.caption),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Text('${pct.toStringAsFixed(0)}%',
          style: AppText.tabular(
              AppText.caption.copyWith(color: AppColors.textPrimary))),
    ]);
  }
}
