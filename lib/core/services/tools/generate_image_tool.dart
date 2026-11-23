import '../../../utils/kelivo_file_uri.dart';
import '../../models/message_part.dart';

abstract final class GenerateImageTool {
  static const name = 'generate_image';
  static const imageIdPattern = r'^img_[0-9a-f]{20}$';
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

  static ImagePart? attachment(Map<String, dynamic>? metadata) {
    final value = metadata?[attachmentKey];
    if (value is! String) return null;
    try {
      final part = ImagePart.fromPayload(value);
      final segments = KelivoFileUri.decodeToSegments(part.uri);
      if (part.generationItemId != null &&
          part.mime?.startsWith('image/') == true &&
          segments?.first == 'upload') {
        return part;
      }
    } on FormatException {
      // Tool metadata can be incomplete if the call did not finish.
    }
    return null;
  }

  static Map<String, dynamic> definition({required bool allowReferences}) {
    final purpose = allowReferences
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

The result is shown to the user automatically, so don't repeat it in Markdown. One call makes one image; call again for more.''',
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
                'description':
                    'Optional. img_ identifiers of conversation images to edit or use as references. Copy them exactly from the messages or a view_image listing; never invent one. Omit to create a new image.',
              },
          },
          'required': ['prompt'],
          'additionalProperties': false,
        },
      },
    };
  }
}
