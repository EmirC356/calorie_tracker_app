import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/index.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shown once after the first sign-in (or whenever the local profile is
/// incomplete): collects the details the app + squads need — display name,
/// birthday, sex, height, weight. Age is derived from the birthday.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  Sex _sex = Sex.male;
  String? _birthday; // ISO YYYY-MM-DD
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final p = context.read<ProfileProvider>().profile;
    _name = TextEditingController(text: auth.appUser?.displayName ?? '');
    _height = TextEditingController(text: (p?.heightCm ?? 0) > 0 ? p!.heightCm.toStringAsFixed(0) : '');
    _weight = TextEditingController(text: p?.fallbackWeightKg != null ? p!.fallbackWeightKg!.toStringAsFixed(1) : '');
    _sex = p?.sex ?? Sex.male;
    _birthday = p?.birthday;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = (_birthday != null ? DateTime.tryParse(_birthday!) : null) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _birthday =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _continue() async {
    final name = _name.text.trim();
    final height = double.tryParse(_height.text) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (_birthday == null) {
      setState(() => _error = 'Pick your birthday');
      return;
    }
    if (height <= 0) {
      setState(() => _error = 'Enter your height');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final profileP = context.read<ProfileProvider>();
    try {
      await auth.saveProfile(name); // cloud display name + clears needsProfileSetup
      await profileP.save(UserProfile(
        heightCm: height,
        age: 0, // derived from birthday
        sex: _sex,
        activity: ActivityLevel.moderate,
        goal: DietGoal.maintain,
        fallbackWeightKg: double.tryParse(_weight.text),
        birthday: _birthday,
      ));
      // The AuthGate rebuilds: hasProfile is now true → HomeScreen.
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save — please try again';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _birthday != null ? DateTime.tryParse(_birthday!) : null;
    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(title: const Text('Welcome — set up your profile'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.s20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('A few details so your goals and squad work. You can edit these any time in Profile.',
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: Spacing.s20),
            Text('NAME', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            TextField(
              controller: _name,
              style: AppText.bodyL,
              decoration: const InputDecoration(hintText: 'How squadmates see you'),
            ),
            const SizedBox(height: Spacing.s20),
            Text('BIRTHDAY', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            OutlinedButton.icon(
              onPressed: _pickBirthday,
              icon: const Icon(Icons.cake_outlined, size: 18),
              label: Text(b != null ? DateFormat('MMM d, yyyy').format(b) : 'Pick your birthday'),
            ),
            const SizedBox(height: Spacing.s20),
            Text('SEX', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            Row(children: [
              for (final (i, s) in Sex.values.indexed) ...[
                if (i > 0) const SizedBox(width: Spacing.s8),
                Expanded(child: _sexChip(s)),
              ],
            ]),
            const SizedBox(height: Spacing.s20),
            Row(children: [
              Expanded(child: _numField(_height, 'Height (cm)')),
              const SizedBox(width: Spacing.s12),
              Expanded(child: _numField(_weight, 'Weight (kg)')),
            ]),
            if (_error != null) ...[
              const SizedBox(height: Spacing.s16),
              Text(_error!, style: AppText.bodyS.copyWith(color: AppColors.statusMissed)),
            ],
            const SizedBox(height: Spacing.s24),
            ElevatedButton(
              onPressed: _saving ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.healthRed,
                foregroundColor: AppColors.surface0,
                padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
              ),
              child: Text(_saving ? 'Saving…' : 'Continue'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sexChip(Sex s) {
    final active = _sex == s;
    return GestureDetector(
      onTap: () => setState(() => _sex = s),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(
              color: active ? AppColors.healthRed : AppColors.surface2,
              width: active ? AppMotion.focusBorderWidth : 1),
        ),
        child: Text(s == Sex.male ? 'MALE' : 'FEMALE',
            textAlign: TextAlign.center,
            style: AppText.bodyS
                .copyWith(color: active ? AppColors.healthRed : AppColors.textSecondary)),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: AppText.tabular(AppText.bodyM),
        decoration: InputDecoration(isDense: true, labelText: label),
      );
}
