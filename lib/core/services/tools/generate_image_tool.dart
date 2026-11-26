import '../../../utils/kelivo_file_uri.dart';
import '../../models/message_part.dart';

abstract final class GenerateImageTool {
  static const name = 'generate_image';
  static const imageIdPattern = r'^img_[0-9a-f]{20}$';
  static const callIdParameter = 'chatToolCallId';
  static const batchKey = 'generationBatchId';
  static const attachmentKey = 'generatedImage';

  static bool acceptsReferences(Map<String, dynamic> tool) =>
      switch (tool['function']) {
        {
          'name': GenerateImageTool.name,
          'parameters': {'properties': {'image_ids': _}},
        } =>
          true,
        _ => false,
      };

  static Map<String, dynamic> withCurrentAttachments(
    Map<String, dynamic> tool,
    List<String> imageIds,
  ) {
    if (imageIds.isEmpty || !acceptsReferences(tool)) return tool;
    final function = tool['function'] as Map<String, dynamic>;
    return {
      ...tool,
      'function': {
        ...function,
        'description':
            '${function['description']}\n\n'
            'Latest user message image IDs, in attachment order: ${imageIds.join(', ')}.',
      },
    };
  }

  static List<ImagePart> attachments(Map<String, dynamic>? metadata) {
    final raw = metadata?[attachmentKey];
    final batch = metadata?[batchKey];
    final parts = <ImagePart>[];
    for (final value in raw is List ? raw : [raw]) {
      if (value is! String) continue;
      try {
        final part = ImagePart.fromPayload(value);
        final id = part.generationItemId;
        if (id != null &&
            part.mime?.startsWith('image/') == true &&
            !part.unavailable &&
            KelivoFileUri.generationImageItemId(part.uri) == id &&
            (batch == null ||
                batch is String &&
                    KelivoFileUri.isGenerationFile(part.uri, batch))) {
          parts.add(part);
        }
      } on FormatException {
        continue;
      }
    }
    return parts;
  }

  static ImagePart? attachment(Map<String, dynamic>? metadata) =>
      attachments(metadata).firstOrNull;

  static Map<String, dynamic> definition({
    required bool allowReferences,
    int minReferences = 0,
    int? maxReferences,
  }) {
    final purpose = minReferences > 0
        ? 'Edit an image from this conversation. The selected model needs a reference image.'
        : allowReferences
        ? 'Create an image from a text description, or edit images from this conversation.'
        : 'Create an image from a text description.';
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description':
            '''
$purpose

Use this when:
- The user asks you to draw, generate, design, or render an image
${allowReferences ? '- The user wants to change an image already in this conversation (an attachment or an image you created earlier)\n' : ''}
Don't use for:
- Describing or answering questions about an existing image (look at it directly, or use view_image)
- Charts, tables, or diagrams that are clearer as text or code

The image is saved in Creation and appears in the conversation automatically. Do not add a Markdown image, invent a file path, or search the workspace for it. The result contains an image_id for each image. Pass it to view_image as image_id when available, or to generate_image as image_ids for an edit.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description':
                  'A complete description of the image: subject, setting, style, composition, lighting, and any text that must appear (quote it exactly).'
                  '${allowReferences ? ' When editing, say what to change and what must stay the same.' : ''}',
            },
            if (allowReferences)
              'image_ids': {
                'type': 'array',
                'items': {'type': 'string', 'pattern': imageIdPattern},
                if (minReferences > 0) 'minItems': minReferences,
                if (maxReferences != null) 'maxItems': maxReferences,
                'description':
                    'Use the exact img_ identifiers of conversation images from the messages or a view_image listing.'
                    '${minReferences > 0 ? ' A reference image is required.' : ' Omit to create a new image.'}',
              },
          },
          'required': ['prompt', if (minReferences > 0) 'image_ids'],
          'additionalProperties': false,
        },
      },
    };
  }
}
