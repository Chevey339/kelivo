import '../../models/media_creation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import 'adapters/openai_images.dart';
import 'adapters/openai_videos.dart';
import 'adapters/ark_video.dart';
import 'adapters/dashscope_video.dart';
import 'adapters/siliconflow_video.dart';
import 'adapters/veo_video.dart';
import 'adapters/xai_media.dart';
import 'media_adapter.dart';

class MediaAdapterResolver {
  const MediaAdapterResolver();

  MediaAdapter? resolve(ProviderConfig provider, MediaMode mode) {
    if (mode == MediaMode.video) return _video(provider);
    final oauth = provider.oauthProvider;
    if (oauth != null) {
      return switch (oauth) {
        OAuthProvider.chatgpt => const OpenAiImagesAdapter(),
        OAuthProvider.grok => const XaiImageAdapter(),
        _ => null,
      };
    }
    final host = Uri.tryParse(provider.baseUrl)?.host;
    if (host == 'api.x.ai') return const XaiImageAdapter();
    if (ProviderConfig.classify(
          provider.id,
          explicitType: provider.providerType,
        ) ==
        ProviderKind.openai) {
      return const OpenAiImagesAdapter();
    }
    return null;
  }

  MediaAdapter? _video(ProviderConfig provider) {
    if (provider.oauthProvider != null) {
      return provider.oauthProvider == OAuthProvider.grok
          ? const XaiVideoAdapter()
          : null;
    }
    final host = Uri.tryParse(provider.baseUrl)?.host.toLowerCase() ?? '';
    final key = provider.id.toLowerCase();
    if (key == 'grok' || host == 'api.x.ai') return const XaiVideoAdapter();
    if (key == 'bytedance' || host.endsWith('.volces.com')) {
      return const ArkVideoAdapter();
    }
    if (key == 'aliyun' ||
        host.startsWith('dashscope') && host.endsWith('.aliyuncs.com') ||
        host.endsWith('.maas.aliyuncs.com')) {
      return const DashScopeVideoAdapter();
    }
    if (key == 'siliconflow' ||
        host == 'api.siliconflow.cn' ||
        host == 'api.siliconflow.com') {
      return const SiliconFlowVideoAdapter();
    }
    final kind = ProviderConfig.classify(
      provider.id,
      explicitType: provider.providerType,
    );
    return switch (kind) {
      ProviderKind.google
          when provider.vertexAI == true ||
              host.isNotEmpty && host != 'generativelanguage.googleapis.com' =>
        const VeoVideoAdapter(),
      ProviderKind.openai when host.isNotEmpty && host != 'api.openai.com' =>
        const OpenAiVideosAdapter(),
      _ => null,
    };
  }
}
