import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../providers/weight_provider.dart';
import '../theme/app_theme.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  final _weightCtrl = TextEditingController();
  bool _isEmptyStomach = false;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('WEIGHT TRACKER'),
        titleTextStyle: const TextStyle(color: kNeonGreen, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kNeonGreen, blurRadius: 8)]),
        iconTheme: const IconThemeData(color: kNeonGreen),
      ),
      body: Consumer<WeightProvider>(
        builder: (_, provider, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Input card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: neonBox(kNeonGreen),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        labelStyle: const TextStyle(color: kNeonGreen),
                        suffixText: 'kg',
                        suffixStyle: const TextStyle(color: kNeonGreen),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kNeonGreen, width: 1)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kNeonGreen, width: 2)),
                        filled: true, fillColor: kSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _logWeight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonGreen, foregroundColor: kBg,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    child: const Text('LOG', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _isEmptyStomach = !_isEmptyStomach),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        border: Border.all(color: kNeonGreen, width: 2),
                        borderRadius: BorderRadius.circular(4),
                        color: _isEmptyStomach ? kNeonGreen : kSurface,
                      ),
                      child: _isEmptyStomach ? const Icon(Icons.check, size: 14, color: kBg) : null,
                    ),
                    const SizedBox(width: 10),
                    const Text('Empty stomach?', style: TextStyle(color: kText, fontSize: 15)),
                    if (provider.latest != null) ...[
                      const Spacer(),
                      Text(
                        'Last: ${provider.latest!.weight.toStringAsFixed(1)} kg',
                        style: const TextStyle(color: kTextDim, fontSize: 12),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            if (provider.entries.isNotEmpty) ...[
              Text('WEIGHT HISTORY', style: neonLabel(kNeonGreen, size: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: neonBox(kNeonGreen),
                child: SizedBox(height: 200, child: _WeightChart(entries: provider.entries)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: kNeonGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Normal', style: TextStyle(color: kTextDim, fontSize: 11)),
                const SizedBox(width: 16),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: kNeonYellow, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Empty stomach', style: TextStyle(color: kTextDim, fontSize: 11)),
              ]),
              const SizedBox(height: 20),
            ],

            Text('LOG HISTORY', style: neonLabel(kNeonGreen, size: 13)),
            const SizedBox(height: 8),
            if (provider.entries.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No weight entries yet', style: Theme.of(context).textTheme.bodySmall),
              ))
            else
              ...provider.entries.reversed.take(30).map((e) => _WeightTile(
                entry: e,
                onDelete: () => provider.deleteEntry(e.id!),
              )),
          ]),
        ),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightChart({required this.entries});

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
      backgroundColor: kSurface,
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) => const FlLine(color: kBorderDim, strokeWidth: 1),
        getDrawingVerticalLine: (_) => const FlLine(color: kBorderDim, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: kBorderDim)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 38,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(color: kTextDim, fontSize: 9)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          getTitlesWidget: (v, _) {
            final d = base.add(Duration(hours: v.toInt()));
            return Text(DateFormat('d/M').format(d), style: const TextStyle(color: kTextDim, fontSize: 8));
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
            color: kNeonGreen,
            barWidth: 2,
            shadow: const Shadow(color: kNeonGreen, blurRadius: 6),
            dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: kNeonGreen, strokeWidth: 1, strokeColor: kBg)),
          ),
        if (emptySpots.isNotEmpty)
          LineChartBarData(
            spots: emptySpots,
            isCurved: true,
            color: kNeonYellow,
            barWidth: 2,
            shadow: const Shadow(color: kNeonYellow, blurRadius: 6),
            dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 5, color: kNeonYellow, strokeWidth: 1.5, strokeColor: kBg)),
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
    final color = entry.isEmptyStomach ? kNeonYellow : kNeonGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: neonBox(color),
      child: Row(children: [
        Icon(entry.isEmptyStomach ? Icons.nightlight_round : Icons.fiber_manual_record, color: color, size: 16),
        const SizedBox(width: 10),
        Text('${entry.weight.toStringAsFixed(1)} kg', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, shadows: textGlow(color))),
        const SizedBox(width: 12),
        Expanded(child: Text(DateFormat('MMM d, HH:mm').format(entry.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12))),
        if (entry.isEmptyStomach)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: kNeonYellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: kNeonYellow.withValues(alpha: 0.5))),
            child: const Text('empty', style: TextStyle(color: kNeonYellow, fontSize: 10)),
          ),
        IconButton(icon: const Icon(Icons.delete_outline, color: kNeonRed, size: 18), onPressed: onDelete, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
      ]),
    );
  }
}
