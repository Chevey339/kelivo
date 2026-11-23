import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import 'native_image_size.dart';

class DashScopeImagesAdapter implements MediaAdapter {
  const DashScopeImagesAdapter();

  static bool _wan26Edit(String model) => model.startsWith('wan2.6-image');
  static bool _wan26Text(String model) => model.startsWith('wan2.6-t2i');
  static bool _wanModern(String model) => model.startsWith('wan2.7-image');
  static bool _wanAsync(String model) =>
      _wan26Edit(model) || _wan26Text(model) || _wanModern(model);
  static bool _legacyWan(String model) =>
      model.startsWith('wan') && !_wanAsync(model);
  static bool _wan25Edit(String model) => model.startsWith('wan2.5-i2i');
  static bool _wanxEdit(String model) => model.startsWith('wanx2.1-imageedit');
  static bool _modernQwen(String model) =>
      model.startsWith('qwen-image-2.') || model.startsWith('qwen-image-3.');
  static bool _negative(String model) =>
      !_wanxEdit(model) &&
      !_wanModern(model) &&
      !model.startsWith('qwen-image-2.1');
  static bool _edit(String model) =>
      model.contains('edit') || model.contains('i2i');

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final wanEdit = _wan26Edit(model);
    final wanModern = _wanModern(model);
    final legacy = _legacyWan(model);
    final edit = _edit(model);
    final qwen = _modernQwen(model);
    final limitedQwen =
        model == 'qwen-image-edit' ||
        model.startsWith('qwen-image-edit-2025-08');
    return MediaCapabilities(
      aspectRatios: _wanxEdit(model)
          ? const ['auto']
          : _wan25Edit(model)
          ? standardImageRatios
          : const ['auto', '1:1', '4:3', '3:4', '16:9', '9:16'],
      maxPerRequest: qwen
          ? 6
          : (wanEdit || wanModern || _wan26Text(model) || legacy)
          ? 4
          : 1,
      maxReferences: switch (true) {
        _ when wanModern => 9,
        _ when wanEdit => 4,
        _ when model.startsWith('qwen-image-2.1') => 10,
        _ when qwen => 3,
        _ when _wanxEdit(model) => 1,
        _ when edit => limitedQwen ? 1 : 3,
        _ => 0,
      },
      requiresReference: edit || wanEdit,
      sizes: wanEdit || wanModern ? const ['1K', '2K'] : const [],
      supportsNegativePrompt: _negative(model),
      supportsSeed: true,
      platformOptions: [
        const MediaParameter(
          'watermark',
          MediaParameterType.boolean,
          defaultValue: false,
        ),
        if (!wanModern && !_wanxEdit(model))
          const MediaParameter(
            'prompt_extend',
            MediaParameterType.boolean,
            defaultValue: true,
          ),
        if (_wanxEdit(model))
          const MediaParameter(
            'function',
            MediaParameterType.enumeration,
            choices: [
              'description_edit',
              'stylization_all',
              'colorization',
              'doodle',
            ],
            defaultValue: 'description_edit',
          ),
        if (wanModern)
          const MediaParameter(
            'thinking_mode',
            MediaParameterType.boolean,
            defaultValue: false,
          ),
      ],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final origin = Uri.parse(context.provider.baseUrl).origin;
    final api = '$origin/api/v1';
    final model = apiModelId(context.provider, request.modelId);
    final normalized = model.toLowerCase();
    final legacy = _legacyWan(normalized);
    final async = legacy || _wanAsync(normalized);
    final wan25Edit = _wan25Edit(normalized);
    final wanxEdit = _wanxEdit(normalized);
    final path = switch (true) {
      _ when wan25Edit || wanxEdit =>
        'services/aigc/image2image/image-synthesis',
      _ when legacy => 'services/aigc/text2image/image-synthesis',
      _ when async => 'services/aigc/image-generation/generation',
      _ => 'services/aigc/multimodal-generation/generation',
    };
    final refs = [
      for (final reference in request.inputImages)
        await mediaReferenceDataUri(reference),
    ];
    final fixedQwenSize =
        normalized.startsWith('qwen-image') && !_modernQwen(normalized);
    final modernWanText =
        _wan26Text(normalized) || normalized.startsWith('wan2.5-t2i');
    final configuredSize = request.parameters['size'];
    final dimensions = imageDimensions(
      request.aspectRatio,
      configuredSize == '2K' ? 2016 : 1344,
      multiple: 16,
    );
    final editSize = imageDimensions(request.aspectRatio, 1024, multiple: 16);
    final size = switch (request.aspectRatio) {
      _ when wan25Edit => '${editSize.width}*${editSize.height}',
      _ when modernWanText => '${dimensions.width}*${dimensions.height}',
      '16:9' when legacy => '1280*720',
      '9:16' when legacy => '720*1280',
      '4:3' when legacy => '1152*864',
      '3:4' when legacy => '864*1152',
      _ when legacy => '1024*1024',
      '16:9' when fixedQwenSize => '1664*928',
      '9:16' when fixedQwenSize => '928*1664',
      '4:3' when fixedQwenSize => '1472*1104',
      '3:4' when fixedQwenSize => '1104*1472',
      _ when fixedQwenSize => '1328*1328',
      _ => '${dimensions.width}*${dimensions.height}',
    };
    final headers = context.headers(request.modelId);
    final response = await context.jsonRequest(
      'POST',
      context.endpoint(path, base: api),
      headers: {...headers, if (async) 'X-DashScope-Async': 'enable'},
      body: context.body(request, {
        'model': model,
        'input': legacy
            ? {
                'prompt': request.prompt,
                if (!wanxEdit && request.negativePrompt != null)
                  'negative_prompt': request.negativePrompt,
                if (wan25Edit) 'images': refs,
                if (wanxEdit) ...{
                  'function':
                      request.parameters['function'] ?? 'description_edit',
                  if (refs.isNotEmpty) 'base_image_url': refs.first,
                },
              }
            : {
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      for (final image in refs) {'image': image},
                      {'text': request.prompt},
                    ],
                  },
                ],
              },
        'parameters': {
          'n': request.count,
          if (!wanxEdit && request.aspectRatio != 'auto')
            'size': size
          else if (configuredSize != null)
            'size': configuredSize,
          if (!legacy &&
              _negative(normalized) &&
              request.negativePrompt != null)
            'negative_prompt': request.negativePrompt,
          if (request.parameters['seed'] case final int seed) 'seed': seed,
          if (request.parameters['watermark'] case final bool watermark)
            'watermark': watermark,
          if (request.parameters['prompt_extend'] case final bool extend)
            'prompt_extend': extend,
          if (_wan26Edit(normalized)) 'enable_interleave': false,
          if (request.parameters['thinking_mode'] case final bool enabled)
            'thinking_mode': enabled,
        },
      }),
    );
    if (!async) {
      yield MediaOutput(_images(response));
      return;
    }
    final output = response['output'] as Map?;
    final id = Uri.encodeComponent(requireMediaTaskId(output?['task_id']));
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('tasks/$id', base: api),
        headers: headers,
      ),
      result: (data) {
        final output = data['output'] as Map?;
        final status = output?['task_status'];
        if (const {
          'FAILED',
          'CANCELED',
          'CANCELLED',
          'UNKNOWN',
        }.contains(status)) {
          failedMediaTask(output);
        }
        return status == 'SUCCEEDED' ? _images(data) : null;
      },
    );
  }

  List<MediaResult> _images(Map<String, dynamic> response) {
    final output = response['output'] as Map?;
    final images = <MediaResult>[];
    void add(Object? url) {
      if (mediaResultUri(url) case final value?) {
        images.add(MediaResult(url: value, mime: 'image/png'));
      }
    }

    for (final choice
        in (output?['choices'] as List? ?? const []).whereType<Map>()) {
      final message = choice['message'] as Map?;
      for (final item
          in (message?['content'] as List? ?? const []).whereType<Map>()) {
        add(item['image']);
      }
    }
    for (final result
        in (output?['results'] as List? ?? const []).whereType<Map>()) {
      add(result['url']);
    }
    if (images.isEmpty && response['code'] != null) failedMediaTask(response);
    return images;
  }
}
