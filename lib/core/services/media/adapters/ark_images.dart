import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_request.dart';
import 'native_image_size.dart';

class ArkImagesAdapter implements MediaAdapter {
  const ArkImagesAdapter();

  static bool _group(String id) =>
      id.contains('seedream-4') ||
      id.contains('seedream-5-0-lite') ||
      id.contains('seedream-5.0-lite') ||
      id.startsWith('ep-');

  static List<String> _sizes(String id) {
    if (_transparent(id) ||
        id.contains('seedream-5-0-pro') ||
        id.contains('seedream-5-0-flash') ||
        id.contains('seedream-5.0-pro') ||
        id.contains('seedream-5.0-flash')) {
      return const ['2K', '1K', '1.5K'];
    }
    if (id.contains('seedream-5') && id.contains('lite')) {
      return const ['2K', '3K', '4K'];
    }
    if (id.contains('seedream-4-5') || id.contains('seedream-4.5')) {
      return const ['2K', '4K'];
    }
    if (id.contains('seedream-3')) return const ['1K', '2K'];
    return const ['2K', '1K', '4K'];
  }

  static bool _supportsFormat(String id) => id.contains('seedream-5');
  static bool _transparent(String id) =>
      id.contains('seedream-5-5') || id.contains('seedream-5.5');

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final group = _group(model);
    final legacy = model.contains('seedream-3');
    return MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: group ? 15 : 1,
      maxReferences: legacy
          ? 0
          : group
          ? 14
          : 10,
      maxCombinedInputsAndOutputs: group ? 15 : null,
      sizes: _sizes(model),
      formats: _supportsFormat(model) ? const ['jpeg', 'png'] : const [],
      supportsSeed: legacy,
      supportsTransparent: _transparent(model),
      platformOptions: const [
        MediaParameter(
          'watermark',
          MediaParameterType.boolean,
          defaultValue: true,
        ),
      ],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final normalized = model.toLowerCase();
    final refs = [
      for (final reference in request.inputImages)
        await mediaReferenceDataUri(reference),
    ];
    final caps = capabilities(context.provider, request.modelId);
    final size = request.parameters['size'] ?? caps.sizes.first;
    final background = request.parameters['background'];
    final format = background == 'transparent'
        ? 'png'
        : request.parameters['format'];
    final pixels = imageDimensions(request.aspectRatio, switch (size) {
      // Leave room for the alignment rounding at the documented pixel ceiling.
      '4K' => request.aspectRatio == '1:1' ? 4096 : 4064,
      '3K' => 3072,
      '2K' => 2048,
      '1.5K' => 1536,
      _ => 1024,
    });
    final output = await context.jsonRequest(
      'POST',
      context.endpoint('images/generations'),
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': model,
        'prompt': request.prompt,
        'size': request.aspectRatio == 'auto'
            ? size
            : '${pixels.width}x${pixels.height}',
        if (refs.isNotEmpty) 'image': refs.length == 1 ? refs.single : refs,
        if (_group(normalized)) ...{
          'sequential_image_generation': request.count > 1
              ? 'auto'
              : 'disabled',
          if (request.count > 1)
            'sequential_image_generation_options': {
              'max_images': request.count,
            },
        },
        if (request.parameters['seed'] case final int seed) 'seed': seed,
        if (format is String) 'output_format': format,
        if (background is String) 'background': background,
        if (request.parameters['watermark'] case final bool watermark)
          'watermark': watermark,
        'response_format': 'url',
      }),
    );
    yield MediaOutput(parseOpenAiMediaImages(output, mime: imageMime(format)));
  }
}
