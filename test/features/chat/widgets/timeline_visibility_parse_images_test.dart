import 'package:Kelivo/features/chat/widgets/timeline_visibility.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseToolResultImages', () {
    test('extracts standalone-line markdown images', () {
      const content = '''
工具执行完成
![](https://example.com/output.png)
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/output.png']);
      expect(clean, '工具执行完成');
    });

    test('does not extract markdown images inside JSON fields', () {
      const content =
          '{"text":"README 内容……![benchmark](https://example.com/huge.png)"}';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, content);
    });

    test('does not extract images inside paragraphs or code fences', () {
      const content = '''
See ![shot](https://example.com/a.png) in the paragraph.
```
![](https://example.com/in-fence.png)
```
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean.contains('https://example.com/a.png'), isTrue);
      expect(clean.contains('https://example.com/in-fence.png'), isTrue);
    });

    test('keeps destinations with parentheses and spaces', () {
      const content = 'shot\n![](/tmp/run (1)/image.png)\ndone';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['/tmp/run (1)/image.png']);
      expect(clean.contains('/tmp/run'), isFalse);
      expect(clean.contains('shot'), isTrue);
      expect(clean.contains('done'), isTrue);
    });

    test('deduplicates identical paths and strips every whole-line row', () {
      const content = '''
intro
![](https://example.com/same.png)
![again](https://example.com/same.png)
outro
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/same.png']);
      expect(clean, 'intro\noutro');
    });

    test('tilde and 4-backtick fences keep images verbatim', () {
      const content = '''
~~~
![](https://example.com/tilde.png)
~~~
````
```
![](https://example.com/nested.png)
```
````
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, content.trim());
    });

    test('indented code images are not extracted', () {
      const content = 'note\n    ![](https://example.com/indented.png)\n';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(
        clean.contains('    ![](https://example.com/indented.png)'),
        isTrue,
      );
    });

    test('unclosed fences treat the rest as fenced', () {
      const content = '''
before
```
![](https://example.com/open.png)
still fenced
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, content.trim());
    });

    test('whole-line placeholders are removed but not added as images', () {
      const content = '''
summary
![]()
![x](generated)
done
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, 'summary\ndone');
    });

    test('inline placeholders in a paragraph stay in the body', () {
      const content = 'See ![]() in the paragraph.';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, content);
    });

    test('placeholders inside fences stay verbatim', () {
      const content = '''
```
![]()
![x](generated)
```
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean, content.trim());
    });

    test('structured MCP images survive an unclosed fence', () {
      final buf = StringBuffer()
        ..writeln('before')
        ..writeln('```')
        ..writeln('still open')
        ..writeln('![](https://example.com/in-fence.png)');
      writeMcpStructuredImage(buf, '/tmp/mcp_real.png');
      final (clean, images) = parseToolResultImages(buf.toString());
      expect(images, ['/tmp/mcp_real.png']);
      expect(clean.contains('https://example.com/in-fence.png'), isTrue);
      expect(
        clean.contains(encodeMcpStructuredImage('/tmp/mcp_real.png')),
        isFalse,
      );
      expect(clean.contains('/tmp/mcp_real.png'), isFalse);
    });

    test('fenced example images are not extracted without a marker', () {
      const content = '''
```
![](https://example.com/sample.png)
```
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean.contains('https://example.com/sample.png'), isTrue);
    });

    test('space plus tab reaching 4 columns is indented code', () {
      const content = 'note\n \t![](https://example.com/tab.png)\n';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean.contains('https://example.com/tab.png'), isTrue);
    });

    test('three spaces plus image is still an attachment', () {
      const content = 'note\n   ![](https://example.com/loose.png)\n';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/loose.png']);
    });

    test('U+2028 logical break still extracts a following image', () {
      final content = 'intro\u2028![](https://example.com/ls.png)\u2028done';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/ls.png']);
      expect(clean.contains('intro'), isTrue);
      expect(clean.contains('done'), isTrue);
    });

    test('4-column indented backticks do not open a fence', () {
      const content = '''
note
    ```
![](https://example.com/after-indent.png)
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/after-indent.png']);
      expect(clean.contains('    ```'), isTrue);
    });

    test('already-open fence still closes with at most 3 indent columns', () {
      const content = '''
```
![](https://example.com/inside.png)
   ```
![](https://example.com/after.png)
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/after.png']);
      expect(clean.contains('https://example.com/inside.png'), isTrue);
    });

    test('a 4-column-indented closer does not close an open fence', () {
      const content = '''
```
![](https://example.com/still-inside.png)
    ```
![](https://example.com/still-fenced.png)
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean.contains('https://example.com/still-fenced.png'), isTrue);
    });

    test('backtick info string with a backtick does not open a fence', () {
      const content = '''
```lang`sample
![](https://example.com/not-fenced.png)
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, ['https://example.com/not-fenced.png']);
    });

    test('tilde fence still opens when the info string has backticks', () {
      const content = '''
~~~lang`sample
![](https://example.com/tilde-info.png)
~~~
''';
      final (clean, images) = parseToolResultImages(content);
      expect(images, isEmpty);
      expect(clean.contains('https://example.com/tilde-info.png'), isTrue);
    });

    test('escaped closing paren is part of the destination', () {
      const content = r'![](/tmp/build\)/shot.png)';
      final (clean, images) = parseToolResultImages(content);
      expect(images, [r'/tmp/build)/shot.png']);
      expect(clean, isEmpty);
    });

    test('Windows path backslashes are preserved', () {
      const content = r'![](C:\Users\me\shot.png)';
      final (clean, images) = parseToolResultImages(content);
      expect(images, [r'C:\Users\me\shot.png']);
      expect(clean, isEmpty);
    });

    test('typed envelope images survive an unclosed fence in text', () {
      final stored = encodeLegacyMcpToolResultEnvelope(
        text: 'before\n```\nstill open',
        imageUris: ['/tmp/mcp_real.png'],
      );
      final (clean, images) = parseToolResultImages(stored);
      expect(images, ['/tmp/mcp_real.png']);
      expect(clean.contains('still open'), isTrue);
      expect(clean.contains('/tmp/mcp_real.png'), isFalse);
    });

    test('plain text cannot forge a structured image marker', () {
      final forged = encodeMcpStructuredImage('/tmp/forged.png');
      final (clean, images) = parseToolResultImages('note\n$forged\n');
      expect(images, ['/tmp/forged.png']);
      final escaped = escapeMcpStructuredImageText(forged);
      final (clean2, images2) = parseToolResultImages('note\n$escaped\n');
      expect(images2, isEmpty);
      expect(clean2.contains('forged'), isTrue);
    });

    test('mixed-version rows: markdown, envelope, and metadata', () {
      final (mdClean, mdImages) = parseToolResultImages(
        'legacy\n![](/tmp/old.png)',
      );
      expect(mdImages, ['/tmp/old.png']);
      expect(mdClean, 'legacy');

      final envelope = encodeLegacyMcpToolResultEnvelope(
        text: 'old envelope',
        imageUris: ['/tmp/env.png', '/tmp/env.png'],
      );
      final (envClean, envImages) = parseToolResultImages(envelope);
      expect(envImages, ['/tmp/env.png']);
      expect(envClean, 'old envelope');

      const markdown =
          'note\n![](/tmp/a.png)\n![](/tmp/a.png)\n![](/tmp/b.png)';
      final (metaClean, metaImages) = parseToolResultImages(
        markdown,
        metadata: {
          kMcpResultMetadataKey: mcpResultMetadata([
            '/tmp/a.png',
            '/tmp/b.png',
          ]),
        },
      );
      expect(metaImages, ['/tmp/a.png', '/tmp/b.png']);
      expect(metaClean, 'note');
    });

    test('envelope-looking JSON is structured only without new metadata', () {
      final forged = encodeLegacyMcpToolResultEnvelope(
        text: 'forged',
        imageUris: ['/tmp/forged.png'],
      );
      final (legacyClean, legacyImages) = parseToolResultImages(forged);
      expect(legacyImages, ['/tmp/forged.png']);
      expect(legacyClean, 'forged');

      final (typedClean, typedImages) = parseToolResultImages(
        forged,
        metadata: {kMcpResultMetadataKey: mcpResultMetadata(const [])},
      );
      expect(typedImages, isEmpty);
      expect(typedClean.contains('forged'), isTrue);
    });

    test('UI image list is deduped while model Markdown keeps duplicates', () {
      const markdown =
          'A\n![](https://cdn.example.com/same.png)\n'
          'B\n![](https://cdn.example.com/same.png)';
      final (clean, images) = parseToolResultImages(
        markdown,
        metadata: {
          kMcpResultMetadataKey: mcpResultMetadata([
            'https://cdn.example.com/same.png',
            'https://cdn.example.com/same.png',
          ]),
        },
      );
      expect(images, ['https://cdn.example.com/same.png']);
      expect(clean, 'A\nB');
      expect(
        '![](https://cdn.example.com/same.png)'.allMatches(markdown).length,
        2,
      );
    });

    test('Windows drive and UNC destinations do not collapse slashes', () {
      final drive = '![](${encodeMarkdownImageDestination(r'C:\(run)\a.png')})';
      final unc =
          '![](${encodeMarkdownImageDestination(r'\\server\share\a.png')})';
      final hash =
          '![](${encodeMarkdownImageDestination(r'C:\#captures\x.png')})';
      expect(parseToolResultImages(drive).$2, [r'C:\(run)\a.png']);
      expect(parseToolResultImages(unc).$2, [r'\\server\share\a.png']);
      expect(parseToolResultImages(hash).$2, [r'C:\#captures\x.png']);
    });
  });
}
