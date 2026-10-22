import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_surface.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/shared/markdown/markdown_surface_scope.dart';
import 'package:Kelivo/shared/markdown/markdown_theme_mapper.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../support/business_test_harness.dart';

class _Assistants extends AssistantProvider {
  _Assistants() : super(preferences: createBusinessTestPreferences());
  Assistant? replacement;
  @override
  Assistant? get currentAssistant => replacement ?? super.currentAssistant;
  void replace(Assistant assistant) {
    replacement = assistant;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'stable backdrop selection, nested surfaces, and opaque exports',
    (tester) async {
      final assistants = _Assistants();
      final settings = SettingsProvider(createBusinessTestPreferences());
      ChatFrostedBackdropController? controller;
      addTearDown(assistants.dispose);
      addTearDown(settings.dispose);
      await assistants.loaded;
      await settings.loaded;
      assistants.replace(Assistant(id: 'backdrop', name: 'Backdrop'));

      MarkstreamTheme? selected;
      var builds = 0;
      Widget app({
        bool chat = true,
        bool exporting = false,
        MarkdownSurfaceKind? surface,
        bool markdown = false,
      }) {
        Widget child = Builder(
          builder: (context) {
            builds++;
            controller =
                ChatFrostedBackdropScope.maybeOf(context)?.controller ??
                controller;
            selected = mapMarkdownTheme(context, settings, null);
            return markdown
                ? const MarkdownWithCodeHighlight(
                    text: '```text\ncode\n```\n\n| A |\n| --- |\n| B |',
                  )
                : const SizedBox();
          },
        );
        if (surface != null) {
          child = MarkdownSurfaceScope(kind: surface, child: child);
        }
        child = ExportCaptureScope(enabled: exporting, child: child);
        child = SingleChildScrollView(child: child);
        if (chat) {
          child = ChatFrostedBackdrop(
            backdrop: const ColoredBox(color: Colors.blueGrey),
            child: child,
          );
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: child),
          ),
        );
      }

      await tester.pumpWidget(app());
      expect(selected!.backdrop, MarkstreamBackdrop.plain);
      assistants.replace(
        assistants.currentAssistant!.copyWith(
          background: 'https://example.com/wallpaper.png',
        ),
      );
      await tester.pump();
      expect(selected!.backdrop, MarkstreamBackdrop.wallpaper);
      for (final pair in [
        (MarkdownSurfaceKind.frosted, MarkstreamBackdrop.frostedBubble),
        (MarkdownSurfaceKind.tinted, MarkstreamBackdrop.wallpaper),
        (MarkdownSurfaceKind.solid, MarkstreamBackdrop.solidBubble),
      ]) {
        await tester.pumpWidget(app(surface: pair.$1));
        expect(selected!.backdrop, pair.$2);
      }
      await tester.pumpWidget(app(chat: false));
      expect(selected!.backdrop, MarkstreamBackdrop.plain);
      final plain = selected;
      await settings.setChatBackgroundMaskStrength(0);
      await tester.pumpWidget(app(chat: false));
      expect(selected, plain);
      await tester.pumpWidget(
        app(
          exporting: true,
          markdown: true,
          surface: MarkdownSurfaceKind.frosted,
        ),
      );
      final exported = tester.widget<MarkstreamView>(
        find.byType(MarkstreamView),
      );
      expect(exported.exporting, isTrue);
      expect(exported.theme!.backdrop, MarkstreamBackdrop.plain);
      expect(exported.theme!.code.backgroundColor.a, 1);
      expect(exported.theme!.table.bodyBackgroundColor.a, 1);
      assistants.replace(
        assistants.currentAssistant!.copyWith(
          background: '',
          useGradientBackground: true,
        ),
      );
      await tester.pumpWidget(app());
      final gradientTheme = selected;
      final stableBuilds = builds;
      assistants.replace(
        assistants.currentAssistant!.copyWith(gradientBackgroundPhase: .5),
      );
      controller!.applyBackdropState(wallpaperActive: true, enterLive: true);
      await tester.pump();
      expect(selected!.backdrop, MarkstreamBackdrop.wallpaper);
      expect(selected, gradientTheme);
      expect(builds, stableBuilds);
    },
  );

  testWidgets(
    'shared surfaces publish context without new compositing layers',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      MarkdownSurfaceKind? kind;
      Future<void> show(
        ChatMessageBackgroundStyle style, {
        Color? tint,
        bool bare = false,
      }) async {
        await settings.setChatMessageBackgroundStyle(style);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              home: Builder(
                builder: (context) => buildSharedChatSurface(
                  context,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(12),
                  defaultColor: tint,
                  bareOnDefault: bare,
                  child: Builder(
                    builder: (context) {
                      kind = MarkdownSurfaceScope.maybeOf(context)?.kind;
                      return const SizedBox(width: 100, height: 100);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await show(ChatMessageBackgroundStyle.frosted);
      expect(kind, MarkdownSurfaceKind.frosted);
      await show(ChatMessageBackgroundStyle.solid);
      expect(kind, MarkdownSurfaceKind.solid);
      await show(ChatMessageBackgroundStyle.defaultStyle, tint: Colors.blue);
      expect(kind, MarkdownSurfaceKind.tinted);
      await show(
        ChatMessageBackgroundStyle.defaultStyle,
        tint: Colors.blue,
        bare: true,
      );
      expect(kind, isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(CompositedTransformFollower), findsNothing);
      final layers = <Layer>[];
      void visit(Layer layer) {
        layers.add(layer);
        if (layer is ContainerLayer) {
          for (
            var child = layer.firstChild;
            child != null;
            child = child.nextSibling
          ) {
            visit(child);
          }
        }
      }

      visit(tester.binding.renderViews.first.debugLayer!);
      expect(layers.whereType<BackdropFilterLayer>(), isEmpty);
    },
  );
}
