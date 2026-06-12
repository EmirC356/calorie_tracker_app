import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/date_helpers.dart';
import '../../models/goal_occurrence.dart';
import '../../models/photo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/photo_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/squad/squad_picker_sheet.dart';
import '../../widgets/squad/goal_attach_sheet.dart';

/// Result returned when the camera dismisses after a capture.
class PhotoSent {
  final String photoId;
  final String squadId;
  final PhotoGoalRef? goalRef;

  /// Finish-mode extras: the sibling group (for multi-squad undo), the
  /// occurrence's proof refs, and per-squad success/total counts.
  final String? siblingGroupId;
  final List<Map<String, dynamic>>? proofPhotoIds;
  final int successCount;
  final int totalCount;

  /// The user chose "Mark done without photo" from the permission screen — the
  /// goal should be marked done with no proof.
  final bool noPhoto;
  const PhotoSent({
    required this.photoId,
    required this.squadId,
    this.goalRef,
    this.siblingGroupId,
    this.proofPhotoIds,
    this.successCount = 1,
    this.totalCount = 1,
    this.noPhoto = false,
  });

  bool get isPersonal => squadId.isEmpty && siblingGroupId == null;
}

/// Full-screen camera for the Proof feature. Back camera + flash-auto by
/// default. Three modes: normal single-squad (squadId), a locked multi-squad
/// "Finish" ([lockedSquadIds] non-empty), or personal proof ([lockedSquadIds]
/// empty). In a locked mode the goal can't be detached and the squad isn't
/// editable.
class CameraScreen extends StatefulWidget {
  final String squadId;
  final PhotoGoalRef? defaultGoalRef;
  final List<String>? lockedSquadIds;
  const CameraScreen({
    super.key,
    required this.squadId,
    this.defaultGoalRef,
    this.lockedSquadIds,
  });

  static Route<PhotoSent> route({required String squadId, PhotoGoalRef? goalRef}) =>
      MaterialPageRoute<PhotoSent>(
          builder: (_) => CameraScreen(squadId: squadId, defaultGoalRef: goalRef));

  /// Finish mode: share to [squadIds] (empty = personal proof), goal locked.
  static Route<PhotoSent> finishRoute({
    required List<String> squadIds,
    required PhotoGoalRef goalRef,
  }) =>
      MaterialPageRoute<PhotoSent>(
        builder: (_) => CameraScreen(
          squadId: squadIds.isNotEmpty ? squadIds.first : '',
          defaultGoalRef: goalRef,
          lockedSquadIds: squadIds,
        ),
      );

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _camIndex = 0;
  FlashMode _flash = FlashMode.auto;
  bool _ready = false;
  bool _denied = false;
  bool _capturing = false;
  late String _squadId;
  PhotoGoalRef? _goalRef;

  @override
  void initState() {
    super.initState();
    _squadId = widget.squadId;
    _goalRef = widget.defaultGoalRef;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _denied = true);
        return;
      }
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back >= 0 ? back : 0;
      await _start();
    } on CameraException {
      if (mounted) setState(() => _denied = true);
    }
  }

  Future<void> _start() async {
    final ctrl = CameraController(_cameras[_camIndex], ResolutionPreset.high, enableAudio: false);
    await ctrl.initialize();
    try {
      await ctrl.setFlashMode(_flash);
    } catch (_) {/* some devices reject flash on the front lens */}
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    setState(() {
      _controller = ctrl;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    setState(() => _ready = false);
    await _controller?.dispose();
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _start();
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.auto, FlashMode.always, FlashMode.off];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {}
  }

  IconData get _flashIcon => switch (_flash) {
        FlashMode.always => LucideIcons.zap,
        FlashMode.off => LucideIcons.zapOff,
        _ => LucideIcons.zap, // auto
      };

  List<PhotoGoalRef> _todaysOpenGoals() {
    final today = dateOnly(DateTime.now());
    return context
        .read<GoalProvider>()
        .occurrencesOn(today)
        .where((e) => e.row == null || e.row!.status == OccurrenceStatus.open)
        .map((e) => PhotoGoalRef(
              goalId: e.goal.id?.toString() ?? '',
              occurrenceDate: ymd(today),
              title: e.goal.title,
              category: e.goal.categoryLabel,
              colorArgb: e.goal.color.toARGB32(),
            ))
        .toList();
  }

  Future<void> _pickSquad() async {
    final squads = context.read<SquadProvider>().squads;
    final chosen = await SquadPickerSheet.show(context, squads: squads, selectedId: _squadId);
    if (chosen != null && mounted) setState(() => _squadId = chosen);
  }

  Future<void> _attachGoal() async {
    final goals = _todaysOpenGoals();
    final chosen = await GoalAttachSheet.show(context, goals: goals);
    if (chosen != null && mounted) setState(() => _goalRef = chosen);
  }

  Future<void> _shutter() async {
    if (!_ready || _capturing || _controller == null) return;
    setState(() => _capturing = true);
    HapticFeedback.lightImpact();
    // Capture everything that needs `context` before any await.
    final photoP = context.read<PhotoProvider>();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = photoP.service;
    final squadId = _squadId;
    final goalRef = _goalRef;
    final locked = widget.lockedSquadIds;
    final name = auth.appUser?.displayName;
    final photoUrl = auth.appUser?.photoURL;
    String? id;
    try {
      final file = await _controller!.takePicture();
      final raw = await file.readAsBytes();
      final bytes = await service.compressForUpload(raw);

      // ── Finish mode: multi-squad fan-out or personal proof ──────────────────
      if (locked != null) {
        if (locked.isEmpty) {
          final pid = await service.uploadPersonalProof(bytes: bytes, goalRef: goalRef!);
          navigator.pop(PhotoSent(
            photoId: pid, squadId: '', goalRef: goalRef,
            proofPhotoIds: [{'personal': true, 'photoId': pid}],
            successCount: 1, totalCount: 1,
          ));
        } else {
          final r = await service.uploadPhotoToSquads(
              squadIds: locked, bytes: bytes, goalRef: goalRef,
              uploaderName: name, uploaderPhotoURL: photoUrl);
          if (!r.anySucceeded) throw Exception('all squad uploads failed');
          final first = r.uploaded.first;
          navigator.pop(PhotoSent(
            photoId: first.photoId, squadId: first.squadId, goalRef: goalRef,
            siblingGroupId: r.siblingGroupId,
            proofPhotoIds: r.photoIdPairs,
            successCount: r.successCount, totalCount: r.totalCount,
          ));
        }
        return;
      }

      // ── Normal mode: single squad, optimistic ──────────────────────────────
      id = service.newPhotoId(squadId);
      photoP.addOptimisticPhoto(Photo(
        id: id,
        uploadedByUid: auth.firebaseUser?.uid ?? '',
        uploadedByName: name ?? 'You',
        uploadedByPhotoURL: photoUrl ?? '',
        uploadedAt: DateTime.now(),
        optimistic: true,
        localBytes: raw,
        goalRef: goalRef,
      ));
      await service.uploadPhoto(
        squadId: squadId, bytes: bytes, goalRef: goalRef, photoId: id,
        uploaderName: name, uploaderPhotoURL: photoUrl,
      );
      navigator.pop(PhotoSent(photoId: id, squadId: squadId, goalRef: goalRef));
    } catch (e) {
      if (id != null) photoP.removeOptimisticPhoto(id);
      if (mounted) setState(() => _capturing = false);
      messenger.showSnackBar(SnackBar(
          content: Text('Upload failed: $e'), duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_denied) return _permissionScreen();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_ready && _controller != null)
          _preview()
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        _overlay(),
      ]),
    );
  }

  Widget _preview() {
    final c = _controller!;
    return LayoutBuilder(builder: (ctx, box) {
      var scale = (box.maxWidth / box.maxHeight) * c.value.aspectRatio;
      if (scale < 1) scale = 1 / scale;
      return ClipRect(
        child: Transform.scale(scale: scale, child: Center(child: CameraPreview(c))),
      );
    });
  }

  Widget _overlay() {
    final squads = context.watch<SquadProvider>().squads;
    final match = squads.where((s) => s.id == _squadId);
    final squadName = match.isNotEmpty ? match.first.name : 'Squad';
    return SafeArea(
      child: Stack(children: [
        // Top-left: close.
        Positioned(
          top: Spacing.s8, left: Spacing.s8,
          child: _round(LucideIcons.x, () => Navigator.pop(context)),
        ),
        // Top-center: squad chip + (below) goal chip.
        Positioned(
          top: Spacing.s8, left: 0, right: 0,
          child: Column(children: [
            _squadChip(squadName),
            const SizedBox(height: Spacing.s8),
            _goalChip(),
          ]),
        ),
        // Top-right: flash.
        Positioned(
          top: Spacing.s8, right: Spacing.s8,
          child: _round(_flashIcon, _cycleFlash),
        ),
        // Bottom row: gallery · shutter · flip.
        Positioned(
          bottom: Spacing.s24, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _round(LucideIcons.image, () => Navigator.pop(context)),
            _shutterButton(),
            _round(LucideIcons.refreshCw, _flip),
          ]),
        ),
      ]),
    );
  }

  Widget _squadChip(String squadName) {
    final locked = widget.lockedSquadIds;
    if (locked == null) return _chip(label: '$squadName ▾', onTap: _pickSquad);
    if (locked.isEmpty) return _chip(label: 'Personal proof — not shared', onTap: () {});
    final n = locked.length;
    return _chip(label: '📤 Sharing to $n squad${n == 1 ? '' : 's'}', onTap: _showLockedSquads);
  }

  void _showLockedSquads() {
    final squads = context.read<SquadProvider>().squads;
    final names = widget.lockedSquadIds!.map((id) {
      final m = squads.where((s) => s.id == id);
      return m.isNotEmpty ? m.first.name : 'Squad';
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.s16),
            child: Text('Sharing this proof to', style: AppText.caption),
          ),
          for (final name in names)
            ListTile(
              leading: const Icon(LucideIcons.users, color: AppColors.squadBlue, size: 20),
              title: Text(name, style: AppText.bodyL),
            ),
          const SizedBox(height: Spacing.s8),
        ]),
      ),
    );
  }

  Widget _goalChip() {
    final locked = widget.lockedSquadIds != null;
    if (_goalRef != null) {
      return _chip(
        label: _goalRef!.title,
        leadingColor: Color(_goalRef!.colorArgb),
        trailing: locked ? null : LucideIcons.x,
        onTap: locked ? () {} : () => setState(() => _goalRef = null),
      );
    }
    if (locked || _todaysOpenGoals().isEmpty) return const SizedBox.shrink();
    return _chip(label: '📎 Attach goal', onTap: _attachGoal, outlined: true);
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    Color? leadingColor,
    IconData? trailing,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: outlined ? Border.all(color: AppColors.squadBlue, width: 1.5) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leadingColor != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle)),
            const SizedBox(width: Spacing.s8),
          ],
          Text(label,
              style: AppText.bodyS.copyWith(
                  color: outlined ? AppColors.squadBlue : Colors.white,
                  fontWeight: FontWeight.w600)),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.s8),
            Icon(trailing, size: 14, color: Colors.white),
          ],
        ]),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(Spacing.s8), child: Icon(icon, color: Colors.white, size: 22)),
        ),
      );

  Widget _shutterButton() {
    // Finish-mode shutter is tinted statusHit to reinforce "this completes a goal".
    final tint = widget.lockedSquadIds != null ? AppColors.statusHit : Colors.white;
    return GestureDetector(
        onTap: _capturing ? null : _shutter,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _capturing ? tint.withValues(alpha: 0.5) : tint,
            border: Border.all(color: tint, width: 4),
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2)),
          ),
        ),
      );
  }

  Widget _permissionScreen() => Scaffold(
        backgroundColor: AppColors.surface0,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.s24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.cameraOff, color: AppColors.textTertiary, size: 64),
              const SizedBox(height: Spacing.s16),
              Text('Camera permission needed', style: AppText.displayM, textAlign: TextAlign.center),
              const SizedBox(height: Spacing.s8),
              Text(
                  widget.lockedSquadIds != null
                      ? 'Finish needs camera access to record proof. Enable it, or in '
                          'system Settings if you previously denied it.'
                      : 'Proof shares a quick photo with your squad. Enable camera access '
                          'to take one. If you previously denied it, turn it on in system Settings.',
                  style: AppText.bodyL.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: Spacing.s24),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.squadBlue, minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  setState(() => _denied = false);
                  _initCamera();
                },
                child: const Text('Try again'),
              ),
              const SizedBox(height: Spacing.s8),
              // Finish-mode escape hatch: mark the goal done without a photo.
              if (widget.lockedSquadIds != null)
                TextButton(
                  onPressed: () => Navigator.pop(
                      context, const PhotoSent(photoId: '', squadId: '', noPhoto: true)),
                  child: const Text('Mark done without photo'),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ]),
          ),
        ),
      );
}
