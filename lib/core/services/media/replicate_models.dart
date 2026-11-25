import '../../models/media_creation.dart';
import 'adapters/native_image_size.dart';
import 'media_request.dart';

/// Replicate official models share a predictions API, but have different inputs.
enum ReplicateMediaModel {
  fluxSchnell('black-forest-labs/flux-schnell'),
  fluxDev('black-forest-labs/flux-dev'),
  fluxKontext('black-forest-labs/flux-kontext-pro'),
  nanoBanana('google/nano-banana'),
  nanoBananaPro('google/nano-banana-pro'),
  seedancePro('bytedance/seedance-1-pro');

  const ReplicateMediaModel(this.id);
  final String id;

  static ReplicateMediaModel? find(String id) =>
      values.where((m) => m.id == id.toLowerCase()).firstOrNull;
  static bool isHost(String? host) => host == 'api.replicate.com';

  MediaMode get mode => this == seedancePro ? MediaMode.video : MediaMode.image;

  MediaCapabilities get capabilities => switch (this) {
    seedancePro => const MediaCapabilities(
      aspectRatios: ['auto', '16:9', '9:16', '1:1', '4:3', '3:4', '21:9'],
      durations: [5, 10],
      resolutions: ['480p', '1080p'],
      maxReferences: 2,
      frameRoles: [MediaReferenceRole.firstFrame, MediaReferenceRole.lastFrame],
      framesUseAutomaticRatio: true,
      supportsSeed: true,
    ),
    nanoBanana || nanoBananaPro => MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxReferences: this == nanoBananaPro ? 14 : 3,
      sizes: this == nanoBananaPro ? const ['1K', '2K', '4K'] : const [],
      formats: const ['png', 'jpeg'],
    ),
    fluxSchnell || fluxDev || fluxKontext => MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: this == fluxKontext ? 1 : 4,
      maxReferences: this == fluxSchnell ? 0 : 1,
      formats: this == fluxKontext ? const ['png', 'jpeg'] : imageFormats,
      supportsSeed: true,
    ),
  };
}
