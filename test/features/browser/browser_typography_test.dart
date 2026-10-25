import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_bookmark_editor.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_find_bar.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  const family = 'BrowserCustomFont';
  const fallback = ['BrowserFallback'];
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    final desktop =
        platform == TargetPlatform.macOS || platform == TargetPlatform.windows;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    for (final kind in ['address', 'find', 'search', 'bookmark']) {
      testWidgets(
        '$kind input and placeholder use app font, platform=$platform',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = TextEditingController();
          final focus = FocusNode();
          final content = switch (kind) {
            'address' => BrowserAddressBar(
              controller: controller,
              focusNode: focus,
              onSubmitted: (_) {},
              loading: false,
              progress: 0,
              onReload: () {},
              secure: false,
              compact: desktop,
            ),
            'find' => BrowserFindBar(
              controller: controller,
              focusNode: focus,
              onChanged: (_) {},
              onSubmitted: (_) {},
              onPrevious: () {},
              onNext: () {},
              onDone: () {},
              compact: desktop,
            ),
            'search' => BrowserSurfaceField(
              controller: controller,
              focusNode: focus,
              hintText: apple ? '搜索标签页' : 'Search saved pages',
              prefixIcon: LucideIcons.search,
            ),
            _ => BrowserBookmarkEditor(
              bookmark: BrowserBookmark(
                title: '',
                url: '',
                createdAt: DateTime(2026),
              ),
              fullPage: !desktop,
            ),
          };
          final baseTheme = ThemeData(
            platform: platform,
            fontFamily: family,
            fontFamilyFallback: fallback,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: apple && kind == 'search'
                  ? baseTheme.copyWith(
                      textTheme: baseTheme.textTheme.copyWith(
                        bodyMedium: baseTheme.textTheme.bodyMedium!.copyWith(
                          textBaseline: TextBaseline.ideographic,
                        ),
                      ),
                    )
                  : baseTheme,
              locale: Locale(apple && kind == 'search' ? 'zh' : 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            controller.dispose();
            focus.dispose();
          });

          void expectFont(TextStyle style) {
            expect(style.fontFamily, family);
            expect(style.fontFamilyFallback, fallback);
          }

          expect(
            find.byType(CupertinoTextField),
            apple ? findsWidgets : findsNothing,
          );
          expect(find.byType(TextField), apple ? findsNothing : findsWidgets);
          final fields = find.byType(BrowserTextField);
          expect(fields, findsNWidgets(kind == 'bookmark' ? 2 : 1));
          for (var index = 0; index < fields.evaluate().length; index++) {
            final field = fields.at(index);
            final hint = tester.widget<BrowserTextField>(field).placeholder;
            if (hint != null) {
              final placeholder = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: field,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is RichText && widget.text.toPlainText() == hint,
                  ),
                ),
              );
              expectFont(placeholder.text.style!);
              if (kind == 'search') {
                final icon = find.byIcon(LucideIcons.search);
                final paragraphRect =
                    placeholder.localToGlobal(Offset.zero) & placeholder.size;
                expect(
                  paragraphRect.center.dy,
                  closeTo(tester.getCenter(icon).dy, 1),
                  reason:
                      'The search placeholder stays centered beside its icon.',
                );
              }
            } else {
              // Desktop bookmark fields use visible labels, not placeholders.
              expect((kind, desktop), ('bookmark', true));
            }
            await tester.enterText(field, 'Custom font text');
            await tester.pump();
            final editable = tester.state<EditableTextState>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            );
            expectFont(editable.renderEditable.text!.style!);
          }
          if (kind == 'bookmark') {
            for (final label in ['Edit bookmark', 'Save']) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: find.text(label),
                  matching: find.byType(RichText),
                ),
              );
              expectFont(paragraph.text.style!);
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
