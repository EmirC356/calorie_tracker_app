import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../providers/photo_provider.dart';
import '../../services/photo_service.dart';
import '../../screens/squad/camera_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'photo_thumbnail.dart';

/// Pushes the camera for [squadId], then (on a real send) shows the 60s undo
/// snackbar. Shared by the Today strip's +Camera tile and the squad-home FAB.
Future<void> launchProofCamera(BuildContext context, String squadId, {PhotoGoalRef? goalRef}) async {
  final service = context.read<PhotoProvider>().service;
  final result = await Navigator.push<PhotoSent>(
      context, CameraScreen.route(squadId: squadId, goalRef: goalRef));
  if (result != null && context.mounted) showProofUndoSnackbar(context, result, service);
}

/// "Sent · Undo (60)" — a counting-down snackbar. Tapping Undo soft-deletes the
/// still-pending photo (clean memory hole). Swiping it away is NOT an undo.
void showProofUndoSnackbar(BuildContext context, PhotoSent sent, PhotoService service) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 60),
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.surface2,
    content: const _UndoCountdown(),
    action: SnackBarAction(
      label: 'Undo',
      textColor: AppColors.calendarAmber,
      onPressed: () async {
        await service.undoPhoto(sent.squadId, sent.photoId);
        messenger.showSnackBar(const SnackBar(
            content: Text('Undone'), duration: Duration(seconds: 2)));
      },
    ),
  ));
}

class _UndoCountdown extends StatefulWidget {
  const _UndoCountdown();
  @override
  State<_UndoCountdown> createState() => _UndoCountdownState();
}

class _UndoCountdownState extends State<_UndoCountdown> {
  int _n = 60;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _n = (_n - 1).clamp(0, 60));
      if (_n <= 0) _t?.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Sent — undo (${_n}s)', style: AppText.bodyM);
}

/// Instagram-instant-style camera FAB: the blue camera button with a small
/// preview of the squad's most-recent photo tucked onto its top-right corner.
/// Tapping the button opens the camera; tapping the preview opens that photo.
class CameraFab extends StatefulWidget {
  final String squadId;
  const CameraFab({super.key, required this.squadId});

  @override
  State<CameraFab> createState() => _CameraFabState();
}

class _CameraFabState extends State<CameraFab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PhotoProvider>().bind(widget.squadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = context.watch<PhotoProvider>().recentPhotos;
    final latest = photos.isNotEmpty ? photos.first : null;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: 0, bottom: 0,
          child: FloatingActionButton(
            heroTag: 'proof-camera-fab',
            backgroundColor: AppColors.squadBlue,
            foregroundColor: AppColors.surface0,
            onPressed: () => launchProofCamera(context, widget.squadId),
            child: const Icon(LucideIcons.camera),
          ),
        ),
        if (latest != null)
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                  fullscreenDialog: true, builder: (_) => _FullPhotoView(photo: latest))),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: AppColors.surface0, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: PhotoThumbnail(photo: latest, size: 30, bare: true),
              ),
            ),
          ),
      ]),
    );
  }
}

class _FullPhotoView extends StatelessWidget {
  final Photo photo;
  const _FullPhotoView({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: Hero(
            tag: 'photo_${photo.id}',
            child: photo.localBytes != null
                ? Image.memory(photo.localBytes!, fit: BoxFit.contain)
                : FutureBuilder<String>(
                    future: context.read<PhotoProvider>().service.downloadUrl(photo.displayPath),
                    builder: (_, snap) => snap.hasData
                        ? Image.network(snap.data!, fit: BoxFit.contain)
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ]),
    );
  }
}
