import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../providers/photo_provider.dart';
import '../../screens/squad/camera_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'photo_thumbnail.dart';

/// Pushes the camera for [squadId]; on a send, shows a brief confirmation.
/// Shared by the squad-home camera FAB. Photos ship immediately (no undo).
Future<void> launchProofCamera(BuildContext context, String squadId, {PhotoGoalRef? goalRef}) async {
  final result = await Navigator.push<PhotoSent>(
      context, CameraScreen.route(squadId: squadId, goalRef: goalRef));
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Shared with your squad'), duration: Duration(seconds: 2)));
  }
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
