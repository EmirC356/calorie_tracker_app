import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../providers/photo_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../ui/member_avatar.dart';

/// A square proof-photo thumbnail: the (thumb) image, the uploader's avatar
/// bottom-right, an optional goal-category dot, and a dashed-amber treatment
/// while the photo is still in its own undo window. Hero-tagged for the detail
/// transition.
class PhotoThumbnail extends StatefulWidget {
  final Photo photo;
  final double size;
  final VoidCallback? onTap;

  /// Image-only (no avatar / goal dot / pending border) — for the camera-FAB
  /// preview badge.
  final bool bare;
  const PhotoThumbnail({
    super.key,
    required this.photo,
    this.size = 64,
    this.onTap,
    this.bare = false,
  });

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  String? _url;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didUpdateWidget(PhotoThumbnail old) {
    super.didUpdateWidget(old);
    if (old.photo.displayPath != widget.photo.displayPath) {
      _url = null;
      _resolve();
    }
  }

  void _resolve() {
    if (!mounted || widget.photo.localBytes != null) return;
    final path = widget.photo.displayPath;
    if (path.isEmpty) return;
    context.read<PhotoProvider>().service.downloadUrl(path).then((u) {
      if (mounted) setState(() => _url = u);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photo;
    final pending = p.isPending;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: (pending && !widget.bare)
              ? Border.all(color: AppColors.calendarAmber, width: 1.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          _image(p),
          if (!widget.bare) ...[
            // Uploader avatar, bottom-right.
            Positioned(
              bottom: 2, right: 2,
              child: Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: AppColors.surface0, width: 1)),
                child: MemberAvatar(
                  photoURL: p.uploadedByPhotoURL.isNotEmpty ? p.uploadedByPhotoURL : null,
                  displayName: p.uploadedByName.isNotEmpty ? p.uploadedByName : 'You',
                  size: 20,
                ),
              ),
            ),
            // Goal-category dot, top-right.
            if (p.goalRef != null)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(p.goalRef!.colorArgb)),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _image(Photo p) {
    if (p.localBytes != null) {
      return Image.memory(p.localBytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    if (_url != null) {
      return Image.network(_url!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return const ColoredBox(color: AppColors.surface2);
  }
}
