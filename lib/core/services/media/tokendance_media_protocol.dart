import '../../models/media_creation.dart';
import 'gemini_media_models.dart';

/// TokenDance's /models rows advertise wire protocols, independently of the
/// chat API configured for the same gateway. Prefer native editing protocols.
enum TokenDanceMediaProtocol {
  arkImage(MediaMode.image, 'ark:image-generations'),
  dashScopeImage(MediaMode.image, 'dashscope:multimodal-generation'),
  klingImage(MediaMode.image, 'kling:image-generation'),
  klingLongImage(MediaMode.image, 'kling:long-image-generation'),
  geminiImage(MediaMode.image, 'gemini:generate-content'),
  chatCompletionsImage(MediaMode.image, 'openai:chat-completions'),
  openAiEdit(MediaMode.image, 'openai:image-edits'),
  openAiImage(MediaMode.image, 'openai:image-generations'),
  miniMax(MediaMode.video, 'minimax:video_generation_v2'),
  seedance(MediaMode.video, 'seedance:generations'),
  wan(MediaMode.video, 'wan3:video-synthesis'),
  happyHorse(MediaMode.video, 'happyhorse:video-synthesis'),
  klingV2(MediaMode.video, 'kling:text2video-v2'),
  klingV1(MediaMode.video, 'kling:text2video'),
  klingOmni(MediaMode.video, 'kling:omni-video'),
  xaiVideo(MediaMode.video, 'xai:video-generations'),
  nonMedia(null, ''),
  unsupported(null, '');

  const TokenDanceMediaProtocol(this.mode, this.wireName);
  final MediaMode? mode;
  final String wireName;

  bool get chatImage => this == geminiImage || this == chatCompletionsImage;

  static bool isHost(String? host) =>
      host == 'tokendance.space' || host == 'www.tokendance.space';

  static TokenDanceMediaProtocol? advertised(String model, Object? protocols) {
    if (protocols is! List) return null;
    for (final protocol in values) {
      if (protocol.wireName.isEmpty || !protocols.contains(protocol.wireName)) {
        continue;
      }
      if (protocol.chatImage && !isGeminiImageModel(model)) continue;
      // Speech recognition shares the DashScope endpoint. HappyHorse edits
      // and multi-subject references need inputs beyond the frame composer.
      if (protocol == dashScopeImage &&
          !model.startsWith('qwen-image') &&
          !model.startsWith('wan')) {
        continue;
      }
      if (protocol == happyHorse &&
          !(model.endsWith('-t2v') || model.endsWith('-i2v'))) {
        continue;
      }
      return protocol;
    }
    return protocols.any(
          const {
            'openai:chat-completions',
            'openai:responses',
            'openai:embeddings',
            'anthropic:messages',
            'gemini:generate-content',
          }.contains,
        )
        ? nonMedia
        : unsupported;
  }

  /// Also resolve existing configurations and models added by hand, before a
  /// catalog refresh. Do not send an unknown video to the Sora endpoint.
  static TokenDanceMediaProtocol? known(String id) => switch (id
      .toLowerCase()) {
    'minimax-h3' || 'minimax-h3-max' => miniMax,
    'kling-image-4.0' => klingImage,
    'kling-image-4.0-long-image' => klingLongImage,
    'kling-4.0' || 'kling-4.0-flash' => klingV2,
    'kling-3.0' || 'kling-3.0-turbo' => klingV1,
    'kling-3.0-omni' => klingOmni,
    'wan3.0-video' || 'wan3.0-video-prime' => wan,
    'qwen-image-2.1-pro' || 'qwen-image-2.1-turbo' => dashScopeImage,
    'seedream-5.0-lite' ||
    'seedream-5.0-pro' ||
    'seedream-5.0-flash' ||
    'seedream-5.5' => arkImage,
    'seedance-2.0' ||
    'seedance-2.0-fast' ||
    'seedance-2.0-mini' ||
    'seedance-2.5' ||
    'seedance-2.5-flash' => seedance,
    'happyhorse-1.0-t2v' ||
    'happyhorse-1.0-i2v' ||
    'happyhorse-1.1-t2v' ||
    'happyhorse-1.1-i2v' => happyHorse,
    'grok-imagine-video' => xaiVideo,
    'kling-tts' || 'kling-avatar-image2video' || 'kling-effects' => unsupported,
    final model when isGeminiImageModel(model) => geminiImage,
    final model when model.startsWith('gpt-image-') => openAiEdit,
    _ => null,
  };
}
