import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState, Tristate;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/desktop/setting/mcp_pane.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_avatar.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_card.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_error_details_sheet.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/theme/palettes.dart';

import '../../../support/mcp_presentation_harness.dart';
import '../../../support/mcp_golden_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMcpGoldenFonts);

  testWidgets('avatar without a resolver uses the bundled MCP mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: McpServerAvatar(
          server: presentationServer('github', 'GitHub'),
          size: 28,
          radius: 8,
        ),
      ),
    );
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      'assets/icons/mcp.svg',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('one injected resolver is used by every avatar', (tester) async {
    await tester.pumpWidget(
      Provider<McpIconResolver?>.value(
        value: (context, server, size, color) => Text(
          '🌱',
          style: TextStyle(fontSize: size * .5, color: color),
        ),
        child: MaterialApp(
          home: McpServerAvatar(
            server: presentationServer('custom', 'Custom'),
            size: 36,
            radius: 10,
          ),
        ),
      ),
    );
    expect(find.text('🌱'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('connected card stays compact and has one readable summary', (
    tester,
  ) async {
    final harness = await McpPresentationHarness.create();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      harness.app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 430,
              child: McpServerCard(
                server: harness.mcp.items.first,
                status: McpStatus.connected,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(McpServerCard)).height,
      inInclusiveRange(58, 62),
    );
    final node = tester.getSemantics(find.byType(McpServerCard));
    expect(node.label, 'GitHub, Connected · HTTP · Tools 18/26');
    expect(node.flagsCollection.isButton, isTrue);
    expect(
      find.descendant(
        of: find.byType(McpServerCard),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(McpServerCard),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(McpServerCard),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  for (final desktop in [false, true]) {
    for (final selected in [false, true]) {
      testWidgets(
        'selection hides trailing controls desktop=$desktop selected=$selected',
        (tester) async {
          final harness = await McpPresentationHarness.create();
          final semantics = tester.ensureSemantics();

          var taps = 0;
          await tester.pumpWidget(
            harness.app(
              Scaffold(
                body: McpServerCard(
                  server: harness.mcp.items.first,
                  status: McpStatus.connected,
                  selectionMode: true,
                  selected: selected,
                  onTap: () => taps++,
                  onEnabledChanged: desktop ? (_) {} : null,
                ),
              ),
            ),
          );
          expect(find.byIcon(Lucide.ChevronRight), findsNothing);
          expect(find.byType(IosSwitch), findsNothing);
          final node = tester.getSemantics(find.byType(McpServerCard));
          expect(node.flagsCollection.isChecked, isNot(CheckedState.none));
          expect(node.flagsCollection.isEnabled, Tristate.isTrue);
          expect(
            node.flagsCollection.isChecked,
            selected ? CheckedState.isTrue : CheckedState.isFalse,
          );
          expect(node.label, startsWith('Select GitHub'));
          await tester.tap(find.text('GitHub'));
          expect(taps, 1);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'connecting and authorization omit tools and isolate the spinner',
    (tester) async {
      final harness = await McpPresentationHarness.create();
      for (final status in [McpStatus.connecting, McpStatus.authorizing]) {
        await tester.pumpWidget(
          harness.app(
            Scaffold(
              body: McpServerCard(
                server: harness.mcp.items.first,
                status: status,
                onTap: () {},
              ),
            ),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.textContaining('Tools 18/26', findRichText: true),
          findsNothing,
        );
        expect(
          tester.getSize(find.byType(CircularProgressIndicator)),
          const Size(10, 10),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('authorization footer fits 320px at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create();
      var authorized = false;
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: McpServerCard(
                  server: harness.mcp.items.first,
                  status: McpStatus.needsAuthorization,
                  error: 'McpError: HTTP 401: Unauthorized',
                  onTap: () {},
                  onDetails: () {},
                  onAuthorize: () => authorized = true,
                ),
              ),
            ),
          ),
          textScale: scale,
          fontFamily: 'mcp-golden',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNothing);
      await tester.tap(find.text('Sign in with OAuth'));
      expect(authorized, isTrue);
    });
  }

  testWidgets('disabled card overrides a stale connection status', (
    tester,
  ) async {
    final harness = await McpPresentationHarness.create();
    await tester.pumpWidget(
      harness.app(
        Scaffold(
          body: McpServerCard(
            server: harness.mcp.items.first.copyWith(enabled: false),
            status: McpStatus.connecting,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.textContaining('Disabled · HTTP · Tools 18/26', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('GitHub')).style!.color!.a,
      closeTo(.55, .001),
    );
  });

  testWidgets(
    'details opens the existing error sheet without editing the server',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await McpPresentationHarness.create(count: 1);
      harness.mcp.statuses['server-0'] = McpStatus.error;
      harness.mcp.errors['server-0'] =
          '401 Unauthorized\nFull diagnostic detail';
      await tester.pumpWidget(harness.app(const McpPage()));
      await tester.pumpAndSettle();
      expect(find.text('401 Unauthorized'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(IosTextButton, 'Details')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.byType(McpErrorDetailsSheet), findsOneWidget);
      expect(find.textContaining('Full diagnostic detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop toggle updates enabled metadata without opening edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await McpPresentationHarness.create(count: 1);
    await tester.pumpWidget(harness.app(const McpPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IosSwitch));
    await tester.pumpAndSettle();
    expect(harness.mcp.items.single.enabled, isFalse);
    expect(find.byType(McpPage), findsOneWidget);
    expect(
      find.textContaining('Disabled · HTTP', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('desktop pane retains reordering and the inline toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await McpPresentationHarness.create();
    await tester.pumpWidget(
      harness.app(const Scaffold(body: DesktopMcpPane())),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('desktop-mcp-server-0'));
    await tester.tap(
      find.descendant(of: first, matching: find.byType(IosSwitch)),
    );
    await tester.pumpAndSettle();
    expect(harness.mcp.items.first.enabled, isFalse);
    final drag = await tester.startGesture(
      tester.getCenter(find.text('GitHub')),
    );
    await drag.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 250));
    await drag.moveTo(
      tester.getBottomLeft(find.byKey(const ValueKey('desktop-mcp-server-2'))) +
          const Offset(120, 40),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(harness.mcp.items.map((server) => server.id), [
      'server-1',
      'server-2',
      'server-0',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large Chinese and English text can grow without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await McpPresentationHarness.create();
    for (final locale in [
      const Locale('en'),
      const Locale('zh'),
      const Locale('zh', 'TW'),
    ]) {
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Column(
              children: [
                McpServerCard(
                  server: presentationServer(
                    'auth',
                    'A very long MCP server name',
                  ),
                  status: McpStatus.needsAuthorization,
                  error: 'Authorization expired. Please sign in to reconnect.',
                  onTap: () {},
                  onDetails: () {},
                  onAuthorize: () {},
                ),
              ],
            ),
          ),
          textScale: 1.3,
          locale: locale,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(McpServerCard)).height,
        greaterThan(58),
      );
    }
  });

  testWidgets(
    'secondary and state colors meet contrast on all bundled palettes',
    (tester) async {
      for (final palette in ThemePalettes.all) {
        for (final scheme in [palette.light, palette.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey("${palette.id}-${scheme.brightness}"),
              theme: ThemeData(colorScheme: scheme),
              home: Builder(
                builder: (context) {
                  final background = context.appColors.surfaceCard;
                  final secondary = mcpReadableColor(
                    scheme.onSurface.withValues(alpha: .6),
                    background,
                    scheme.onSurface,
                  );
                  expect(
                    _contrast(secondary, background),
                    greaterThanOrEqualTo(4.5),
                    reason: '${palette.id} ${scheme.brightness}',
                  );
                  for (final status in McpStatus.values) {
                    expect(
                      _contrast(mcpStatusColor(context, status), background),
                      greaterThanOrEqualTo(3),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          );
        }
      }
    },
  );
}

double _contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}
