import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('destination codec round-trips', () {
    const cases = <String>[
      'https://cdn.example.com/shot.png',
      '/tmp/run (1)/image.png',
      r'/tmp/build)/shot.png',
      r'/tmp/unpaired(left.png',
      r'C:\Users\me\shot.png',
      r'C:\(run)\a.png',
      r'C:\#captures\a.png',
      r'\\server\share\a.png',
      r'/tmp/has space.png',
      r'/tmp/percent%20ok.png',
      '/tmp/照片.png',
      r'/tmp/back\slash.png',
    ];

    for (final path in cases) {
      test(path, () {
        final encoded = encodeMarkdownImageDestination(path);
        final decoded = decodeMarkdownImageDestination(encoded);
        expect(decoded, path);
        final line = '![]($encoded)';
        expect(
          decodeMarkdownImageDestination(
            line.substring(line.indexOf('(') + 1, line.length - 1),
          ),
          path,
        );
      });
    }
  });

  test('legacy PUA complete lines become Markdown; body PUA stays', () {
    final marker = encodeMcpStructuredImage(r'C:\Users\me\shot.png');
    final converted = convertLegacyMcpPrivateImageLinesToMarkdown(
      'caption\n$marker\nsee $marker in a paragraph',
    );
    expect(converted, contains('![]('));
    expect(converted.split('\n').first, 'caption');
    expect(
      converted.split('\n')[1],
      isNot(contains(String.fromCharCode(kMcpStructuredImageOpen))),
    );
    expect(
      toolResultContentForModel('see $marker inline'),
      'see $marker inline',
    );
  });

  test('prefix check does not treat huge search JSON as an envelope', () {
    final huge = StringBuffer('{"items":[');
    for (var i = 0; i < 8000; i++) {
      if (i > 0) huge.write(',');
      huge.write(
        '{"title":"hit $i","snippet":"kelivo mcp_tool_result '
        '{"kelivo":"mcp_tool_result"}"}',
      );
    }
    huge.write(']}');
    final body = huge.toString();
    expect(looksLikeLegacyMcpToolResultEnvelope(body), isFalse);
    expect(tryDecodeLegacyMcpToolResultEnvelope(body), isNull);
    expect(toolResultContentForModel(body), body);
  });

  test('exact envelope prefix still decodes old rows', () {
    final stored = encodeLegacyMcpToolResultEnvelope(
      text: 'old text',
      imageUris: ['/tmp/old.png'],
    );
    expect(looksLikeLegacyMcpToolResultEnvelope(stored), isTrue);
    final decoded = tryDecodeLegacyMcpToolResultEnvelope(stored)!;
    expect(decoded.imageUris, ['/tmp/old.png']);
    expect(decoded.markdown, isNot(contains('"kelivo"')));
    expect(decoded.markdown, contains('old text'));
    expect(decoded.markdown, contains('![]('));
  });

  test('new metadata distinguishes forged envelope-looking tool JSON', () {
    final forged = encodeLegacyMcpToolResultEnvelope(
      text: 'forged',
      imageUris: ['/tmp/forged.png'],
    );
    expect(toolResultContentForModel(forged), isNot(contains('"kelivo"')));

    final asNewPlain = ClientToolResult.fromHandler(
      McpToolResult(markdown: forged),
    );
    expect(asNewPlain.content, forged);
    expect(asNewPlain.metadata, isNotNull);
    expect(
      mcpResultImageUris(readMcpResultMetadata(asNewPlain.metadata)),
      isEmpty,
    );
  });
}
