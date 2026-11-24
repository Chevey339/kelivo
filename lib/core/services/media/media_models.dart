import '../../models/media_creation.dart';
import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import '../model_spec/model_list_metadata_cache.dart';
import 'media_adapter_resolver.dart';
import 'media_request.dart';
import 'openrouter_media_catalog.dart';

class MediaModelChoice {
  const MediaModelChoice(this.provider, this.spec, this.capabilities);

  final ProviderConfig provider;
  final ModelSpec spec;
  final MediaCapabilities capabilities;

  String get key => '${provider.id}::${spec.id}';
}

MediaModelChoice? resolveMediaModel(
  ProviderConfig provider,
  String id,
  MediaMode mode, {
  MediaAdapterResolver resolver = const MediaAdapterResolver(),
  ModelSpec? resolvedSpec,
}) {
  if (!provider.enabled ||
      !provider.enabledModels.contains(id) ||
      provider.isOAuth && provider.oauthCredentials?.requiresLogin != false) {
    return null;
  }
  final spec = resolvedSpec ?? ModelSpecResolver.instance.spec(provider, id);
  final openRouter = OpenRouterMediaModel.isHost(
    Uri.tryParse(provider.baseUrl)?.host,
  );
  final eligible = switch (mode) {
    MediaMode.video =>
      spec.type == ModelType.video ||
          spec.type == ModelType.chat &&
              openRouter &&
              // Video is delivered through the dedicated generation endpoint.
              // The ordinary chat stream has no video output modality.
              ModelListMetadataCache.instance
                      .lookup(provider, spec.upstreamId)
                      ?.openRouterMedia
                      ?.mode ==
                  MediaMode.video,
    MediaMode.image =>
      spec.type == ModelType.image ||
          spec.type == ModelType.chat && spec.output.contains(Modality.image),
  };
  if (!eligible) return null;
  final capabilities = resolver.capabilities(provider, mode, id);
  return capabilities == null
      ? null
      : MediaModelChoice(provider, spec, capabilities);
}

MediaModelChoice? resolveDefaultImageModel(SettingsProvider settings) {
  final selection = settings.creationModel(CreationModelSlot.image);
  if (selection == null) return null;
  final provider = settings.providerConfigs[selection.providerKey];
  if (provider == null) return null;
  return resolveMediaModel(provider, selection.modelId, MediaMode.image);
}

({ProviderConfig provider, ModelSpec spec})? resolvePromptEnhancementModel(
  SettingsProvider settings,
) {
  final selected = settings.creationModel(CreationModelSlot.promptEnhance);
  if (selected == null) return null;
  final provider = settings.providerConfigs[selected.providerKey];
  if (provider == null ||
      !provider.enabled ||
      !provider.enabledModels.contains(selected.modelId) ||
      provider.isOAuth && provider.oauthCredentials?.requiresLogin != false) {
    return null;
  }
  final spec = ModelSpecResolver.instance.spec(provider, selected.modelId);
  return spec.type == ModelType.chat ? (provider: provider, spec: spec) : null;
}
