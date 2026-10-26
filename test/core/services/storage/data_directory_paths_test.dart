import 'dart:convert';

import 'package:Kelivo/core/services/storage/data_directory_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/markdown/markdown_image_sources.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  final paths = DataDirectoryPaths(
    r'C:\Users\Alice\AppData\Roaming\Kelivo',
    r'D:\聊天数据',
  );

  test('rewrites Windows native, slash and file URI paths in payloads', () {
    final before = jsonEncode({
      'avatar': r'C:\Users\Alice\AppData\Roaming\Kelivo\avatars\me.png',
      'cwd': 'c:/users/alice/appdata/roaming/kelivo/workspaces/one/files',
      'markdown':
          '![image](file:///C:/Users/Alice/AppData/Roaming/Kelivo/images/a%20b.png)',
      'external': r'C:\Users\Alice\Pictures\photo.png',
      'portable': 'kelivo-file:///images/foo.png',
      'other': r'C:\Users\Alice\AppData\Roaming\Kelivo-copy\images\a.png',
      'nested': jsonEncode({
        'output': r'C:\Users\Alice\AppData\Roaming\Kelivo\sessions\one\out.txt',
      }),
    });
    final after = jsonDecode(paths.rewrite(before));
    expect(after['avatar'], r'D:\聊天数据\avatars\me.png');
    expect(after['cwd'], 'D:/聊天数据/workspaces/one/files');
    expect(markdownImageSources(after['markdown'] as String), [
      'file:///D:/%E8%81%8A%E5%A4%A9%E6%95%B0%E6%8D%AE/images/a%20b.png',
    ]);
    expect(after['external'], r'C:\Users\Alice\Pictures\photo.png');
    expect(after['portable'], 'kelivo-file:///images/foo.png');
    expect(
      after['other'],
      r'C:\Users\Alice\AppData\Roaming\Kelivo-copy\images\a.png',
    );
    expect(
      jsonDecode(after['nested'])['output'],
      r'D:\聊天数据\sessions\one\out.txt',
    );
  });

  test(
    'rewrites JSON encoded primitive preferences without changing unrelated formatting',
    () {
      final before = jsonEncode(
        r'C:\Users\Alice\AppData\Roaming\Kelivo\fonts\font.ttf',
      );
      expect(jsonDecode(paths.rewrite(before)), r'D:\聊天数据\fonts\font.ttf');
      const unrelated = '{ "value": "https://example.com/image.png" }';
      expect(paths.rewrite(unrelated), unrelated);
    },
  );

  test(
    'Markdown image destinations survive spaces and unmatched parentheses',
    () {
      for (final target in [
        r'D:\My Data',
        r'D:\My) Data',
        r'D:\My( Data',
        r'D:\A&B [Data]',
      ]) {
        final rewriter = DataDirectoryPaths(r'C:\Data', target);
        final next = rewriter.rewrite(
          'before ![img](C:/Data/images/a.png "title") after',
        );
        expect(markdownImageSources(next), [
          '${target.replaceAll(r'\', '/')}/images/a.png',
        ]);
        final paragraph = MarkdownParser().parse(next).children.single;
        expect(paragraph.children.whereType<ImageNode>().single.title, 'title');
        expect(next.startsWith('before '), isTrue);
        expect(next.endsWith(' after'), isTrue);
      }
    },
  );

  test('rewrites nested images, ordinary links and reference destinations', () {
    final rewriter = DataDirectoryPaths(r'C:\Data', r'D:\New) Data');
    const before =
        '[![thumbnail](C:/Data/images/a.png)](C:/Data/upload/file.txt)\n\n'
        '![again][asset]\n\n[asset]: C:/Data/images/b.png "caption"';
    final next = rewriter.rewrite(before);
    expect(markdownImageSources(next), [
      'D:/New) Data/images/a.png',
      'D:/New) Data/images/b.png',
    ]);
    final link =
        MarkdownParser().parse(next).children.first.children.single as LinkNode;
    expect(link.destination, 'D:/New) Data/upload/file.txt');
  });
}
