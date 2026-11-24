/// Match the upstream model, including IDs namespaced by compatible gateways.
/// An image-input (vision) chat model alone cannot generate artwork.
String geminiMediaName(String id) => id.trim().toLowerCase().split('/').last;

bool isNanoBanana21(String id) =>
    geminiMediaName(id) == 'gemini-nano-banana-2.1';

bool isGeminiImageModel(String id) {
  final name = geminiMediaName(id);
  return _imageFamily.hasMatch(name) || _nanoBanana.hasMatch(name);
}

final _imageFamily = RegExp(
  r'^gemini-\d+(?:\.\d+)?-(?:flash(?:-lite)?|pro)(?:-preview)?-(?:preview-)?image(?:$|[-:@])',
);
final _nanoBanana = RegExp(r'^(?:gemini-)?nano-banana(?:$|[-:@])');

final _omniVideo = RegExp(r'^gemini-omni-1\.[12]-flash(?:$|[-:@])');

bool isGeminiOmniVideoModel(String id) =>
    _omniVideo.hasMatch(geminiMediaName(id));
