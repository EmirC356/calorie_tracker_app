import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/index.dart';
import '../providers/weight_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/date_nav_bar.dart';
import '../widgets/ui/ui.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  final _weightCtrl = TextEditingController();
  bool _isEmptyStomach = false;
  DateTime _date = dateOnly(DateTime.now()); // day shown in LOG HISTORY

  @override
  void initState() {
    super.initState();
    context.read<WeightProvider>().loadEntries();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _logWeight() {
    final val = double.tryParse(_weightCtrl.text);
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight')));
      return;
    }
    context.read<WeightProvider>().addEntry(WeightEntry(
      weight: val,
      timestamp: DateTime.now(),
      isEmptyStomach: _isEmptyStomach,
    ));
    _weightCtrl.clear();
    setState(() => _isEmptyStomach = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weight logged!')));
  }

  @override
  Widget build(BuildContext context) {
    final accent = SectionAccent.of(context);
    return Scaffold(
      appBar: SectionAppBar(title: 'Weight', accent: accent),
      body: Consumer<WeightProvider>(
        builder: (_, provider, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (provider.latest != null) ...[
              _CurrentWeightHero(entries: provider.entries),
              const SizedBox(height: Spacing.s24),
            ],

            // ── Input ───────────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.tabular(AppText.bodyL),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    suffixText: 'kg',
                  ),
                ),
              ),
              const SizedBox(width: Spacing.s12),
              ElevatedButton(
                onPressed: _logWeight,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.s20, vertical: Spacing.s16),
                ),
                child: const Text('LOG'),
              ),
            ]),
            const SizedBox(height: Spacing.s12),
            InkWell(
              onTap: () => setState(() => _isEmptyStomach = !_isEmptyStomach),
              child: Row(children: [
                // Focus rule: 1.5px accent border, never a solid accent fill.
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _isEmptyStomach
                            ? accent
                            : AppColors.textTertiary,
                        width: AppMotion.focusBorderWidth),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow:
                        _isEmptyStomach ? AppMotion.accentGlow(accent) : null,
                  ),
                  child: _isEmptyStomach
                      ? Icon(LucideIcons.check, size: 14, color: accent)
                      : null,
                ),
                const SizedBox(width: Spacing.s12),
                Text('Empty stomach?', style: AppText.bodyM),
                if (provider.latest != null) ...[
                  const Spacer(),
                  Text(
                    'LAST ${provider.latest!.weight.toStringAsFixed(1)} KG',
                    style: AppText.tabular(AppText.caption),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: Spacing.s24),

            if (provider.entries.isNotEmpty) ...[
              Text('WEIGHT HISTORY', style: AppText.caption),
              const SizedBox(height: Spacing.s12),
              SizedBox(height: 200, child: _WeightChart(entries: provider.entries)),
              const SizedBox(height: Spacing.s8),
              Row(children: [
                _legendDot(AppColors.healthRed),
                const SizedBox(width: Spacing.s4),
                Text('NORMAL', style: AppText.caption),
                const SizedBox(width: Spacing.s16),
                _legendDot(AppColors.calendarAmber),
                const SizedBox(width: Spacing.s4),
                Text('EMPTY STOMACH', style: AppText.caption),
              ]),
              const SizedBox(height: Spacing.s24),
            ],

            Text('LOG HISTORY', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            DateNavBar(
              selected: _date,
              accent: accent,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: Spacing.s8),
            ...() {
              final dayEntries = provider.entries
                  .where((e) => dateOnly(e.timestamp) == _date)
                  .toList()
                  .reversed
                  .toList();
              final isToday = _date == dateOnly(DateTime.now());
              if (dayEntries.isEmpty) {
                return [
                  Center(child: Padding(
                    padding: const EdgeInsets.all(Spacing.s32),
                    child: Text(
                        isToday ? 'No weight entries today' : 'No weight entries on this day',
                        style: AppText.bodyM
                            .copyWith(color: AppColors.textTertiary)),
                  )),
                ];
              }
              return dayEntries
                  .map((e) => _WeightTile(
                        entry: e,
                        onDelete: () => provider.deleteEntry(e.id!),
                      ))
                  .toList();
            }(),
          ]),
        ),
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// The data hero: current weight as a tabular displayL number with the delta
/// from the previous entry below.
class _CurrentWeightHero extends StatelessWidget {
  final List<WeightEntry> entries;
  const _CurrentWeightHero({required this.entries});

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = sorted.last;
    final previous = sorted.length > 1 ? sorted[sorted.length - 2] : null;
    final delta = previous != null ? latest.weight - previous.weight : null;

    // TODO(ui): clarify goal direction — profile goal data isn't available in
    // this screen, so loss reads as statusHit per the conservative default.
    Color deltaColor(double d) => d < 0
        ? AppColors.statusHit
        : (d > 0 ? AppColors.statusInProgress : AppColors.textSecondary);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CURRENT WEIGHT', style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AnimatedNumber(
            value: latest.weight,
            decimals: 1,
            style: AppText.displayL,
          ),
          const SizedBox(width: Spacing.s4),
          Text('kg',
              style: AppText.tabular(
                  AppText.titleM.copyWith(color: AppColors.textTertiary))),
        ],
      ),
      if (delta != null) ...[
        const SizedBox(height: Spacing.s4),
        Row(children: [
          Icon(
            delta < 0
                ? LucideIcons.arrowDown
                : (delta > 0 ? LucideIcons.arrowUp : LucideIcons.minus),
            size: 16,
            color: deltaColor(delta),
          ),
          const SizedBox(width: Spacing.s4),
          Text(
            '${delta.abs().toStringAsFixed(1)} kg since last entry',
            style: AppText.tabular(
                AppText.titleM.copyWith(color: deltaColor(delta))),
          ),
          if (latest.isEmptyStomach) ...[
            const SizedBox(width: Spacing.s8),
            const _EmptyStomachChip(),
          ],
        ]),
      ],
    ]);
  }
}

/// Empty-stomach flag chip in caption style.
class _EmptyStomachChip extends StatelessWidget {
  const _EmptyStomachChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s8, vertical: Spacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text('EMPTY STOMACH', style: AppText.caption),
      );
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightChart({required this.entries});

  static final TextStyle _axisStyle = AppText.tabular(
      AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 9));

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final base = sorted.first.timestamp;

    final normalSpots = <FlSpot>[];
    final emptySpots = <FlSpot>[];

    for (final e in sorted) {
      final x = e.timestamp.difference(base).inHours.toDouble();
      (e.isEmptyStomach ? emptySpots : normalSpots).add(FlSpot(x, e.weight));
    }

    final weights = sorted.map((e) => e.weight).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 1.5).clamp(0.0, double.infinity);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 1.5;

    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.surface1, strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            const FlLine(color: AppColors.surface1, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 38,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: _axisStyle),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          getTitlesWidget: (v, _) {
            final d = base.add(Duration(hours: v.toInt()));
            return Text(DateFormat('d/M').format(d), style: _axisStyle);
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        if (normalSpots.isNotEmpty)
          LineChartBarData(
            spots: normalSpots,
            isCurved: true,
            color: AppColors.healthRed,
            barWidth: 1.5,
            dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 2.5, color: AppColors.healthRed,
                  strokeWidth: 0, strokeColor: AppColors.surface0)),
          ),
        if (emptySpots.isNotEmpty)
          LineChartBarData(
            spots: emptySpots,
            isCurved: true,
            color: AppColors.calendarAmber,
            barWidth: 1.5,
            dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 2.5, color: AppColors.calendarAmber,
                  strokeWidth: 0, strokeColor: AppColors.surface0)),
          ),
      ],
    ));
  }
}

class _WeightTile extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onDelete;
  const _WeightTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: AppColors.surface2, width: 1)),
      ),
      child: Row(children: [
        Text('${entry.weight.toStringAsFixed(1)} kg',
            style: AppText.tabular(AppText.titleM)),
        const SizedBox(width: Spacing.s12),
        Expanded(
          child: Text(
              DateFormat('MMM d, HH:mm').format(entry.timestamp).toUpperCase(),
              style: AppText.tabular(AppText.caption)),
        ),
        if (entry.isEmptyStomach) ...[
          const _EmptyStomachChip(),
          const SizedBox(width: Spacing.s8),
        ],
        IconButton(
            icon: const Icon(LucideIcons.trash2,
                color: AppColors.statusMissed, size: 16),
            onPressed: onDelete,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero),
      ]),
    );
  }
}
