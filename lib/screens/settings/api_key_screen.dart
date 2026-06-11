import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/ai_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
import '../../widgets/ui/status_pill.dart';

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
              child: const Text('Clear',
                  style: TextStyle(color: AppColors.statusMissed))),
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
      appBar: AppBar(title: const Text('AI Provider')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.s16),
        children: [
          // ── Active provider ────────────────────────────────────────────────
          Text('ACTIVE PROVIDER', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
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
          const SizedBox(height: Spacing.s16),
          Text('MODEL', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: AppColors.surface2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AppColors.surface3,
                value: ai.activeModel,
                style: AppText.bodyM,
                items: [
                  for (final m in ai.modelsFor(pk))
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: _onModelChanged,
              ),
            ),
          ),

          const SizedBox(height: Spacing.s32),
          // ── API key ────────────────────────────────────────────────────────
          Row(children: [
            Text('API KEY', style: AppText.caption),
            const Spacer(),
            StatusPill(
              status: configured ? PillStatus.hit : PillStatus.inProgress,
              label: configured ? 'Configured' : 'Not configured',
            ),
          ]),
          const SizedBox(height: Spacing.s8),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'monospace'),
            onChanged: (_) => _resetResult(),
            decoration: InputDecoration(
              hintText: 'Paste your ${_shortName[pk]} key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: Spacing.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pasteFromClipboard,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.healthRed),
              icon: const Icon(LucideIcons.clipboard, size: 16),
              label: const Text('Paste from clipboard'),
            ),
          ),
          const SizedBox(height: Spacing.s4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _keyCtrl,
            builder: (_, value, __) {
              final canTest = value.text.trim().isNotEmpty && !_testing;
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canTest ? _testKey : null,
                  icon: _testing
                      ? const ShimmerPlaceholder.line(width: 16)
                      : const Icon(LucideIcons.radioTower, size: 18),
                  label: Text(_testing ? 'Testing…' : 'Test key'),
                ),
              );
            },
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: Spacing.s8),
            _testResultRow(),
          ],
          if (configured) ...[
            const SizedBox(height: Spacing.s8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearKey,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusMissed,
                    side: const BorderSide(
                        color: AppColors.statusMissed, width: 1.5)),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Clear key'),
              ),
            ),
          ],

          // ── How to get an API key (Task 5 fills this in) ───────────────────
          _instructionsSection(context),
        ],
      ),
    );
  }

  Widget _testResultRow() {
    final ok = _lastOk == true;
    final color = ok ? AppColors.statusHit : AppColors.statusMissed;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ok ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
          color: color, size: 18),
      const SizedBox(width: Spacing.s8),
      Expanded(
          child: Text(_lastMessage!,
              style: AppText.bodyS.copyWith(color: color))),
    ]);
  }

  Future<void> _launch(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }

  TextStyle get _body =>
      AppText.bodyM.copyWith(color: AppColors.textPrimary, height: 1.4);

  Widget _stepText(int n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s4 / 2),
        child: Text('$n. $text', style: _body),
      );

  Widget _stepLink(int n, String label, String url) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s4 / 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$n. $label', style: _body),
          Padding(
            padding: const EdgeInsets.only(left: Spacing.s16, top: Spacing.s4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flexible(
                child: SelectableText.rich(TextSpan(
                  text: url,
                  style: AppText.bodyS.copyWith(
                      color: AppColors.healthRed,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = () => _launch(url),
                )),
              ),
              const SizedBox(width: Spacing.s4),
              GestureDetector(
                onTap: () => _launch(url),
                child: const Icon(LucideIcons.externalLink,
                    color: AppColors.healthRed, size: 14),
              ),
            ]),
          ),
        ]),
      );

  Widget _footer(String note) => Padding(
        padding: const EdgeInsets.only(top: Spacing.s8),
        child: Text(note,
            style: AppText.caption
                .copyWith(fontStyle: FontStyle.italic)),
      );

  Widget _providerCard({
    required IconData icon,
    required String header,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s8),
      child: ExpansionTile(
        backgroundColor: AppColors.surface1,
        collapsedBackgroundColor: AppColors.surface1,
        iconColor: AppColors.healthRed,
        collapsedIconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        collapsedTextColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r12)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r12)),
        leading: Icon(icon),
        title: Text(header, style: AppText.titleM),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding:
            const EdgeInsets.fromLTRB(Spacing.s16, 0, Spacing.s16, Spacing.s16),
        children: children,
      ),
    );
  }

  Widget _instructionsSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: Spacing.s32),
      const Divider(color: AppColors.surface2),
      const SizedBox(height: Spacing.s12),
      Text('NEED A KEY?', style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Text('Pick a provider above, then follow its steps to create a key.',
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: Spacing.s16),
      _providerCard(icon: LucideIcons.sparkles, header: 'Google Gemini', children: [
        _stepLink(1, 'Open the API keys page:', 'https://aistudio.google.com/apikey'),
        _stepText(2, 'Sign in with your Google account.'),
        _stepText(3, 'Click "Create API key" → "Create API key in new project".'),
        _stepText(4, 'Copy the key (starts with AIza…).'),
        _stepText(5, 'Paste it above and tap "Test key".'),
        _footer('Free tier: 60 requests/min, 1500/day on gemini-2.5-flash.'),
      ]),
      _providerCard(icon: LucideIcons.bot, header: 'OpenAI', children: [
        _stepLink(1, 'Open the API keys page:', 'https://platform.openai.com/api-keys'),
        _stepText(2, 'Sign in or create an OpenAI account.'),
        _stepText(3, 'Click "Create new secret key" — give it any name.'),
        _stepText(4, 'Copy the key (starts with sk-…).'),
        _stepLink(5, 'Add a payment method (OpenAI requires one even for trial use):',
            'https://platform.openai.com/settings/organization/billing'),
        _stepText(6, 'Paste the key above and tap "Test key".'),
        _footer('Pay-as-you-go. gpt-4o-mini is the cheapest option for meal analysis.'),
      ]),
      _providerCard(icon: LucideIcons.brain, header: 'Anthropic Claude', children: [
        _stepLink(1, 'Open the API keys page:', 'https://console.anthropic.com/settings/keys'),
        _stepText(2, 'Sign in or create an Anthropic account.'),
        _stepText(3, 'Click "Create Key" — give it any name and select your workspace.'),
        _stepText(4, 'Copy the key (starts with sk-ant-…).'),
        _stepLink(5, 'Add credits if you haven\'t already:',
            'https://console.anthropic.com/settings/billing'),
        _stepText(6, 'Paste the key above and tap "Test key".'),
        _footer('Pay-as-you-go. claude-haiku-4-5 is cheapest for meal analysis.'),
      ]),
    ]);
  }
}
