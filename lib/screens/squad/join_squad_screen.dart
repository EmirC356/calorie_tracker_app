import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_theme.dart';
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
      appBar: AppBar(
        title: const Text('JOIN SQUAD'),
        titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('6-DIGIT INVITE CODE', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            textAlign: TextAlign.center,
            style: const TextStyle(color: kWhite, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 10),
            decoration: const InputDecoration(hintText: '000000', counterText: ''),
          ),
          const SizedBox(height: 8),
          const Text('Ask a squad member for the code shown on their squad screen.',
              style: TextStyle(color: kTextDim, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _join,
            style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_busy ? 'JOINING...' : 'JOIN SQUAD',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}
