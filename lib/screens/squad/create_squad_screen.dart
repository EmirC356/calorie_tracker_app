import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../providers/squad_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'squad_home_screen.dart';

class CreateSquadScreen extends StatefulWidget {
  const CreateSquadScreen({super.key});

  @override
  State<CreateSquadScreen> createState() => _CreateSquadScreenState();
}

class _CreateSquadScreenState extends State<CreateSquadScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  Squad? _created;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your squad a name')));
      return;
    }
    setState(() => _busy = true);
    try {
      final squad = await context.read<SquadProvider>().createSquad(_name.text);
      if (mounted) setState(() => _created = squad);
    } on SquadException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _shareText(Squad s) =>
      'Join my squad "${s.name}" on Calorie Tracker!\nUse code: ${s.inviteCode}\n(valid 7 days)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Squad')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.s20),
        child: _created == null ? _form() : _success(_created!),
      ),
    );
  }

  Widget _form() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('SQUAD NAME', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      TextField(
        controller: _name,
        maxLength: 30,
        decoration: const InputDecoration(hintText: 'e.g. Morning Grinders'),
      ),
      const SizedBox(height: Spacing.s8),
      Text("You'll be the owner. Up to 10 members can join with a 6-digit code.",
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: Spacing.s20),
      OutlinedButton(
        onPressed: _busy ? null : _create,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.squadBlue,
          side: const BorderSide(color: AppColors.squadBlue, width: 1.5),
        ),
        child: Text(_busy ? 'Creating…' : 'Create squad'),
      ),
    ]);
  }

  Widget _success(Squad s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: Spacing.s8),
      const Icon(LucideIcons.checkCircle2,
          color: AppColors.statusHit, size: 48),
      const SizedBox(height: Spacing.s12),
      Center(child: Text(s.name, style: AppText.titleL)),
      const SizedBox(height: Spacing.s20),
      Column(children: [
        Text('INVITE CODE', style: AppText.caption),
        const SizedBox(height: Spacing.s8),
        Text(s.inviteCode,
            textAlign: TextAlign.center,
            style: AppText.displayL.copyWith(letterSpacing: 6)),
        const SizedBox(height: Spacing.s4),
        Text('Valid for 7 days', style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s16),
      OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _shareText(s)));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite copied to clipboard')));
        },
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.squadBlue,
            side: const BorderSide(color: AppColors.squadBlue, width: 1.5)),
        icon: const Icon(LucideIcons.copy, size: 18),
        label: const Text('Copy invite'),
      ),
      const SizedBox(height: Spacing.s12),
      OutlinedButton(
        onPressed: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => SquadHomeScreen(squadId: s.id))),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.squadBlue,
            side: const BorderSide(color: AppColors.squadBlue, width: 1.5)),
        child: const Text('Go to squad'),
      ),
    ]);
  }
}
