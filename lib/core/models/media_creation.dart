enum MediaMode { image, video }

enum GenerationTitleSource { auto, prompt, manual }

enum GenerationStatus {
  queued,
  running,
  downloading,
  succeeded,
  partial,
  failed,
  cancelled,
  interrupted;

  bool get isActive => this == queued || this == running || this == downloading;
}

enum GenerationSource { workbench, edit, chat }

enum GenerationItemStatus { pending, ready, failed }

enum CreationTopicView { coverAndTitle, covers, list }

enum CreationGalleryFilter { all, images, videos, favorites }

enum RecentImageSource { all, creation, chat }

class RecentMediaImage {
  const RecentMediaImage({
    required this.path,
    required this.title,
    required this.source,
    this.thumbnailPath,
  });

  final String path, title;
  final RecentImageSource source;
  final String? thumbnailPath;
}
