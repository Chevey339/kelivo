import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

const _style = TextStyle(
  fontSize: 15.5 * .86,
  height: 1,
  leadingDistribution: TextLeadingDistribution.even,
  fontFamily: 'monospace',
);
Widget capsule(String text) => OpticalBaseline(
  center: 15.5 * .35,
  child: InlineCodeCapsule(
    key: const ValueKey('code'),
    text: text,
    style: _style,
    backgroundColor: const Color(0x66F1F3F5),
    borderColor: Colors.transparent,
  ),
);

Widget harness({
  required String code,
  required SelectionListenerNotifier listener,
  required ValueChanged<SelectedContent?> onSelection,
  TargetPlatform platform = TargetPlatform.macOS,
  double width = 390,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SelectionArea(
        onSelectionChanged: onSelection,
        child: StableSelectionContainer(
          child: SelectionListener(
            selectionNotifier: listener,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: buildSelectableText(
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Before '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: capsule(code),
                        ),
                        const TextSpan(text: ' middle '),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: SelectableSpanAdapter(
                            selectedText: r'$x+y$',
                            child: Text('x+y'),
                          ),
                        ),
                        const TextSpan(text: ' After'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15.5, height: 1.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

RenderParagraph paragraph() => find
    .byType(RichText)
    .evaluate()
    .map((e) => e.renderObject)
    .whereType<RenderParagraph>()
    .firstWhere((p) => p.text.toPlainText().contains('\uFFFC'));

TextBox box(RenderParagraph p, int offset) => p
    .getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    )
    .single;
Offset point(RenderParagraph p, int offset, {bool end = false}) {
  final b = box(p, offset);
  return p.localToGlobal(
    Offset(end ? b.right - 1 : b.left + 1, (b.top + b.bottom) / 2),
  );
}

void main() {
  testWidgets(
    'desktop drag crosses code and math atoms in both directions',
    (tester) async {
      final listener = SelectionListenerNotifier();
      addTearDown(listener.dispose);
      String? selected;
      await tester.pumpWidget(
        harness(
          code: 'run(中😀)',
          platform: defaultTargetPlatform,
          listener: listener,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph();
      for (final reverse in [false, true]) {
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .clearSelection();
        await tester.pump(const Duration(milliseconds: 600));
        final a = point(p, 0), b = point(p, 22, end: true);
        final gesture = await tester.startGesture(
          reverse ? b : a,
          kind: ui.PointerDeviceKind.mouse,
        );
        await gesture.moveTo(reverse ? a : b);
        await tester.pump();
        await gesture.up();
        await gesture.removePointer();
        await tester.pumpAndSettle();
        expect(selected, r'Before run(中😀) middle $x+y$ After');
        final range = listener.selection.range!;
        expect((
          range.startOffset,
          range.endOffset,
        ), reverse ? (34, 0) : (0, 34));
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'mobile long press and end handle extend across an inline capsule',
    (tester) async {
      final listener = SelectionListenerNotifier();
      addTearDown(listener.dispose);
      String? selected;
      await tester.pumpWidget(
        harness(
          code: 'code',
          listener: listener,
          platform: TargetPlatform.android,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph();
      await tester.longPressAt(point(p, 2));
      await tester.pumpAndSettle();
      expect(selected, 'Before');
      final overlay = tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectionOverlay;
      final controls = overlay!.selectionControls!;
      final size = controls.getHandleSize(overlay.lineHeightAtEnd);
      final center =
          Offset(size.width / 2, size.height / 2) -
          controls.getHandleAnchor(
            overlay.endHandleType,
            overlay.lineHeightAtEnd,
          );
      final handle = overlay.endHandleLayerLink.leader!.offset;
      final gesture = await tester.startGesture(handle + center);
      final target = box(p, 22);
      final leading =
          (overlay.lineHeightAtEnd - (target.bottom - target.top)) / 2;
      await gesture.moveTo(
        p.localToGlobal(Offset(target.right, target.bottom + leading)) + center,
      );
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(selected, r'Before code middle $x+y$ After');
      expect(listener.selection.range!.endOffset, 30);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('long code wraps within narrow constraints at both font scales', (
    tester,
  ) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    String? selected;
    final code = List.filled(12, 'longCode()').join(' ');
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        harness(
          code: code,
          listener: listener,
          width: 180,
          scale: scale,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(InlineCodeCapsule)).width,
        lessThanOrEqualTo(180),
      );
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, 'Before $code middle \$x+y\$ After');
      expect(listener.selection.range!.endOffset, selected!.length);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'platform copy shortcut includes both inline atoms',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings')
            return {'value': clipboard != null};
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final listener = SelectionListenerNotifier();
      addTearDown(listener.dispose);
      await tester.pumpWidget(
        harness(
          code: 'code',
          listener: listener,
          platform: defaultTargetPlatform,
          onSelection: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        point(paragraph(), 0),
        kind: ui.PointerDeviceKind.mouse,
      );
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
      expect(clipboard, r'Before code middle $x+y$ After');
    },
    variant: TargetPlatformVariant.desktop(),
  );
}
