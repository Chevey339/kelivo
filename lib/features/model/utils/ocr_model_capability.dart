import '../../../core/providers/settings_provider.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';

bool modelSupportsOcrImageInput(
  SettingsProvider settings,
  String providerKey,
  String modelId,
) {
  final cfg = settings.getProviderConfig(providerKey);
  return ModelSpecResolver.instance.spec(cfg, modelId).supportsImageInput;
}
