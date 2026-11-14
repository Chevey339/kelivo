import '../../../core/models/image_upload_quality.dart';

/// Composer callbacks remain tied to attachment identity even when a path is
/// replaced by an edit or a quality change.
class ImageViewerDraftMode {
  const ImageViewerDraftMode({
    required this.onEdit,
    required this.qualityOf,
    required this.customQualityOf,
    required this.originalAvailable,
    required this.onQualityChanged,
  });
  final Future<bool> Function(int index) onEdit;
  final ImageUploadQuality Function(int index) qualityOf;
  final int Function(int index) customQualityOf;
  final bool Function(int index) originalAvailable;
  final Future<String> Function(
    int index,
    ImageUploadQuality quality,
    int? custom,
  )
  onQualityChanged;
}
