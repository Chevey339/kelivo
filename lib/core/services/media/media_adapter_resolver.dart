import '../../models/media_creation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import 'adapters/ark_images.dart';
import 'adapters/ark_video.dart';
import 'adapters/dashscope_images.dart';
import 'adapters/dashscope_video.dart';
import 'adapters/fal_media.dart';
import 'adapters/gemini_images.dart';
import 'adapters/openai_images.dart';
import 'adapters/openai_videos.dart';
import 'adapters/siliconflow_images.dart';
import 'adapters/siliconflow_video.dart';
import 'adapters/veo_video.dart';
import 'adapters/xai_media.dart';
import 'media_adapter.dart';
import 'media_model_overrides.dart';
import 'media_request.dart';

class MediaAdapterResolver {
  const MediaAdapterResolver();

  MediaAdapter? resolve(
    ProviderConfig provider,
    MediaMode mode, {
    String? modelId,
  }) {
    final video = mode == MediaMode.video;
    final oauth = provider.oauthProvider;
    if (oauth != null) {
      return switch (oauth) {
        OAuthProvider.chatgpt when !video => const OpenAiImagesAdapter(),
        OAuthProvider.grok =>
          video ? const XaiVideoAdapter() : const XaiImageAdapter(),
        _ => null,
      };
    }
    final kind = ProviderConfig.classify(
      provider.id,
      explicitType: provider.providerType,
    );
    if (kind == ProviderKind.claude) return null;
    final host = Uri.tryParse(provider.baseUrl)?.host ?? '';
    final key = provider.id.toLowerCase();
    if (provider.isFal || host == 'queue.fal.run') {
      final model = modelId == null
          ? null
          : FalMediaAdapter.knownModel(provider, modelId);
      return model == null || model.video == video
          ? FalMediaAdapter(mode)
          : null;
    }
    if (key == 'grok' || host == 'api.x.ai') {
      return video ? const XaiVideoAdapter() : const XaiImageAdapter();
    }
    if (key == 'bytedance' || host.endsWith('.volces.com')) {
      return video ? const ArkVideoAdapter() : const ArkImagesAdapter();
    }
    // TokenDance lists DashScope for both generation and editing on these
    // models. Its OpenAI compatibility endpoint supports generation only.
    if (!video &&
        (host == 'tokendance.space' || host == 'www.tokendance.space') &&
        modelId != null &&
        const {
          'qwen-image-2.1-pro',
          'qwen-image-2.1-turbo',
        }.contains(apiModelId(provider, modelId).toLowerCase())) {
      return const DashScopeImagesAdapter(apiPath: '/gateway/alibaba/api/v1');
    }
    if (key == 'aliyun' ||
        host.startsWith('dashscope') && host.endsWith('.aliyuncs.com') ||
        host.endsWith('.maas.aliyuncs.com')) {
      return video
          ? const DashScopeVideoAdapter()
          : const DashScopeImagesAdapter();
    }
    if (key == 'siliconflow' ||
        host == 'api.siliconflow.cn' ||
        host == 'api.siliconflow.com') {
      return video
          ? const SiliconFlowVideoAdapter()
          : const SiliconFlowImagesAdapter();
    }
    if (kind == ProviderKind.google) {
      final publicApi =
          host == 'generativelanguage.googleapis.com' &&
          provider.vertexAI != true;
      if (video) {
        return !publicApi && (host.isNotEmpty || provider.vertexAI == true)
            ? const VeoVideoAdapter()
            : null;
      }
      if (modelId != null) {
        final upstream = GeminiImagesAdapter.modelName(provider, modelId);
        if ((publicApi && GeminiImagesAdapter.isImagen(upstream)) ||
            (provider.vertexAI == true &&
                GeminiImagesAdapter.retiredOnVertex(upstream))) {
          return null;
        }
      }
      return const GeminiImagesAdapter();
    }
    if (video) {
      return host.isNotEmpty && host != 'api.openai.com'
          ? const OpenAiVideosAdapter()
          : null;
    }
    return const OpenAiImagesAdapter();
  }

  MediaCapabilities? capabilities(
    ProviderConfig provider,
    MediaMode mode,
    String modelId,
  ) {
    final base = resolve(
      provider,
      mode,
      modelId: modelId,
    )?.capabilities(provider, modelId);
    return base == null
        ? null
        : overrides(
            provider,
            modelId,
          ).apply(base, video: mode == MediaMode.video);
  }

  static MediaModelOverrides overrides(
    ProviderConfig provider,
    String modelId,
  ) {
    final raw = provider.modelOverrides[modelId];
    return MediaModelOverrides.fromJson(raw is Map ? raw['media'] : null);
  }

  bool hasModelData(ProviderConfig provider, MediaMode mode, String modelId) {
    final adapter = resolve(provider, mode, modelId: modelId);
    final id = apiModelId(provider, modelId).toLowerCase();
    return switch (adapter) {
      FalMediaAdapter() =>
        FalMediaAdapter.knownModel(provider, modelId) != null,
      OpenAiImagesAdapter() =>
        id.startsWith('gpt-image-') || id.startsWith('dall-e-'),
      OpenAiVideosAdapter() => id.startsWith('sora-'),
      XaiImageAdapter() || XaiVideoAdapter() => id.startsWith('grok-imagine-'),
      GeminiImagesAdapter() =>
        id.contains('imagen-') ||
            id.startsWith('gemini-') && id.contains('-image'),
      VeoVideoAdapter() => id.startsWith('veo-'),
      ArkImagesAdapter() => id.contains('seedream-'),
      ArkVideoAdapter() => id.contains('seedance-'),
      DashScopeImagesAdapter() =>
        id.startsWith('wan') || id.startsWith('qwen-image'),
      DashScopeVideoAdapter() => id.startsWith('wan'),
      SiliconFlowImagesAdapter() =>
        id.contains('kolors') || id.contains('qwen-image'),
      SiliconFlowVideoAdapter() =>
        id.contains('minimax-h3') || id.contains('wan'),
      _ => false,
    };
  }
}
