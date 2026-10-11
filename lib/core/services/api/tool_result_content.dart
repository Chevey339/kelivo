import '../../../utils/mcp_structured_image.dart';
import '../mcp/mcp_image_snapshot.dart';

import 'chat_api_helpers.dart';

/// Reads typed MCP images and successful view_image snapshots from metadata.
/// Tool text, including rejected paths in errors, never authorizes file reads.
class ToolResultContent {
  const ToolResultContent(this.text, [this.imageUrls = const []]);

  final String text;
  final List<String> imageUrls;

  static Future<ToolResultContent> read(
    String name,
    String content, {
    Map<String, dynamic>? metadata,
    bool canImageInput = true,
  }) async {
    final workspace = metadata?['workspace'];
    if (workspace != null &&
        (name != 'view_image' ||
            workspace is! Map ||
            workspace['tool'] != name ||
            workspace['status'] != 'ok')) {
      return ToolResultContent(content);
    }
    final imageUris = mcpResultImageUris(readMcpResultMetadata(metadata));
    if (imageUris.isEmpty) return ToolResultContent(content);
    var text = content;
    for (final uri in imageUris) {
      text = text.replaceAll('![](${encodeMarkdownImageDestination(uri)})', '');
    }
    text = text.trim();
    if (!canImageInput) {
      return ToolResultContent(
        '$text\n(Image omitted: this model does not support image input.)',
      );
    }
    final urls = <String>[];
    for (final uri in imageUris) {
      final url = workspace == null
          ? await McpImageSnapshot.readDataUrl(uri)
          : await tryEncodeBase64DataUrl(uri);
      if (url != null) urls.add(url);
    }
    return ToolResultContent(
      urls.isEmpty ? '$text\n(Image snapshot is unavailable.)' : text,
      urls,
    );
  }

  Object get responsesOutput => imageUrls.isEmpty
      ? text
      : [
          if (text.isNotEmpty) {'type': 'input_text', 'text': text},
          for (final url in imageUrls)
            {'type': 'input_image', 'image_url': url, 'detail': 'high'},
        ];

  Object get claudeContent => imageUrls.isEmpty
      ? (text.trim().isEmpty ? '(no output)' : text)
      : [
          if (text.isNotEmpty) {'type': 'text', 'text': text},
          for (final url in imageUrls)
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mimeFromDataUrl(url),
                'data': url.substring(url.indexOf(',') + 1),
              },
            },
        ];

  List<Map<String, dynamic>> get googleImageParts => [
    for (final url in imageUrls)
      {
        'inlineData': {
          'mimeType': mimeFromDataUrl(url),
          'data': url.substring(url.indexOf(',') + 1),
        },
      },
  ];
}
