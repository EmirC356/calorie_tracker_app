import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'squad_home_screen.dart';

class JoinSquadScreen extends StatefulWidget {
  const JoinSquadScreen({super.key});

  @override
  State<JoinSquadScreen> createState() => _JoinSquadScreenState();
}

class _JoinSquadScreenState extends State<JoinSquadScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final squad = await context.read<SquadProvider>().joinSquad(_code.text);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => SquadHomeScreen(squadId: squad.id)));
    } on SquadException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Squad')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.s20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('6-DIGIT INVITE CODE', style: AppText.caption),
          const SizedBox(height: Spacing.s12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            textAlign: TextAlign.center,
            style: AppText.displayL.copyWith(letterSpacing: 10),
            decoration: const InputDecoration(hintText: '000000', counterText: ''),
          ),
          const SizedBox(height: Spacing.s8),
          Text('Ask a squad member for the code shown on their squad screen.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: Spacing.s20),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.squadBlue,
              side: const BorderSide(color: AppColors.squadBlue, width: 1.5),
            ),
            child: Text(_busy ? 'Joining…' : 'Join squad'),
          ),
        ]),
      ),
    );
  }
}
