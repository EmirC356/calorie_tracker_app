import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photo_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/member_avatar.dart';

/// Opens a member's photos as a full-screen, one-at-a-time story.
Future<void> showPhotoStory(BuildContext context, String squadId,
        {required String uploaderUid, required String name, String? photoURL}) =>
    Navigator.push(context, MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoStoryViewer(
          squadId: squadId, uploaderUid: uploaderUid, name: name, photoURL: photoURL),
    ));

/// Snapchat/Instagram-story-style viewer of one member's shared photos: tap the
/// right half to advance, the left half to go back, swipe down (or X) to close.
class PhotoStoryViewer extends StatefulWidget {
  final String squadId;
  final String uploaderUid;
  final String name;
  final String? photoURL;
  const PhotoStoryViewer({
    super.key,
    required this.squadId,
    required this.uploaderUid,
    required this.name,
    this.photoURL,
  });

  @override
  State<PhotoStoryViewer> createState() => _PhotoStoryViewerState();
}

class _PhotoStoryViewerState extends State<PhotoStoryViewer> {
  StreamSubscription<List<Photo>>? _sub;
  List<Photo> _photos = const [];
  bool _loaded = false;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    final service = context.read<PhotoProvider>().service;
    _sub = service.streamForUser(widget.squadId, widget.uploaderUid).listen((list) {
      if (!mounted) return;
      setState(() {
        _photos = list;
        _loaded = true;
        if (_i >= list.length) _i = list.isEmpty ? 0 : list.length - 1;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _next() {
    if (_i < _photos.length - 1) {
      setState(() => _i++);
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
  }

  Future<void> _delete(Photo p) async {
    final service = context.read<PhotoProvider>().service;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('It will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.statusMissed))),
        ],
      ),
    );
    if (ok == true) {
      await service.deletePhoto(widget.squadId, p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_photos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Center(
            child: Text('No photos yet', style: AppText.bodyL.copyWith(color: Colors.white70)),
          ),
          _closeButton(),
        ]),
      );
    }

    final p = _photos[_i];
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    final isMine = p.uploadedByUid == myUid;
    final service = context.read<PhotoProvider>().service;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 250) Navigator.pop(context);
        },
        child: Stack(children: [
          // Image.
          Positioned.fill(
            child: Hero(
              tag: 'photo_${p.id}',
              child: p.localBytes != null
                  ? Image.memory(p.localBytes!, fit: BoxFit.contain)
                  : FutureBuilder<String>(
                      future: service.downloadUrl(p.storagePath),
                      builder: (_, snap) => snap.hasData
                          ? Image.network(snap.data!, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(LucideIcons.imageOff, color: Colors.white38, size: 48)),
                              loadingBuilder: (_, child, prog) => prog == null
                                  ? child
                                  : const Center(child: CircularProgressIndicator(color: Colors.white)))
                          : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
            ),
          ),
          // Top gradient + progress segments + header.
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent]),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.s8, Spacing.s8, Spacing.s8, 0),
                    child: Row(children: [
                      for (var k = 0; k < _photos.length; k++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: k <= _i ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.s12, Spacing.s8, Spacing.s8, Spacing.s8),
                    child: Row(children: [
                      MemberAvatar(
                          photoURL: widget.photoURL, displayName: widget.name, size: 32),
                      const SizedBox(width: Spacing.s8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.name,
                              style: AppText.titleM.copyWith(color: Colors.white)),
                          if (p.uploadedAt != null)
                            Text(_ago(p.uploadedAt!),
                                style: AppText.caption.copyWith(color: Colors.white70)),
                        ]),
                      ),
                      if (isMine)
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                          onPressed: () => _delete(p),
                        ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          // Goal chip, if attached.
          if (p.goalRef != null)
            Positioned(
              left: Spacing.s16, right: Spacing.s16, bottom: Spacing.s24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Color(p.goalRef!.colorArgb))),
                    const SizedBox(width: Spacing.s8),
                    Text(p.goalRef!.title,
                        style: AppText.bodyS.copyWith(color: Colors.white)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _closeButton() => SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}
