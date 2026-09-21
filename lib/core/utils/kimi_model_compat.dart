// Kimi Code model IDs and capabilities:
// https://www.kimi.com/code/docs/en/kimi-code/models.html
bool isKimiCodeK3Alias(String modelId) {
  final id = modelId.trim().toLowerCase();
  return id == 'k3' || id == 'k3-256k';
}

bool isKimiK28Model(String modelId) => RegExp(
  r'(^|[/_:@])kimi-k2\.8(?:$|[-.:])',
  caseSensitive: false,
).hasMatch(modelId.trim());

bool isKimiForCodingModel(String modelId) => RegExp(
  r'(^|[/_:@])kimi-for-coding(?:-highspeed)?(?:$|[:])',
  caseSensitive: false,
).hasMatch(modelId.trim());

bool isKimiCodeHighSpeedModel(String modelId) => RegExp(
  r'(^|[/_:@])kimi-for-coding-highspeed(?:$|[:])',
  caseSensitive: false,
).hasMatch(modelId.trim());
