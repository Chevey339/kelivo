import '../../models/media_creation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import 'adapters/openai_images.dart';
import 'adapters/xai_media.dart';
import 'media_adapter.dart';

class MediaAdapterResolver {
  const MediaAdapterResolver();

  MediaAdapter? resolve(ProviderConfig provider, MediaMode mode) {
    if (mode != MediaMode.image) return null;
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
}
