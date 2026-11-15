import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/mcp/mcp_icon_cache.dart';
import 'package:Kelivo/core/services/storage/storage_attachment_usage.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/markdown_media_sanitizer.dart';

import '../../../support/storage_images_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageImagesFixture fixture;
  setUp(() async => fixture = await StorageImagesFixture.create());
  tearDown(() async {
    await fixture.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'classifies actual references and includes appearance images once',
    () async {
      final avatar = await fixture.file('images/custom avatar.png');
      final background = await fixture.file('upload/shared.png');
      final provider = await fixture.file('avatars/provider.png');
      final user = await fixture.file('images/user.png');
      final tool = await fixture.file('images/tool.png');
      final preview = await fixture.file('images/preview.png');
      final chat = await fixture.file('images/generated.png');
      await fixture.file('images/orphan.png');
      await fixture.file('images/background_unused.png');
      await fixture.file('images/mcp_img_unused.png');
      await fixture.file('images/view_image_unused.png');
      await fixture.file('workspaces/ws/files/output.png');
      await fixture.assistants([
        {
          'id': 'a',
          'name': 'A',
          'avatar': avatar.uri.toString(),
          'background': 'kelivo-file:///upload/shared.png',
        },
      ]);
      await fixture.preferences.setString(
        'provider_configs_v1',
        jsonEncode({
          'p': {
            'name': 'P',
            'avatarType': 'file',
            'avatarValue': provider.path,
          },
        }),
      );
      await fixture.preferences.setString('avatar_type', 'file');
      await fixture.preferences.setString('avatar_value', user.path);
      await fixture.message([
        ImagePart(uri: background.path),
        ImagePart(uri: tool.path),
        ImagePart(uri: chat.path),
        ToolCallPart(
          jsonEncode({
            'name': 'view_image',
            'metadata': {
              'mcpResult': {
                'version': 1,
                'imageUris': [tool.path, tool.path],
              },
            },
          }),
        ),
        ToolCallPart(
          jsonEncode({
            'name': 'browser',
            'metadata': {
              'browser': {'previewImage': preview.path},
            },
          }),
        ),
      ]);

      final entries = await StorageUsageService.listUploadEntries(images: true);
      final byName = {for (final entry in entries) entry.name: entry};
      for (final name in [
        'custom avatar.png',
        'shared.png',
        'provider.png',
        'user.png',
      ]) {
        expect(byName[name]!.imageKind, StorageImageKind.avatar);
        expect(byName[name]!.isInUse, isTrue);
      }
      for (final name in [
        'tool.png',
        'preview.png',
        'mcp_img_unused.png',
        'view_image_unused.png',
      ]) {
        expect(byName[name]!.imageKind, StorageImageKind.tool);
        expect(
          byName[name]!.isInUse,
          name == 'tool.png' || name == 'preview.png',
        );
      }
      expect(byName['generated.png']!.imageKind, StorageImageKind.chat);
      expect(byName['orphan.png']!.imageKind, isNull);
      expect(
        byName['background_unused.png']!.imageKind,
        StorageImageKind.avatar,
      );
      expect(byName['background_unused.png']!.isInUse, isFalse);
      expect(byName, isNot(contains('output.png')));
      expect(entries, hasLength(11));
      final report = await StorageUsageService.computeReport();
      final images = report.categories.singleWhere(
        (c) => c.key == StorageUsageCategoryKey.images,
      );
      expect(images.stats.fileCount, entries.length);
      expect(
        images.stats.bytes,
        entries.fold<int>(0, (sum, e) => sum + e.bytes),
      );
      expect(
        await StorageUsageService.deleteUploadFiles(
          entries.map((e) => e.path),
          images: true,
        ),
        4,
      );
      for (final file in [
        avatar,
        background,
        provider,
        user,
        tool,
        preview,
        chat,
      ]) {
        expect(await file.exists(), isTrue);
      }
    },
  );

  test(
    'deletion rechecks new and shared appearance references, including aliases',
    () async {
      final image = await fixture.file('images/reused.png');
      final before = await StorageUsageService.listUploadEntries(images: true);
      expect(before.single.isInUse, isFalse);
      await fixture.assistants([
        {'id': 'a', 'name': 'A', 'background': image.uri.toString()},
        {'id': 'b', 'name': 'B', 'avatar': await image.resolveSymbolicLinks()},
      ]);
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        0,
      );
      await fixture.assistants([
        {'id': 'b', 'name': 'B', 'avatar': image.path},
      ]);
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        0,
      );
      await fixture.assistants([]);
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        1,
      );
      expect(await image.exists(), isFalse);
    },
  );

  test(
    'model file avatars remain protected until their last model reference is removed',
    () async {
      final image = await fixture.file('avatars/model.png');
      final before = await StorageUsageService.listUploadEntries(images: true);
      expect(before.single.isInUse, isFalse);
      Map<String, Object?> provider(String key, String path) => {
        'name': key,
        'models': [key],
        'disabledModels': [key],
        'modelOverrides': {
          key: {
            'apiModelId': 'same-model',
            'avatar': {'type': 'file', 'value': path},
          },
        },
      };
      final providers = {
        'A': provider('model', image.path),
        'B': provider('alias', await image.resolveSymbolicLinks()),
      };
      await fixture.preferences.setString(
        'provider_configs_v1',
        jsonEncode(providers),
      );
      final entries = await StorageUsageService.listUploadEntries(images: true);
      expect(entries.single.isInUse, isTrue);
      expect(entries.single.imageKind, StorageImageKind.avatar);
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        0,
      );
      providers.remove('A');
      await fixture.preferences.setString(
        'provider_configs_v1',
        jsonEncode(providers),
      );
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        0,
      );
      expect(await image.exists(), isTrue);
      await fixture.preferences.setString(
        'provider_configs_v1',
        jsonEncode({
          'B': {
            'name': 'B',
            'models': ['alias'],
            'modelOverrides': {
              'alias': {'apiModelId': 'same-model'},
            },
          },
        }),
      );
      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        1,
      );
      expect(await image.exists(), isFalse);
    },
  );

  test(
    'classifies rendered Markdown images without treating code samples as uses',
    () async {
      final markdown = await MarkdownMediaSanitizer.replaceInlineBase64Images(
        'Generated: ![image](data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 2, height: 2)))})',
      );
      final spaced = await fixture.file('images/local path.png');
      final reference = await fixture.file('images/reference.png');
      final html = await fixture.file('images/html.png');
      final code = await fixture.file('images/code.png');
      final inlineCode = await fixture.file('images/inline-code.png');
      await fixture.message([
        TextPart('''$markdown

![Local](${spaced.path})

![Reference][picture]

[picture]: <${reference.uri}>

<img src="${html.uri}">

```markdown
![Example](${code.uri})
```

`![Inline example](${inlineCode.uri})`
'''),
      ]);
      final entries = await StorageUsageService.listUploadEntries(images: true);
      expect(entries, hasLength(6));
      for (final entry in entries) {
        expect(
          entry.imageKind,
          entry.path == code.path || entry.path == inlineCode.path
              ? isNull
              : StorageImageKind.chat,
          reason: entry.name,
        );
      }
    },
  );

  test(
    'storage details preserve local files referenced by decorated file URIs',
    () async {
      final image = await fixture.file("images/John's photo (1) #1.png");
      final pdf = await fixture.file('upload/manual #1.pdf');
      final unused = await fixture.file('upload/unreferenced.pdf');
      final pdfLink = pdf.uri
          .replace(fragment: 'page=2')
          .toString()
          .replaceFirst('file:', 'FILE:');
      final imageLink = image.uri.replace(
        host: 'localhost',
        query: 'width=200',
      );
      final remote = unused.uri.replace(host: 'files.example');
      await fixture.message([
        TextPart('[Page]($pdfLink)'),
        TextPart('[Remote]($remote)'),
        ToolCallPart(
          jsonEncode({
            'result': 'Preview saved at $imageLink',
            'unreadable': 'file:///tmp/%FF.png',
          }),
        ),
      ]);

      final images = await StorageUsageService.listUploadEntries(images: true);
      expect(images.single.path, image.path);
      expect(images.single.isInUse, isTrue);
      expect(images.single.imageKind, StorageImageKind.tool);
      final files = await StorageUsageService.listUploadEntries(images: false);
      final document = files.singleWhere((entry) => entry.path == pdf.path);
      expect(document.isInUse, isTrue);
      expect(document.conversations.values, ['Images']);
      expect(
        files.singleWhere((entry) => entry.path == unused.path).isInUse,
        isFalse,
      );

      expect(
        await StorageUsageService.deleteUploadFiles([image.path], images: true),
        0,
      );
      expect(
        await StorageUsageService.deleteUploadFiles([
          pdf.path,
          unused.path,
        ], images: false),
        1,
      );
      expect(await pdf.exists(), isTrue);
      expect(await image.exists(), isTrue);
      expect(await unused.exists(), isFalse);
    },
  );

  test(
    'quoted tool links retain filename punctuation and stay separate',
    () async {
      final first = await fixture.file("images/John's (edited).png");
      final second = await fixture.file('images/photo (2).png');
      final markdown = await fixture.file("images/Sara's copy (3).png");
      final adjacent = await fixture.file('images/near.png');
      final fields = await fixture.file("images/Peter's (4).png");
      final sentence = await fixture.file("images/June's notes.png");
      final xml = await fixture.file('images/xml.png');
      final output = await fixture.file('sessions/demo/outputs/report(2)');
      await fixture.message([
        ToolCallPart(
          jsonEncode({
            'previews': "['${first.uri}','${second.uri}']",
            'result': 'Saved (${output.uri}).',
            'markdown': '已保存[高清图](${markdown.uri})，请查看',
            'comparison': '[图](${adjacent.uri})[对比](${second.uri})',
            'fields': "{'preview':'${fields.uri}','status':'ok'}",
            'sentence': "Preview saved to '${sentence.uri}'.",
            'xml': "<resource uri='${xml.uri}'/>",
          }),
        ),
      ]);
      final usage = await StorageAttachmentUsage.load();
      for (final file in [
        first,
        second,
        markdown,
        adjacent,
        fields,
        sentence,
        xml,
        output,
      ]) {
        expect(usage.isInUse(file.path), isTrue, reason: file.path);
      }
    },
  );

  test(
    'a malformed terminal link in tool output cannot block file lookup or cleanup',
    () async {
      final unused = await fixture.file('upload/unused.pdf');
      await fixture.message([
        const ToolCallPart(
          '{"result":"For reference, KELIVO://terminal?cmd=echo+100%"}',
        ),
      ]);
      final files = await StorageUsageService.listUploadEntries(images: false);
      expect(files.single.path, unused.path);
      expect(files.single.isInUse, isFalse);
      expect(
        await StorageUsageService.deleteUploadFiles([
          unused.path,
        ], images: false),
        1,
      );
    },
  );

  for (final svg in [false, true]) {
    test('protects imported MCP icons in file cleanup (svg=$svg)', () async {
      final source = await fixture.file(
        'incoming',
        svg
            ? utf8.encode(
                '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"><rect width="2" height="2" fill="red"/></svg>',
              )
            : img.encodePng(img.Image(width: 2, height: 2)),
      );
      final name = await McpIconCache.importFile(source.path);
      final path = (await McpIconCache.localPath(name))!;
      await fixture.preferences.setString(
        'mcp_presentation_v1',
        jsonEncode({
          'servers': {
            'server': {
              'icon': {'type': 'file', 'value': name},
            },
          },
        }),
      );
      final entries = await StorageUsageService.listUploadEntries(
        images: false,
      );
      expect(entries.single.path, path);
      expect(entries.single.isInUse, isTrue);
      expect(
        await StorageUsageService.deleteUploadFiles([path], images: false),
        0,
      );
      expect(await File(path).exists(), isTrue);
      await fixture.preferences.remove('mcp_presentation_v1');
      expect(
        await StorageUsageService.deleteUploadFiles([path], images: false),
        1,
      );
    });
  }

  test('an unreadable reference database cannot authorize deletion', () async {
    final image = await fixture.file('images/keep.png');
    await fixture.database.close();
    final root = await AppDirectories.getAppDataDirectory();
    await File('${root.path}/kelivo.db').writeAsString('broken database');
    await expectLater(
      StorageUsageService.deleteUploadFiles([image.path], images: true),
      throwsA(anything),
    );
    expect(await image.exists(), isTrue);
  });

  test('iOS uses private database references for public image files', () async {
    await fixture.dispose();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fixture = await StorageImagesFixture.create();
    final image = await fixture.file('images/ios.png');
    await fixture.assistants([
      {'id': 'a', 'name': 'A', 'background': 'kelivo-file:///images/ios.png'},
    ]);
    final entries = await StorageUsageService.listUploadEntries(images: true);
    expect(entries.single.imageKind, StorageImageKind.avatar);
    expect(entries.single.isInUse, isTrue);
    expect(
      await StorageUsageService.deleteUploadFiles([image.path], images: true),
      0,
    );
  });
}
