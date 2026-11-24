import '../../models/media_creation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import '../model_spec/model_list_metadata_cache.dart';
import 'adapters/ark_images.dart';
import 'adapters/ark_video.dart';
import 'adapters/dashscope_images.dart';
import 'adapters/dashscope_video.dart';
import 'adapters/fal_media.dart';
import 'adapters/gemini_images.dart';
import 'adapters/kling_gateway.dart';
import 'adapters/minimax_video.dart';
import 'adapters/openai_images.dart';
import 'adapters/openai_videos.dart';
import 'adapters/openrouter_media.dart';
import 'adapters/siliconflow_images.dart';
import 'adapters/siliconflow_video.dart';
import 'adapters/veo_video.dart';
import 'adapters/xai_media.dart';
import 'media_adapter.dart';
import 'media_model_overrides.dart';
import 'media_request.dart';
import 'openrouter_media_catalog.dart';
import 'tokendance_media_protocol.dart';

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
    final host = Uri.tryParse(provider.baseUrl)?.host ?? '';
    if (OpenRouterMediaModel.isHost(host)) {
      final data = modelId == null
          ? null
          : ModelListMetadataCache.instance
                .lookup(provider, apiModelId(provider, modelId))
                ?.openRouterMedia;
      if (data != null && (mode != data.mode || !data.supportsComposer)) {
        return null;
      }
      return OpenRouterMediaAdapter(mode, data);
    }
    if (TokenDanceMediaProtocol.isHost(host)) {
      if (modelId == null) return null;
      final upstream = apiModelId(provider, modelId);
      final cache = ModelListMetadataCache.instance;
      final protocol =
          cache.lookup(provider, upstream)?.mediaProtocol ??
          (upstream != modelId
              ? cache.lookup(provider, modelId)?.mediaProtocol
              : null) ??
          TokenDanceMediaProtocol.known(upstream);
      if (protocol?.mode != mode) return null;
      return switch (protocol) {
        TokenDanceMediaProtocol.miniMax => const MiniMaxVideoAdapter(
          apiPath: '/gateway/minimax/v2',
        ),
        TokenDanceMediaProtocol.klingImage ||
        TokenDanceMediaProtocol.klingLongImage ||
        TokenDanceMediaProtocol.klingV1 ||
        TokenDanceMediaProtocol.klingV2 ||
        TokenDanceMediaProtocol.klingOmni => KlingGatewayAdapter(protocol!),
        TokenDanceMediaProtocol.arkImage => const ArkImagesAdapter(
          path: '/gateway/ark/v3/images/generations',
        ),
        TokenDanceMediaProtocol.seedance => const ArkVideoAdapter(
          taskPath: '/gateway/ark/v3/generations/tasks',
        ),
        TokenDanceMediaProtocol.dashScopeImage => const DashScopeImagesAdapter(
          apiPath: '/gateway/alibaba/api/v1',
        ),
        TokenDanceMediaProtocol.wan => const DashScopeVideoAdapter(
          gatewayPath: '/gateway/alibaba/wan3/v1',
        ),
        TokenDanceMediaProtocol.happyHorse => const DashScopeVideoAdapter(
          gatewayPath: '/gateway/alibaba/happyhorse/v1',
        ),
        TokenDanceMediaProtocol.xaiVideo => const XaiVideoAdapter(),
        TokenDanceMediaProtocol.openAiEdit => const OpenAiImagesAdapter(),
        TokenDanceMediaProtocol.openAiImage => const OpenAiImagesAdapter(
          generationOnly: true,
        ),
        _ => null,
      };
    }
    if (const {
          'api.minimax.io',
          'api.minimaxi.com',
          'api.minimax.chat',
        }.contains(host) &&
        video &&
        modelId != null &&
        RegExp(
          r'^minimax-h3(?:-(?:max(?:-turbo)?|highspeed|lite|mg|nc))?$',
        ).hasMatch(apiModelId(provider, modelId).toLowerCase())) {
      return const MiniMaxVideoAdapter();
    }
    if (kind == ProviderKind.claude) return null;
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
    if (TokenDanceMediaProtocol.isHost(Uri.tryParse(provider.baseUrl)?.host)) {
      return adapter != null;
    }
    final id = apiModelId(provider, modelId).toLowerCase();
    return switch (adapter) {
      FalMediaAdapter() =>
        FalMediaAdapter.knownModel(provider, modelId) != null,
      OpenAiImagesAdapter() =>
        id.startsWith('gpt-image-') || id.startsWith('dall-e-'),
      OpenAiVideosAdapter() => id.startsWith('sora-'),
      KlingGatewayAdapter() || MiniMaxVideoAdapter() => true,
      OpenRouterMediaAdapter(:final model) => model != null,
      XaiImageAdapter() || XaiVideoAdapter() => id.startsWith('grok-imagine-'),
      GeminiImagesAdapter() =>
        id.contains('imagen-') ||
            id.startsWith('gemini-') && id.contains('-image'),
      VeoVideoAdapter() => id.startsWith('veo-'),
      ArkImagesAdapter() => id.contains('seedream-'),
      ArkVideoAdapter() => id.contains('seedance-'),
      DashScopeImagesAdapter() =>
        id.startsWith('wan') || id.startsWith('qwen-image'),
      DashScopeVideoAdapter() =>
        id.startsWith('wan') || id.startsWith('happyhorse-'),
      SiliconFlowImagesAdapter() =>
        id.contains('kolors') || id.contains('qwen-image'),
      SiliconFlowVideoAdapter() =>
        id.contains('minimax-h3') || id.contains('wan'),
      _ => false,
    };
  }
}
