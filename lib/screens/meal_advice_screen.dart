import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

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
      appBar: AppBar(
        title: const Text('MEAL ADVISOR'),
        titleTextStyle: const TextStyle(color: kPurple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPurple, blurRadius: 8)]),
        iconTheme: const IconThemeData(color: kPurple),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ASK ANYTHING', style: neonLabel(kPurple, size: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(
              hintText: 'e.g. How much protein do I need to build muscle?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _ask,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shadowColor: kPurple, elevation: 8,
            ),
            child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('GET ADVICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
          if (_advice != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: neonBox(kPurple),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RESPONSE', style: neonLabel(kPurple, size: 12)),
                const SizedBox(height: 10),
                Text(_advice!, style: const TextStyle(color: kText, fontSize: 14, height: 1.6)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
