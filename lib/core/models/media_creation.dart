enum MediaMode { image, video }

enum CreationModelSlot {
  image('image_model_v1', MediaMode.image),
  video('video_model_v1', MediaMode.video),
  promptEnhance('prompt_enhance_model_v1', null);

  const CreationModelSlot(this.settingKey, this.mode);

  final String settingKey;
  final MediaMode? mode;
}

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
