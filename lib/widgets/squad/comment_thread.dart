import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

/// Comment thread + composer at the foot of a member's day detail. Words, not
/// emoji. ≤200 chars, ≤5 per person per day (rules-enforced; surfaced on reject).
///
/// Styled per the canon: 24px MemberAvatars, bodyM text, caption timestamps in
/// textTertiary, no card backgrounds.
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
      backgroundColor: AppColors.surface3,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (canEdit)
          ListTile(
              leading: const Icon(LucideIcons.pencil,
                  color: AppColors.textPrimary, size: 20),
              title: Text('Edit', style: AppText.bodyL),
              onTap: () => Navigator.pop(ctx, 'edit')),
        ListTile(
            leading: const Icon(LucideIcons.trash2,
                color: AppColors.statusMissed, size: 20),
            title: Text('Delete',
                style: AppText.bodyL.copyWith(color: AppColors.statusMissed)),
            onTap: () => Navigator.pop(ctx, 'delete')),
      ]),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await service.deleteComment(widget.squadId, widget.dateKey, c.id);
    } else if (action == 'edit') {
      _ctrl.text = c.text;
      final edited = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit comment'),
          content: TextField(controller: _ctrl, maxLength: 200, style: AppText.bodyM),
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
      Text('COMMENTS', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      StreamBuilder<List<SquadComment>>(
        stream: service.watchComments(widget.squadId, widget.dateKey, widget.toUid),
        builder: (context, snap) {
          final comments = snap.data ?? const <SquadComment>[];
          if (comments.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
              child: Text('No comments yet — say something.',
                  style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
            );
          }
          return Column(children: [for (final c in comments) _comment(c)]);
        },
      ),
      const SizedBox(height: Spacing.s8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl, maxLength: 200, minLines: 1, maxLines: 3,
            style: AppText.bodyM,
            decoration: const InputDecoration(hintText: 'Write a comment…', isDense: true),
          ),
        ),
        const SizedBox(width: Spacing.s8),
        _sending
            ? const Padding(
                padding: EdgeInsets.all(Spacing.s12),
                child: ShimmerPlaceholder(
                    width: 20, height: 20, radius: AppRadius.pill),
              )
            : IconButton(
                icon: const Icon(LucideIcons.send, color: AppColors.squadBlue),
                onPressed: _send,
              ),
      ]),
    ]);
  }

  /// Flat comment row: 24px avatar, name + caption timestamp, bodyM text.
  Widget _comment(SquadComment c) {
    final mine = c.fromUid == widget.myUid;
    return GestureDetector(
      onLongPress: () => _manage(c),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.s12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MemberAvatar(displayName: mine ? widget.myName : c.fromName, size: 24),
          const SizedBox(width: Spacing.s8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(mine ? 'You' : c.fromName,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyS),
                ),
                const SizedBox(width: Spacing.s8),
                if (c.createdAt != null)
                  Text(
                    DateFormat('MMM d, HH:mm').format(c.createdAt!).toUpperCase(),
                    style: AppText.caption.copyWith(color: AppColors.textTertiary),
                  ),
                if (c.isEdited && !c.isDeleted) ...[
                  const SizedBox(width: Spacing.s8),
                  Text('EDITED',
                      style: AppText.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ]),
              const SizedBox(height: Spacing.s4),
              Text(
                c.displayText,
                style: AppText.bodyM.copyWith(
                  color: c.isDeleted
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontStyle: c.isDeleted ? FontStyle.italic : null,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
