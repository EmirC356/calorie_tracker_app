import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ai/blocked_ai_overlay.dart';
import '../widgets/ui/shimmer_placeholder.dart';

class MealAdviceScreen extends StatefulWidget {
  const MealAdviceScreen({super.key});

  @override
  State<MealAdviceScreen> createState() => _MealAdviceScreenState();
}

class _MealAdviceScreenState extends State<MealAdviceScreen> {
  final _ctrl = TextEditingController();
  String? _advice;
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _ask() async {
    if (_ctrl.text.trim().isEmpty) return;
    if (!aiService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set your Gemini key in Settings first')));
      return;
    }
    setState(() { _loading = true; _advice = null; });
    try {
      final response = await aiService.getMealAdvice(_ctrl.text.trim());
      if (mounted) setState(() => _advice = response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Advisor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ASK ANYTHING', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'e.g. How much protein do I need to build muscle?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Spacing.s12),
          OutlinedButton(
            onPressed: _loading ? null : _ask,
            child: _loading
                ? const ShimmerPlaceholder.line(width: 96)
                : const Text('Get advice'),
          ),
          if (_loading) ...[
            const SizedBox(height: Spacing.s20),
            const ShimmerPlaceholder.card(height: 140),
          ],
          if (_advice != null) ...[
            const SizedBox(height: Spacing.s20),
            Text('RESPONSE', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            Text(_advice!,
                style: AppText.bodyM
                    .copyWith(color: AppColors.textPrimary, height: 1.6)),
          ],
        ]),
      ).lockedWhenNoKey(context,
          message: 'Add your API key to ask the Meal Advisor.'),
    );
  }
}
