import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';

/// Strict BYO API-key configuration: pick a provider + model, enter your key,
/// and test it before it's saved. Keys live on-device only.
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  bool? _lastOk; // null = no result yet, true = works, false = failed
  String? _lastMessage;

  static const _shortName = {'gemini': 'Gemini', 'openai': 'OpenAI', 'anthropic': 'Claude'};

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  void _resetResult() {
    if (_lastOk != null || _lastMessage != null) {
      setState(() {
        _lastOk = null;
        _lastMessage = null;
      });
    }
  }

  Future<void> _onProviderChanged(String pk) async {
    await context.read<AiService>().setActiveProvider(pk);
    _keyCtrl.clear();
    _resetResult();
  }

  Future<void> _onModelChanged(String? model) async {
    if (model == null) return;
    final ai = context.read<AiService>();
    await ai.setActiveProvider(ai.activeProviderKey, model: model);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _keyCtrl.text = text);
      _resetResult();
    }
  }

  Future<void> _testKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    final ai = context.read<AiService>();
    final messenger = ScaffoldMessenger.of(context);
    final pk = ai.activeProviderKey;
    final previous = await ai.getApiKey(pk);

    setState(() {
      _testing = true;
      _lastOk = null;
      _lastMessage = null;
    });

    // Persist temporarily so the active provider tests with this key.
    await ai.setApiKey(pk, key);
    try {
      final ok = await ai.testActiveKey();
      if (ok) {
        setState(() {
          _lastOk = true;
          _lastMessage = 'Key works';
        });
        _keyCtrl.clear();
        messenger.showSnackBar(const SnackBar(content: Text('Key works')));
      } else {
        await _restore(ai, pk, previous);
        setState(() {
          _lastOk = false;
          _lastMessage = 'Unexpected response from provider.';
        });
      }
    } catch (e) {
      // Never keep a key that fails the test; restore the prior one if any.
      await _restore(ai, pk, previous);
      setState(() {
        _lastOk = false;
        _lastMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _restore(AiService ai, String pk, String? previous) async {
    if (previous != null && previous.isNotEmpty) {
      await ai.setApiKey(pk, previous);
    } else {
      await ai.clearApiKey(pk);
    }
  }

  Future<void> _clearKey() async {
    final ai = context.read<AiService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear API key?'),
        content: Text('Remove the saved ${ai.displayNameFor(ai.activeProviderKey)} key from this device? AI features will lock until you add one again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: kNeonRed))),
        ],
      ),
    );
    if (confirm != true) return;
    await ai.clearApiKey(ai.activeProviderKey);
    _keyCtrl.clear();
    _resetResult();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiService>();
    final configured = ai.hasValidKey;
    final pk = ai.activeProviderKey;

    return Scaffold(
      appBar: AppBar(title: const Text('AI PROVIDER')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Active provider ────────────────────────────────────────────────
          Text('ACTIVE PROVIDER', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                for (final p in AiService.providerKeys)
                  ButtonSegment(value: p, label: Text(_shortName[p] ?? p)),
              ],
              selected: {pk},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _onProviderChanged(s.first),
            ),
          ),
          const SizedBox(height: 14),
          Text('MODEL', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderDim),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: kCard,
                value: ai.activeModel,
                style: const TextStyle(color: kText, fontSize: 14),
                items: [
                  for (final m in ai.modelsFor(pk))
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: _onModelChanged,
              ),
            ),
          ),

          const SizedBox(height: 28),
          // ── API key ────────────────────────────────────────────────────────
          Row(children: [
            Text('API KEY', style: neonLabel(kCyan, size: 12)),
            const Spacer(),
            _statusPill(configured),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: kText, fontFamily: 'monospace'),
            onChanged: (_) => _resetResult(),
            decoration: InputDecoration(
              hintText: 'Paste your ${_shortName[pk]} key',
              filled: true,
              fillColor: kSurface,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: kTextDim),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 16, color: kCyan),
              label: const Text('Paste from clipboard', style: TextStyle(color: kCyan)),
            ),
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _keyCtrl,
            builder: (_, value, __) {
              final canTest = value.text.trim().isNotEmpty && !_testing;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canTest ? _testKey : null,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_testing ? 'TESTING…' : 'TEST KEY', style: const TextStyle(letterSpacing: 1.2)),
                ),
              );
            },
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: 10),
            _testResultRow(),
          ],
          if (configured) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearKey,
                style: OutlinedButton.styleFrom(
                    foregroundColor: kNeonRed, side: const BorderSide(color: kNeonRed)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('CLEAR KEY'),
              ),
            ),
          ],

          // ── How to get an API key (Task 5 fills this in) ───────────────────
          _instructionsSection(context),
        ],
      ),
    );
  }

  Widget _statusPill(bool configured) {
    final color = configured ? kNeonGreen : kNeonYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(configured ? Icons.check_circle : Icons.warning_amber, size: 14, color: color),
        const SizedBox(width: 6),
        Text(configured ? 'Configured' : 'Not configured',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _testResultRow() {
    final ok = _lastOk == true;
    final color = ok ? kNeonGreen : kNeonRed;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ok ? Icons.check_circle : Icons.cancel, color: color, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(_lastMessage!, style: TextStyle(color: color, fontSize: 13))),
    ]);
  }

  // Replaced with the full provider instructions in Task 5.
  Widget _instructionsSection(BuildContext context) => const SizedBox.shrink();
}
