import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/desktop_context_menu.dart';
import 'package:Kelivo/features/media/widgets/creation_menu.dart';
import 'package:Kelivo/features/media/widgets/creation_picker.dart';
import 'package:Kelivo/features/media/widgets/creation_toast.dart';
import 'package:Kelivo/shared/widgets/plain_text_input.dart';

void main() {
  testWidgets(
    'creation inputs, overlays and feedback inherit the selected font and fallbacks',
    (tester) async {
      const font = 'Custom application font';
      const fallback = ['CJK fallback'];
      void check(TextStyle? style) {
        expect(style?.fontFamily, font);
        expect(style?.fontFamilyFallback, fallback);
      }

      late BuildContext anchor;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: font, fontFamilyFallback: fallback),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                anchor = context;
                return const PlainTextInput(placeholder: 'Search');
              },
            ),
          ),
        ),
      );
      final input = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      check(tester.widget<EditableText>(find.byType(EditableText)).style);
      check(input.placeholderStyle);
      TextStyle? rendered(String label) => tester
          .widget<RichText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText && widget.text.toPlainText() == label,
            ),
          )
          .text
          .style;
      showCreationMenu(
        anchor,
        globalPosition: const Offset(50, 50),
        items: [DesktopContextMenuItem(label: 'Menu choice', onTap: () {})],
      );
      await tester.pumpAndSettle();
      check(rendered('Menu choice'));
      Navigator.of(anchor).pop();
      await tester.pumpAndSettle();
      showCreationPicker<void>(
        anchor,
        desktop: false,
        title: 'Sheet title',
        builder: (_) => const Text('Picker item'),
      );
      await tester.pumpAndSettle();
      check(rendered('Sheet title'));
      check(rendered('Picker item'));
      Navigator.of(anchor).pop();
      await tester.pumpAndSettle();
      showCreationToast(anchor, message: 'Added reference');
      await tester.pump();
      check(rendered('Added reference'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
