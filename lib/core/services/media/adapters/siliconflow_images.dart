import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import 'native_image_size.dart';

class SiliconFlowImagesAdapter implements MediaAdapter {
  const SiliconFlowImagesAdapter();

  static bool _international(ProviderConfig provider) =>
      Uri.tryParse(provider.baseUrl)?.host == 'api.siliconflow.com';

  static Map<String, String> _sizes(ProviderConfig provider, String model) {
    if (model.contains('image-edit')) return const {};
    if (_international(provider)) {
      return const {
        '1:1': '512x512',
        '3:4': '768x1024',
        '4:3': '1024x768',
        '9:16': '576x1024',
        '16:9': '1024x576',
      };
    }
    if (model.contains('kolors')) {
      return const {
        '1:1': '1024x1024',
        '3:4': '960x1280',
        '1:2': '720x1440',
        '9:16': '720x1280',
      };
    }
    if (model.contains('qwen-image')) {
      return const {
        '1:1': '1328x1328',
        '16:9': '1664x928',
        '9:16': '928x1664',
        '4:3': '1472x1140',
        '3:4': '1140x1472',
        '3:2': '1584x1056',
        '2:3': '1056x1584',
      };
    }
    return const {};
  }

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final edit = model.contains('image-edit');
    final kolors = model.contains('kolors');
    return MediaCapabilities(
      aspectRatios: ['auto', ..._sizes(provider, model).keys],
      maxReferences: edit
          ? (model.contains('2509') ? 3 : 1)
          : kolors
          ? 1
          : 0,
      requiresReference: edit,
      supportsNegativePrompt: !_international(provider),
      formats: _international(provider) ? const ['png', 'jpeg'] : const [],
      supportsSeed: true,
      platformOptions: [
        if (!_international(provider))
          const MediaParameter(
            'num_inference_steps',
            MediaParameterType.integer,
            minimum: 1,
            maximum: 100,
            step: 1,
            defaultValue: 20,
          ),
        if (kolors)
          const MediaParameter(
            'guidance_scale',
            MediaParameterType.number,
            minimum: 0,
            maximum: 20,
            step: 0.1,
          ),
        if (model.contains('qwen-image'))
          const MediaParameter(
            'cfg',
            MediaParameterType.number,
            minimum: 0,
            maximum: 20,
            step: 0.1,
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
    final lower = model.toLowerCase();
    final images = [
      for (final reference in request.inputImages)
        await mediaReferenceDataUri(reference),
    ];
    final size = _sizes(context.provider, lower)[request.aspectRatio];
    final format = request.parameters['format'];
    final output = await context.jsonRequest(
      'POST',
      context.endpoint('images/generations'),
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': model,
        'prompt': request.prompt,
        if (size != null) 'image_size': size,
        if (format is String) 'output_format': format,
        if (request.negativePrompt case final value?) 'negative_prompt': value,
        if (request.parameters['seed'] case final int seed) 'seed': seed,
        for (var index = 0; index < images.length; index++)
          index == 0 ? 'image' : 'image${index + 1}': images[index],
        for (final field in capabilities(
          context.provider,
          request.modelId,
        ).platformOptions)
          if (request.parameters[field.key] case final num value)
            field.key: value,
      }),
    );
    yield MediaOutput([
      for (final row
          in (output['images'] as List? ?? const []).whereType<Map>())
        if (mediaResultUri(row['url']) case final url?)
          MediaResult(mime: imageMime(format), url: url),
    ]);
  }
}
