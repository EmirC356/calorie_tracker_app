import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_theme.dart';
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
      appBar: AppBar(
        title: const Text('CREATE SQUAD'),
        titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _created == null ? _form() : _success(_created!),
      ),
    );
  }

  Widget _form() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('SQUAD NAME', style: neonLabel(kNavy, size: 12)),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        maxLength: 30,
        style: const TextStyle(color: kText),
        decoration: const InputDecoration(hintText: 'e.g. Morning Grinders'),
      ),
      const SizedBox(height: 8),
      const Text('You\'ll be the owner. Up to 10 members can join with a 6-digit code.',
          style: TextStyle(color: kTextDim, fontSize: 12)),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _busy ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: kNavy, foregroundColor: kWhite,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(_busy ? 'CREATING...' : 'CREATE SQUAD',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    ]);
  }

  Widget _success(Squad s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      const Icon(Icons.check_circle, color: kNavy, size: 48),
      const SizedBox(height: 12),
      Center(child: Text(s.name, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold))),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: neonBox(kNavy),
        child: Column(children: [
          Text('INVITE CODE', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 8),
          Text(s.inviteCode,
              style: const TextStyle(color: kWhite, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 6)),
          const SizedBox(height: 4),
          const Text('Valid for 7 days', style: TextStyle(color: kTextDim, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _shareText(s)));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite copied to clipboard')));
        },
        style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy),
            padding: const EdgeInsets.symmetric(vertical: 14)),
        icon: const Icon(Icons.copy),
        label: const Text('COPY INVITE'),
      ),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => SquadHomeScreen(squadId: s.id))),
        style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('GO TO SQUAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    ]);
  }
}
