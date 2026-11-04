import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_content.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/shared/markdown/markdown_theme_mapper.dart';
import 'package:Kelivo/shared/markdown/kelivo_markdown_extensions.dart'
    show markdownCodeOptions;
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';

import '../../support/business_test_harness.dart';
import 'markstream_adapters_test.dart' show host;

void main() {
  for (final wallpaper in [false, true]) {
    testWidgets(
      'code block preference leaves generated mono text unchanged: wallpaper=$wallpaper',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        await settings.loaded;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => GenUiThemeScope(
                markdownTheme: mapMarkdownTheme(
                  context,
                  context.watch<SettingsProvider>(),
                  null,
                ),
                child: const GenUiText(text: 'v = a * x + b', variant: 'mono'),
              ),
            ),
            settings: settings,
            wallpaper: wallpaper,
          ),
        );
        await tester.pumpAndSettle();
        final before = GenUiTheme.of(tester.element(find.byType(GenUiText)));
        for (final enabled in [true, false]) {
          await settings.setUseLegacyCodeBlockStyle(enabled);
          await tester.pumpAndSettle();
          final after = GenUiTheme.of(tester.element(find.byType(GenUiText)));
          expect(after.body, before.body);
          expect(after.mono, before.mono);
          expect(after.markdown.chrome, before.markdown.chrome);
          expect(
            tester.widget<GenUiText>(find.byType(GenUiText)).text,
            'v = a * x + b',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      'code block preference updates live without resetting content or other styles: dark=$dark',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        await settings.loaded;
        await settings.setAutoCollapseCodeBlock(false);
        await settings.setAutoCollapseCodeBlockLines(2);
        final code = List.generate(8, (i) => 'final value$i = $i;').join('\n');
        markdownCodeOptions(
          settings,
        ).expansionState!.remember('dart', code, true);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          host(
            MarkdownWithCodeHighlight(
              text:
                  'Before `inline` <kbd>Ctrl</kbd>\n\n```dart\n$code\n```\n\n| Header |\n| --- |\n| Value |',
            ),
            settings: settings,
            dark: dark,
            wallpaper: dark,
          ),
        );
        await tester.pumpAndSettle();
        final view = find.byType(MarkstreamView);
        final block = find.byType(MarkstreamCodeBlock);
        final state = tester.state(block);
        final modern = tester.widget<MarkstreamView>(view).theme!;
        expect(settings.useLegacyCodeBlockStyle, isFalse);
        expect(modern.code.chrome, modern.chrome);

        await tester.tap(find.byKey(const ValueKey('markstream-code-toggle')));
        await tester.pumpAndSettle();
        final toggle = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.key == const ValueKey('markstream-code-toggle'),
        );
        expect(tester.widget<Semantics>(toggle).properties.expanded, isFalse);

        // Both preferences can be used independently and together.
        await settings.setUseLegacyInlineCodeStyle(true);
        await tester.pumpAndSettle();
        final inlineOnly = tester.widget<MarkstreamView>(view).theme!;
        expect(inlineOnly.code, modern.code);
        for (final enabled in [true, false, true]) {
          await settings.setUseLegacyCodeBlockStyle(enabled);
          await tester.pumpAndSettle();
          final theme = tester.widget<MarkstreamView>(view).theme!;
          expect(tester.state(block), same(state));
          expect(theme.copyWith(code: modern.code), inlineOnly);
          expect(theme.code == modern.code, !enabled);
          expect(settings.useLegacyInlineCodeStyle, isTrue);
          expect(tester.widget<Semantics>(toggle).properties.expanded, isFalse);
          await tester.tap(
            find.descendant(of: block, matching: find.byTooltip('Copy')),
          );
          await tester.pumpAndSettle();
          expect(copied, tester.widget<MarkstreamCodeBlock>(block).node.code);
          expect(copied, contains('value7'));
          expect(tester.takeException(), isNull);
          // The app's shared copy notification outlives its overlay widget.
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
        await settings.setUseLegacyInlineCodeStyle(false);
        await tester.pumpAndSettle();
        expect(
          tester.widget<MarkstreamView>(view).theme!.inlineCode,
          modern.inlineCode,
        );
        expect(settings.useLegacyCodeBlockStyle, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
}
