import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A goal occurrence a proof photo is attached to (denormalized onto the photo
/// doc so the feed/strip render without extra reads).
class PhotoGoalRef {
  final String goalId;
  final String occurrenceDate; // YYYY-MM-DD
  final String title;
  final String category;
  final int colorArgb;

  const PhotoGoalRef({
    required this.goalId,
    required this.occurrenceDate,
    required this.title,
    this.category = '',
    this.colorArgb = 0xFF3B82F6,
  });

  Map<String, dynamic> toMap() => {
        'goalId': goalId,
        'occurrenceDate': occurrenceDate,
        'title': title,
        'category': category,
        'colorArgb': colorArgb,
      };

  static PhotoGoalRef? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return PhotoGoalRef(
      goalId: (m['goalId'] as String?) ?? '',
      occurrenceDate: (m['occurrenceDate'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      colorArgb: (m['colorArgb'] as num?)?.toInt() ?? 0xFF3B82F6,
    );
  }
}

/// One proof photo (`squads/{squadId}/photos/{photoId}`).
///
/// Visibility: a viewer sees a photo when `deletedAt == null` AND
/// (`published` OR it is their own). Uploaders see their own pending photos
/// immediately; squadmates only after the 60s undo window promotes it. The
/// `published` boolean mirrors `publishedAt != null` and exists so the
/// squadmate query stays rules-compatible (see firestore.rules).
class Photo {
  final String id;
  final String uploadedByUid;
  final String uploadedByName;
  final String uploadedByPhotoURL;
  final String storagePath;
  final String? thumbStoragePath;
  final int width;
  final int height;
  final DateTime? uploadedAt;
  final DateTime? publishedAt;
  final DateTime? pendingPublishAt;
  final bool published;
  final PhotoGoalRef? goalRef;
  final Map<String, int> reactionCounts;
  final DateTime? deletedAt;

  /// True only for an in-memory optimistic placeholder not yet confirmed by the
  /// Firestore listener.
  final bool optimistic;

  /// Captured bytes held only for an optimistic placeholder so the strip can
  /// render the image instantly before upload completes. Never serialized.
  final Uint8List? localBytes;

  const Photo({
    required this.id,
    required this.uploadedByUid,
    this.uploadedByName = '',
    this.uploadedByPhotoURL = '',
    this.storagePath = '',
    this.thumbStoragePath,
    this.width = 0,
    this.height = 0,
    this.uploadedAt,
    this.publishedAt,
    this.pendingPublishAt,
    this.published = false,
    this.goalRef,
    this.reactionCounts = const {'fire': 0, 'flex': 0, 'clap': 0},
    this.deletedAt,
    this.optimistic = false,
    this.localBytes,
  });

  bool get isPending => !published && deletedAt == null;
  bool get isDeleted => deletedAt != null;

  /// The core visibility predicate used everywhere a photo could be shown.
  bool visibleTo(String? viewerUid) =>
      deletedAt == null && (published || uploadedByUid == viewerUid);

  int reactionCount(String emoji) => reactionCounts[emoji] ?? 0;

  /// Prefer the generated thumbnail; fall back to the full image during the
  /// brief window before the Cloud Function writes the thumb.
  String get displayPath => thumbStoragePath ?? storagePath;

  factory Photo.fromMap(String id, Map<String, dynamic> m) {
    final counts = (m['reactionCounts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Photo(
      id: id,
      uploadedByUid: (m['uploadedByUid'] as String?) ?? '',
      uploadedByName: (m['uploadedByName'] as String?) ?? '',
      uploadedByPhotoURL: (m['uploadedByPhotoURL'] as String?) ?? '',
      storagePath: (m['storagePath'] as String?) ?? '',
      thumbStoragePath: m['thumbStoragePath'] as String?,
      width: (m['width'] as num?)?.toInt() ?? 0,
      height: (m['height'] as num?)?.toInt() ?? 0,
      uploadedAt: (m['uploadedAt'] as Timestamp?)?.toDate(),
      publishedAt: (m['publishedAt'] as Timestamp?)?.toDate(),
      pendingPublishAt: (m['pendingPublishAt'] as Timestamp?)?.toDate(),
      published: (m['published'] as bool?) ?? (m['publishedAt'] != null),
      goalRef: PhotoGoalRef.fromMap((m['goalRef'] as Map?)?.cast<String, dynamic>()),
      reactionCounts: {
        'fire': (counts['fire'] as num?)?.toInt() ?? 0,
        'flex': (counts['flex'] as num?)?.toInt() ?? 0,
        'clap': (counts['clap'] as num?)?.toInt() ?? 0,
      },
      deletedAt: (m['deletedAt'] as Timestamp?)?.toDate(),
    );
  }
}
