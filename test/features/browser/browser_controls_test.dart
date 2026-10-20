import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  const shadows = [
    Shadow(color: Color(0x66000000), offset: Offset(0, .5), blurRadius: 0),
  ];
  for (final (name, editing, text) in [
    ('display', false, 'example.com'),
    ('editing', true, 'example.com'),
    ('placeholder', true, ''),
  ]) {
    testWidgets('dark toolbar keeps foreground edge styling in $name', (
      tester,
    ) async {
      final controller = TextEditingController(text: text);
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                BrowserActionButton(
                  label: 'Back',
                  icon: LucideIcons.chevronLeft,
                  onPressed: () {},
                  foregroundShadows: shadows,
                ),
                Expanded(
                  child: BrowserAddressBar(
                    controller: controller,
                    focusNode: focus,
                    onSubmitted: (_) {},
                    loading: false,
                    progress: 0,
                    onReload: null,
                    onPageMenu: () {},
                    secure: true,
                    editing: editing,
                    displayText: text,
                    foregroundShadows: shadows,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final button in find.byType(BrowserActionButton).evaluate()) {
        final widget = button.widget as BrowserActionButton;
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byWidget(widget),
            matching: find.byType(RichText),
          ),
        );
        expect(
          paragraph.text.style!.shadows,
          widget.onPressed != null ? shadows : isEmpty,
        );
      }
      if (editing) {
        final field = tester.widget<CupertinoTextField>(
          find.byType(CupertinoTextField),
        );
        expect(field.placeholderStyle!.shadows, shadows);
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        expect(editable.text!.style!.shadows, shadows);
      }
      final visibleText = editing && text.isEmpty
          ? tester
                .widget<CupertinoTextField>(find.byType(CupertinoTextField))
                .placeholder!
          : text;
      if (!editing || text.isEmpty) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == visibleText,
          ),
        );
        expect(paragraph.text.style!.shadows, shadows);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
