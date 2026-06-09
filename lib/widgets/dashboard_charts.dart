import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../theme/app_theme.dart';

/// A dashboard section with a neon header that collapses its chart child.
class CollapsibleChartSection extends StatelessWidget {
  final String title;
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: neonBox(accent),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: accent,
          collapsedIconColor: accent,
          title: Text(title, style: neonLabel(accent, size: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [SizedBox(height: 200, child: child)],
        ),
      ),
    );
  }
}

Widget _emptyHint(String text) => Center(
      child: Text(text, style: const TextStyle(color: kTextDim, fontSize: 12)),
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
      backgroundColor: kSurface,
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) => const FlLine(color: kBorderDim, strokeWidth: 1),
        getDrawingVerticalLine: (_) => const FlLine(color: kBorderDim, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: kBorderDim)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: kTextDim, fontSize: 9)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          interval: 15,
          getTitlesWidget: (v, _) {
            final d = base.add(Duration(hours: (v * 24).toInt()));
            return Text(DateFormat('d/M').format(d), style: const TextStyle(color: kTextDim, fontSize: 8));
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: rawSpots,
          isCurved: false,
          color: kNeonGreen,
          barWidth: 1.5,
          dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
            FlDotCirclePainter(radius: 2.5, color: kNeonGreen, strokeWidth: 0, strokeColor: kBg)),
        ),
        LineChartBarData(
          spots: maSpots,
          isCurved: true,
          color: kCyan,
          barWidth: 2.5,
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
      backgroundColor: kSurface,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: kBorderDim, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: kBorderDim)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 38,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: kTextDim, fontSize: 9)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= totals.length || i % 2 != 0) return const SizedBox.shrink();
            return Text(DateFormat('d/M').format(totals[i].day), style: const TextStyle(color: kTextDim, fontSize: 8));
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      extraLinesData: goal != null && goal! > 0
          ? ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: goal!,
                color: kNeonGreen,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: kNeonGreen, fontSize: 9),
                  labelResolver: (_) => 'Goal',
                ),
              ),
            ])
          : const ExtraLinesData(),
      barGroups: [
        for (var i = 0; i < totals.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: totals[i].value,
              color: (goal != null && totals[i].value > goal!) ? kNeonRed : kCyan,
              width: 7,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ]),
      ],
    ));
  }
}

/// Donut of today's protein/carb/fat split in grams and %.
class MacrosDonut extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  const MacrosDonut({super.key, required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total <= 0) return _emptyHint('No macros logged today');

    double pct(double g) => g / total * 100;
    final sections = [
      _section('P', protein, pct(protein), kNeonRed),
      _section('C', carbs, pct(carbs), kNeonYellow),
      _section('F', fat, pct(fat), kOrange),
    ];

    return Row(children: [
      Expanded(
        flex: 3,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 38,
          sections: sections,
        )),
      ),
      Expanded(
        flex: 2,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend('Protein', protein, pct(protein), kNeonRed),
          const SizedBox(height: 8),
          _legend('Carbs', carbs, pct(carbs), kNeonYellow),
          const SizedBox(height: 8),
          _legend('Fat', fat, pct(fat), kOrange),
        ]),
      ),
    ]);
  }

  PieChartSectionData _section(String t, double grams, double pct, Color color) =>
      PieChartSectionData(
        value: grams,
        color: color,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 42,
        titleStyle: const TextStyle(color: kBg, fontSize: 11, fontWeight: FontWeight.bold),
      );

  Widget _legend(String label, double grams, double pct, Color color) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Expanded(child: Text(
        '$label  ${grams.toStringAsFixed(0)}g',
        style: const TextStyle(color: kText, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      )),
      Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}
