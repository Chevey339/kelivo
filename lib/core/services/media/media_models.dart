import '../../models/media_creation.dart';
import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import 'media_adapter_resolver.dart';
import 'media_request.dart';

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
  final eligible = switch (mode) {
    MediaMode.video => spec.type == ModelType.video,
    MediaMode.image =>
      spec.type == ModelType.image ||
          spec.type == ModelType.chat &&
              spec.output.contains(Modality.image) &&
              ProviderConfig.classify(
                    provider.id,
                    explicitType: provider.providerType,
                  ) ==
                  ProviderKind.google,
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
