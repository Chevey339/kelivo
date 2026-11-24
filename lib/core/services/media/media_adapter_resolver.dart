import '../../models/media_creation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import '../model_spec/model_list_metadata_cache.dart';
import '../model_spec/model_spec_resolver.dart';
import '../../models/model_spec.dart';
import 'adapters/chat_completion_images.dart';
import 'adapters/gemini_omni_video.dart';
import 'adapters/modelscope_media.dart';
import 'adapters/new_api_video.dart';
import 'adapters/replicate_media.dart';
import 'replicate_models.dart';
import 'modelscope_models.dart';
import 'gemini_media_models.dart';
import 'ark_media_models.dart';
import 'adapters/ark_images.dart';
import 'adapters/ark_video.dart';
import 'adapters/dashscope_images.dart';
import 'adapters/dashscope_video.dart';
import 'adapters/fal_media.dart';
import 'adapters/gemini_images.dart';
import 'adapters/google_media_route.dart';
import 'adapters/kling_gateway.dart';
import 'adapters/minimax_video.dart';
import 'adapters/openai_images.dart';
import 'adapters/openai_videos.dart';
import 'adapters/openrouter_media.dart';
import 'adapters/siliconflow_images.dart';
import 'adapters/siliconflow_video.dart';
import 'adapters/veo_video.dart';
import 'adapters/xai_media.dart';
import 'adapters/zai_media.dart';
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
    MediaApiProtocol? protocol,
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
    final upstream = modelId == null ? '' : apiModelId(provider, modelId);
    final selected =
        protocol ??
        (modelId == null
            ? MediaApiProtocol.auto
            : overrides(provider, modelId).protocol);
    if (selected != MediaApiProtocol.auto && selected.mode == mode) {
      return switch (selected) {
        MediaApiProtocol.openAiImage => const OpenAiImagesAdapter(),
        MediaApiProtocol.chatImage => const ChatCompletionImagesAdapter(),
        MediaApiProtocol.geminiImage =>
          modelId != null && !GeminiImagesAdapter.available(provider, modelId)
              ? null
              : GeminiImagesAdapter(
                  compatibleBase: kind != ProviderKind.google,
                ),
        MediaApiProtocol.geminiVideo =>
          GoogleMediaRoute.globalAvailable(provider)
              ? const GeminiOmniVideoAdapter()
              : null,
        MediaApiProtocol.arkImage => const ArkImagesAdapter(),
        MediaApiProtocol.arkVideo => const ArkVideoAdapter(),
        MediaApiProtocol.dashScopeImage => const DashScopeImagesAdapter(),
        MediaApiProtocol.dashScopeVideo =>
          DashScopeVideoAdapter.supportsPromptOrFrames(upstream)
              ? const DashScopeVideoAdapter()
              : null,
        MediaApiProtocol.modelScopeImage => const ModelScopeImagesAdapter(),
        MediaApiProtocol.modelScopeVideo => const ModelScopeVideoAdapter(),
        MediaApiProtocol.openAiVideo => const OpenAiVideosAdapter(),
        MediaApiProtocol.newApiVideo => const NewApiVideoAdapter(),
        MediaApiProtocol.auto => null,
      };
    }
    if (ReplicateMediaModel.isHost(host)) {
      final model = ReplicateMediaModel.find(upstream);
      return model != null && model.mode == mode
          ? ReplicateMediaAdapter(model)
          : null;
    }
    if (isModelScopeInferenceHost(host)) {
      return video
          ? const ModelScopeVideoAdapter()
          : const ModelScopeImagesAdapter();
    }
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
      final cache = ModelListMetadataCache.instance;
      final protocol =
          cache.lookup(provider, upstream)?.mediaProtocol ??
          (upstream != modelId
              ? cache.lookup(provider, modelId)?.mediaProtocol
              : null) ??
          TokenDanceMediaProtocol.known(upstream);
      if (protocol?.mode != mode) return null;
      return switch (protocol) {
        TokenDanceMediaProtocol.geminiImage => const GeminiImagesAdapter(
          apiBasePath: '/gateway/v1beta',
        ),
        TokenDanceMediaProtocol.chatCompletionsImage =>
          const ChatCompletionImagesAdapter(),
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
    if (host == 'open.bigmodel.cn' || host == 'api.z.ai') {
      if (upstream.toLowerCase() == 'glm-image' && !video) {
        return const ZaiImagesAdapter();
      }
      if (upstream.toLowerCase() == 'cogvideox-3' && video) {
        return const ZaiVideoAdapter();
      }
    }
    if (key == 'grok' || host == 'api.x.ai') {
      return video ? const XaiVideoAdapter() : const XaiImageAdapter();
    }
    if (key == 'bytedance' || isArkMediaHost(host)) {
      return video ? const ArkVideoAdapter() : const ArkImagesAdapter();
    }
    if (key == 'aliyun' ||
        host.startsWith('dashscope') && host.endsWith('.aliyuncs.com') ||
        host.endsWith('.maas.aliyuncs.com')) {
      if (video && !DashScopeVideoAdapter.supportsPromptOrFrames(upstream)) {
        return null;
      }
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
    if (kind == ProviderKind.google ||
        host == 'generativelanguage.googleapis.com') {
      final publicApi =
          host == 'generativelanguage.googleapis.com' &&
          provider.vertexAI != true;
      if (video) {
        if (isGeminiOmniVideoModel(upstream)) {
          return GoogleMediaRoute.globalAvailable(provider)
              ? const GeminiOmniVideoAdapter()
              : null;
        }
        if (provider.vertexAI == true &&
            VeoVideoAdapter.retiredOnVertex(upstream)) {
          return null;
        }
        return !publicApi && (host.isNotEmpty || provider.vertexAI == true)
            ? const VeoVideoAdapter()
            : null;
      }
      if (modelId != null &&
          !GeminiImagesAdapter.available(provider, modelId)) {
        return null;
      }
      return GeminiImagesAdapter(compatibleBase: kind != ProviderKind.google);
    }
    if (video) {
      return host.isNotEmpty && host != 'api.openai.com'
          ? const OpenAiVideosAdapter()
          : null;
    }
    if (modelId != null) {
      final resolved = ModelSpecResolver.instance.resolve(provider, modelId);
      if (resolved.spec.type == ModelType.chat) {
        final outputSource = resolved.sources[ModelSpecField.output];
        if (!resolved.spec.output.contains(Modality.image) ||
            !isGeminiImageModel(upstream) &&
                outputSource != SpecSource.override &&
                outputSource != SpecSource.catalog) {
          return null;
        }
        return const ChatCompletionImagesAdapter();
      }
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

  bool hasModelData(
    ProviderConfig provider,
    MediaMode mode,
    String modelId, {
    MediaApiProtocol? protocol,
  }) {
    final adapter = resolve(
      provider,
      mode,
      modelId: modelId,
      protocol: protocol,
    );
    if (TokenDanceMediaProtocol.isHost(Uri.tryParse(provider.baseUrl)?.host)) {
      return adapter != null;
    }
    final upstream = apiModelId(provider, modelId).toLowerCase();
    final raw = provider.modelOverrides[modelId];
    final id = adapter is ArkImagesAdapter || adapter is ArkVideoAdapter
        ? arkMediaFamily(
            upstream,
            modelId,
            raw is Map ? raw['name'] as String? : null,
          )
        : upstream;
    return switch (adapter) {
      FalMediaAdapter() =>
        FalMediaAdapter.knownModel(provider, modelId) != null,
      OpenAiImagesAdapter() =>
        id.startsWith('gpt-image-') || id.startsWith('dall-e-'),
      OpenAiVideosAdapter() => id.startsWith('sora-'),
      KlingGatewayAdapter() || MiniMaxVideoAdapter() => true,
      OpenRouterMediaAdapter(:final model) => model != null,
      XaiImageAdapter() || XaiVideoAdapter() => id.startsWith('grok-imagine-'),
      GeminiImagesAdapter() => id.contains('imagen-') || isGeminiImageModel(id),
      ChatCompletionImagesAdapter() => isGeminiImageModel(id),
      GeminiOmniVideoAdapter() => isGeminiOmniVideoModel(id),
      ReplicateMediaAdapter() ||
      ZaiImagesAdapter() ||
      ZaiVideoAdapter() => true,
      ModelScopeImagesAdapter() || ModelScopeVideoAdapter() =>
        modelScopeCreationModels.any((model) => model.toLowerCase() == id),
      VeoVideoAdapter() => id.startsWith('veo-'),
      ArkImagesAdapter() =>
        id.contains('seedream-') || id.contains('seededit-'),
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
