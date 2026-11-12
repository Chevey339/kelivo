import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/mcp_presentation.dart';
import 'package:Kelivo/core/services/mcp/mcp_icon_cache.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_resolved_icon.dart';

const _custom = 'https://icons.example/custom.svg';
const _declared = 'https://mcp.example/declared.svg';
const _favicon = 'https://mcp.example/favicon.ico';
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="red" d="M0 0h24v24H0z"/></svg>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('mcp-resolved-icon-');
    McpIconCache.clearMemory();
  });
  tearDown(() => directory.deleteSync(recursive: true));

  Future<String?> cache(String source, String? content) => McpIconCache.getPath(
    source,
    directory: directory,
    client: MockClient(
      (_) async => http.Response(content ?? '', content == null ? 404 : 200),
    ),
  );
  Future<void> mount(
    WidgetTester tester, {
    McpServerIcon? icon,
    Color color = const Color(0xff445599),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: McpResolvedIcon(
            icon: icon,
            sources: const [_declared, _favicon],
            size: 36,
            color: color,
            fallback: const Text('MCP fallback'),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  String renderedPath(WidgetTester tester) =>
      (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
              as SvgFileLoader)
          .file
          .path;

  testWidgets('custom image precedes declared image and cached favicon', (
    tester,
  ) async {
    final path = await tester.runAsync(() async {
      await cache(_favicon, _svg);
      await cache(_declared, _svg);
      return cache(_custom, _svg);
    });
    await mount(
      tester,
      icon: const McpServerIcon(type: McpIconType.url, value: _custom),
    );
    expect(renderedPath(tester), path);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed custom and declared images fall through to favicon', (
    tester,
  ) async {
    final path = await tester.runAsync(() async {
      await cache(_custom, null);
      await cache(_declared, null);
      return cache(_favicon, _svg);
    });
    await mount(
      tester,
      icon: const McpServerIcon(type: McpIconType.url, value: _custom),
    );
    expect(renderedPath(tester), path);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decoder failure advances to the next source', (tester) async {
    final path = await tester.runAsync(() async {
      await cache(
        _custom,
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="INVALID"/></svg>',
      );
      return cache(_declared, _svg);
    });
    await mount(
      tester,
      icon: const McpServerIcon(type: McpIconType.url, value: _custom),
    );
    expect(renderedPath(tester), path);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'emoji avoids remote resolution and disabled colored SVG is faded',
    (tester) async {
      await mount(
        tester,
        icon: const McpServerIcon(type: McpIconType.emoji, value: '🧰'),
      );
      expect(find.text('🧰'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      final path = await tester.runAsync(() => cache(_declared, _svg));
      await mount(
        tester,
        color: const Color(0xff445599).withValues(alpha: .55),
      );
      expect(renderedPath(tester), path);
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
        ColorFilter.mode(
          Colors.white.withValues(alpha: .55),
          BlendMode.modulate,
        ),
      );
    },
  );
}
