import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../providers/photo_provider.dart';
import '../../services/photo_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Private gallery of proof photos for goals finished without a squad.
/// 3-column grid, month filter, tap → detail, long-press → delete.
class PersonalProofGalleryScreen extends StatefulWidget {
  const PersonalProofGalleryScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const PersonalProofGalleryScreen());

  @override
  State<PersonalProofGalleryScreen> createState() => _PersonalProofGalleryScreenState();
}

class _PersonalProofGalleryScreenState extends State<PersonalProofGalleryScreen> {
  String? _month; // 'yyyy-MM' or null = all

  static String _monthKey(DateTime? d) => DateFormat('yyyy-MM').format(d ?? DateTime.now());

  @override
  Widget build(BuildContext context) {
    final service = context.read<PhotoProvider>().service;
    return Scaffold(
      appBar: AppBar(title: const Text('Personal proof')),
      body: StreamBuilder<List<Photo>>(
        stream: service.streamPersonalProof(),
        builder: (context, snap) {
          final all = snap.data ?? const <Photo>[];
          if (all.isEmpty) {
            return snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : _emptyHero();
          }
          final months = <String>{for (final p in all) _monthKey(p.uploadedAt)}.toList()
            ..sort((a, b) => b.compareTo(a));
          final shown = _month == null
              ? all
              : all.where((p) => _monthKey(p.uploadedAt) == _month).toList();
          return Column(children: [
            _filterBar(months),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text('No proof this month',
                          style: AppText.bodyM.copyWith(color: AppColors.textTertiary)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(1),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _ProofImage(
                        photo: shown[i],
                        service: service,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute<void>(builder: (_) => _ProofDetail(photo: shown[i]))),
                        onLongPress: () => _confirmDelete(shown[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _filterBar(List<String> months) => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
          children: [
            _chip('All', _month == null, () => setState(() => _month = null)),
            for (final m in months)
              _chip(DateFormat('MMM yyyy').format(DateTime.parse('$m-01')), _month == m,
                  () => setState(() => _month = m)),
          ],
        ),
      );

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Spacing.s8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s12),
            decoration: BoxDecoration(
              color: active ? AppColors.calendarAmber : AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: active ? AppColors.calendarAmber : AppColors.surface2),
            ),
            child: Text(label,
                style: AppText.bodyS.copyWith(
                    color: active ? AppColors.surface0 : AppColors.textSecondary)),
          ),
        ),
      );

  Widget _emptyHero() => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.imageOff, color: AppColors.textTertiary, size: 64),
            const SizedBox(height: Spacing.s16),
            Text('No personal proof yet', style: AppText.displayM, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.s8),
            Text('Finish a private goal with a photo and it lands here.',
                style: AppText.bodyL.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Future<void> _confirmDelete(Photo p) async {
    final service = context.read<PhotoProvider>().service;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this proof?'),
        content: const Text('This removes the photo permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.statusMissed))),
        ],
      ),
    );
    if (ok == true) await service.deletePersonalProof(p.id);
  }
}

/// A grid cell — resolves the Storage URL once and shows the image.
class _ProofImage extends StatefulWidget {
  final Photo photo;
  final PhotoService service;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ProofImage(
      {required this.photo, required this.service, required this.onTap, required this.onLongPress});

  @override
  State<_ProofImage> createState() => _ProofImageState();
}

class _ProofImageState extends State<_ProofImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    widget.service.downloadUrl(widget.photo.storagePath).then((u) {
      if (mounted) setState(() => _url = u);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        color: AppColors.surface2,
        child: _url == null
            ? null
            : Image.network(_url!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(LucideIcons.imageOff, color: Colors.white24)),
      ),
    );
  }
}

class _ProofDetail extends StatelessWidget {
  final Photo photo;
  const _ProofDetail({required this.photo});

  @override
  Widget build(BuildContext context) {
    final service = context.read<PhotoProvider>().service;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            onPressed: () async {
              await service.deletePersonalProof(photo.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(children: [
        Expanded(
          child: Center(
            child: FutureBuilder<String>(
              future: service.downloadUrl(photo.storagePath),
              builder: (_, snap) => snap.hasData
                  ? Image.network(snap.data!, fit: BoxFit.contain)
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
        if (photo.goalRef != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.s16),
              child: Row(children: [
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Color(photo.goalRef!.colorArgb))),
                const SizedBox(width: Spacing.s8),
                Expanded(
                  child: Text(photo.goalRef!.title,
                      style: AppText.bodyL.copyWith(color: Colors.white)),
                ),
                if (photo.uploadedAt != null)
                  Text(DateFormat('MMM d').format(photo.uploadedAt!),
                      style: AppText.caption.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
      ]),
    );
  }
}
