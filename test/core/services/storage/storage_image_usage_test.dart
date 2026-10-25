import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/mcp/mcp_icon_cache.dart';
import 'package:Kelivo/core/services/storage/storage_image_usage.dart';
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
        expect(byName[name]!.isInUse, isFalse);
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
        7,
      );
      for (final file in [avatar, background, provider, user]) {
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
