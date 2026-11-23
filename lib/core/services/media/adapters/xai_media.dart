import '../../../models/provider_oauth.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_request.dart';

class XaiImageAdapter implements MediaAdapter {
  const XaiImageAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      const MediaCapabilities(
        aspectRatios: [
          'auto',
          '1:1',
          '3:2',
          '2:3',
          '4:3',
          '3:4',
          '16:9',
          '9:16',
        ],
        maxPerRequest: 10,
        maxReferences: 1,
      );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final base = context.provider.oauthProvider == OAuthProvider.grok
        ? grokMediaBaseUrl
        : null;
    final reference = request.references.firstOrNull;
    final url = context.endpoint(
      reference == null ? 'images/generations' : 'images/edits',
      base: base,
    );
    final payload = await context.jsonRequest(
      'POST',
      url,
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        'n': request.count,
        if (request.aspectRatio != 'auto') 'aspect_ratio': request.aspectRatio,
        if (request.parameters['resolution'] case final String resolution)
          'resolution': resolution,
        if (reference != null)
          'image': {
            'type': 'image_url',
            'url': await mediaReferenceDataUri(reference),
          },
      }),
    );
    yield MediaOutput(parseOpenAiMediaImages(payload, mime: 'image/jpeg'));
  }
}
