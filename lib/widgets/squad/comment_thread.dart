import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';

/// Comment thread + composer at the foot of a member's day detail. Words, not
/// emoji. ≤200 chars, ≤5 per person per day (rules-enforced; surfaced on reject).
class CommentThread extends StatefulWidget {
  final String squadId;
  final String dateKey;
  final String toUid;
  final String myUid;
  final String myName;
  const CommentThread({
    super.key,
    required this.squadId,
    required this.dateKey,
    required this.toUid,
    required this.myUid,
    required this.myName,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final service = context.read<SquadProvider>().service;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await service.addComment(widget.squadId, widget.dateKey,
          fromUid: widget.myUid, fromName: widget.myName, toUid: widget.toUid, text: text);
      _ctrl.clear();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Comment limit reached for today (5).')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _manage(SquadComment c) async {
    if (c.fromUid != widget.myUid || c.isDeleted) return;
    final service = context.read<SquadProvider>().service;
    final canEdit = c.createdAt != null &&
        DateTime.now().difference(c.createdAt!) < const Duration(minutes: 5);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurface,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (canEdit)
          ListTile(leading: const Icon(Icons.edit, color: kNavy), title: const Text('Edit', style: TextStyle(color: kText)),
              onTap: () => Navigator.pop(ctx, 'edit')),
        ListTile(leading: const Icon(Icons.delete_outline, color: kNeonRed), title: const Text('Delete', style: TextStyle(color: kNeonRed)),
            onTap: () => Navigator.pop(ctx, 'delete')),
      ]),
    );
    if (action == 'delete') {
      await service.deleteComment(widget.squadId, widget.dateKey, c.id);
    } else if (action == 'edit') {
      _ctrl.text = c.text;
      final edited = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kSurface,
          title: const Text('Edit comment', style: TextStyle(color: kText, fontSize: 16)),
          content: TextField(controller: _ctrl, maxLength: 200, style: const TextStyle(color: kText)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(ctx, _ctrl.text.trim()), child: const Text('SAVE')),
          ],
        ),
      );
      _ctrl.clear();
      if (edited != null && edited.isNotEmpty) {
        await service.editComment(widget.squadId, widget.dateKey, c.id, edited);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('COMMENTS', style: neonLabel(kNavy, size: 12)),
      const SizedBox(height: 8),
      StreamBuilder<List<SquadComment>>(
        stream: service.watchComments(widget.squadId, widget.dateKey, widget.toUid),
        builder: (context, snap) {
          final comments = snap.data ?? const <SquadComment>[];
          if (comments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No comments yet — say something.', style: TextStyle(color: kTextDim, fontSize: 12)),
            );
          }
          return Column(children: [for (final c in comments) _bubble(c)]);
        },
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl, maxLength: 200, minLines: 1, maxLines: 3,
            style: const TextStyle(color: kText, fontSize: 13),
            decoration: const InputDecoration(hintText: 'Write a comment…', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kNavy))
              : const Icon(Icons.send, color: kNavy),
          onPressed: _send,
        ),
      ]),
    ]);
  }

  Widget _bubble(SquadComment c) {
    final mine = c.fromUid == widget.myUid;
    return GestureDetector(
      onLongPress: () => _manage(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mine ? kNavy.withValues(alpha: 0.5) : kBorderDim),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(mine ? 'You' : c.fromName, style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            if (c.createdAt != null)
              Text(DateFormat('MMM d, HH:mm').format(c.createdAt!), style: const TextStyle(color: kTextDim, fontSize: 10)),
          ]),
          const SizedBox(height: 3),
          Text(c.displayText,
              style: TextStyle(color: c.isDeleted ? kTextDim : kText, fontSize: 13, fontStyle: c.isDeleted ? FontStyle.italic : null)),
          if (c.isEdited && !c.isDeleted)
            const Text('edited', style: TextStyle(color: kTextDim, fontSize: 10)),
        ]),
      ),
    );
  }
}
