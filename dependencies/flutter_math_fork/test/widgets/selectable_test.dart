// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The following tests are transformed from flutter/test/widgets/selectable_text_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/src/render/layout/line_editable.dart';
import 'package:flutter_math_fork/src/widgets/selectable.dart';
import 'package:flutter_math_fork/src/widgets/selection/handle_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';

Widget overlay({required Widget child}) => MaterialApp(
      home: Center(
        child: Material(
          child: child,
        ),
      ),
    );

Future<void> skipPastScrollingAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  // Returns the first RenderEditable.
  RenderEditableLine findRenderEditableLine(WidgetTester tester) {
    final root = tester.renderObject(find.byType(InternalSelectableMath));
    expect(root, isNotNull);

    RenderEditableLine? renderEditable;
    void recursiveFinder(RenderObject child) {
      if (child is RenderEditableLine) {
        renderEditable = child;
        return;
      }
      child.visitChildren(recursiveFinder);
    }

    root.visitChildren(recursiveFinder);
    expect(renderEditable, isNotNull);
    return renderEditable!;
  }

  Offset textOffsetToCaretPosition(WidgetTester tester, int index) {
    final renderLine = findRenderEditableLine(tester);
    final endpoints = renderLine.getEndpointForCaretIndex(index);
    return endpoints + const Offset(0.0, -2.0);
  }

  setUpAll(loadKaTeXFonts);

  group('SelectableMath test', () {
    testWidgets('Cursor blinks when showCursor is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        overlay(
          child: SelectableMath.tex(
            'some text',
            showCursor: true,
          ),
        ),
      );
      await tester.tap(find.byType(SelectableMath));
      await tester.idle();

      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));

      // Check that the cursor visibility toggles after each blink interval.
      final initialShowCursor = selectableMath.cursorCurrentlyVisible;
      await tester.pump(selectableMath.cursorBlinkInterval);
      expect(selectableMath.cursorCurrentlyVisible, equals(!initialShowCursor));
      await tester.pump(selectableMath.cursorBlinkInterval);
      expect(selectableMath.cursorCurrentlyVisible, equals(initialShowCursor));
      await tester.pump(selectableMath.cursorBlinkInterval ~/ 10);
      expect(selectableMath.cursorCurrentlyVisible, equals(initialShowCursor));
      await tester.pump(selectableMath.cursorBlinkInterval);
      expect(selectableMath.cursorCurrentlyVisible, equals(!initialShowCursor));
      await tester.pump(selectableMath.cursorBlinkInterval);
      expect(selectableMath.cursorCurrentlyVisible, equals(initialShowCursor));
    });

    testWidgets('selectable math basic', (WidgetTester tester) async {
      await tester.pumpWidget(
        overlay(
          child: SelectableMath.tex('selectable'),
        ),
      );
      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      // selectable text cannot open keyboard.
      // TODO
      // await tester.showKeyboard(find.byType(InternalSelectableMath));
      // expect(tester.testTextInput.hasAnyClients, false);
      // await skipPastScrollingAnimation(tester);

      // expect(selectableMath.controller.selection.isCollapsed, true);

      await tester.tap(find.byType(SelectableMath));
      await tester.pump();

      // Collapse selection should not paint.
      expect(selectableMath.selectionOverlay!.handlesAreVisible, isFalse);
      // Long press on the 't' character of text 'selectable' to show context
      // menu.
      const dIndex = 5;
      final dPos = textOffsetToCaretPosition(tester, dIndex);
      await tester.longPressAt(dPos);
      await tester.pump();

      // Context menu should not have paste and cut.
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsNothing);
      expect(find.text('Cut'), findsNothing);
    });

    testWidgets('Can drag handles to change selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex(
                'abc def ghi',
                dragStartBehavior: DragStartBehavior.down,
              ),
            ),
          ),
        ),
      );
      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      final controller = selectableMath.controller;

      // Long press the 'e' to select 'def'.
      final ePos = textOffsetToCaretPosition(tester, 5);
      var gesture = await tester.startGesture(ePos, pointer: 7);
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(
          milliseconds: 200)); // skip past the frame where the opacity is zero

      final selection = controller.selection;
      expect(selection.baseOffset, 5);
      expect(selection.extentOffset, 6);

      final renderEditable = findRenderEditableLine(tester);
      final endpoints = [
        renderEditable.getEndpointForCaretIndex(5),
        renderEditable.getEndpointForCaretIndex(6)
      ];
      expect(endpoints.length, 2);

      // Drag the right handle 2 letters to the right.
      // We use a small offset because the endpoint is on the very corner
      // of the handle.
      var handlePos = endpoints[1] + const Offset(1.0, 1.0);
      var newHandlePos = textOffsetToCaretPosition(tester, 9);
      gesture = await tester.startGesture(handlePos, pointer: 7);
      await tester.pump();
      await gesture.moveTo(newHandlePos);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 9);

      // Drag the left handle 2 letters to the left.
      handlePos = endpoints[0] + const Offset(-1.0, 1.0);
      newHandlePos = textOffsetToCaretPosition(tester, 0);
      gesture = await tester.startGesture(handlePos, pointer: 7);
      await tester.pump();
      await gesture.moveTo(newHandlePos);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 9);
    });

    // testWidgets('Can use selection toolbar', (WidgetTester tester) async {
    //   const testValue = 'abcdefghi';
    //   await tester.pumpWidget(
    //     MaterialApp(
    //       home: Material(
    //         child: Center(
    //           child: SelectableMath.tex(
    //             testValue,
    //           ),
    //         ),
    //       ),
    //     ),
    //   );
    //   final selectableMath = tester.state<InternalSelectableMathState>(
    //       find.byType(InternalSelectableMath));
    //   final controller = selectableMath.controller;

    //   // Tap the selection handle to bring up the "paste / select all" menu.
    //   await tester
    //       .tapAt(textOffsetToCaretPosition(tester, testValue.indexOf('e')));
    //   await tester.pump();
    //   await tester.pump(const Duration(
    //       milliseconds: 200)); // skip past the frame where the opacity is zero
    //   final renderLine = findRenderEditableLine(tester);
    //   final endpoint =
    //       renderLine.getEndpointForCaretIndex(controller.selection.start);
    //   // Tapping on the part of the handle's GestureDetector where it overlaps
    //   // with the text itself does not show the menu, so add a small vertical
    //   // offset to tap below the text.
    //   await tester.tapAt(endpoint + const Offset(1.0, 13.0));
    //   await tester.pump();
    //   await tester.pump(const Duration(
    //       milliseconds: 200)); // skip past the frame where the opacity is zero

    //   // Select all should select all the text.
    //   await tester.tap(find.text('Select all'));
    //   await tester.pump();
    //   expect(controller.selection.baseOffset, 0);
    //   expect(controller.selection.extentOffset, testValue.length);

    //   // Copy should reset the selection.
    //   await tester.tap(find.text('Copy'));
    //   await skipPastScrollingAnimation(tester);
    //   expect(controller.selection.isCollapsed, true);
    // });

    testWidgets('Selectable text drops selection when losing focus',
        (WidgetTester tester) async {
      final Key key1 = UniqueKey();
      final Key key2 = UniqueKey();

      await tester.pumpWidget(
        overlay(
          child: Column(
            children: <Widget>[
              SelectableMath.tex(
                'text 1',
                key: key1,
              ),
              SelectableMath.tex(
                'text 2',
                key: key2,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(key1));
      await tester.pump();
      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath).first);
      final controller = selectableMath.controller;
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 3);
      await tester.pump();
      expect(controller.selection, isNot(equals(TextRange.empty)));

      await tester.tap(find.byKey(key2));
      await tester.pump();
      expect(controller.selection, equals(TextRange.empty));
    });

    testWidgets('selection handles are rendered and not faded away',
        (WidgetTester tester) async {
      const testText = r'abcdef\frac{abc}{def}\sqrt[abc]{def}';
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex(testText),
            ),
          ),
        ),
      );

      final state = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));

      // await tester.tapAt(const Offset(20, 10));
      state.selectWordAt(
          offset: const Offset(20, 10), cause: SelectionChangedCause.longPress);
      await tester.pumpAndSettle();

      final transitions = find
          .descendant(
            of: find.byWidgetPredicate(
                (Widget w) => w.runtimeType == MathSelectionHandleOverlay),
            matching: find.byType(FadeTransition),
          )
          .evaluate()
          .map((Element e) => e.widget)
          .cast<FadeTransition>()
          .toList();
      expect(transitions.length, 2);
      final left = transitions[0];
      final right = transitions[1];

      expect(left.opacity.value, equals(1.0));
      expect(right.opacity.value, equals(1.0));
    });

    testWidgets('selection handles are rendered and not faded away',
        (WidgetTester tester) async {
      const testText = r'abcdef\frac{abc}{def}\sqrt[abc]{def}';
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex(testText),
            ),
          ),
        ),
      );

      final state = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));

      // await tester.tapAt(const Offset(20, 10));
      state.selectWordAt(
          offset: const Offset(20, 10), cause: SelectionChangedCause.longPress);
      await tester.pumpAndSettle();

      final transitions = find
          .descendant(
            of: find.byWidgetPredicate(
                (Widget w) => w.runtimeType == MathSelectionHandleOverlay),
            matching: find.byType(FadeTransition),
          )
          .evaluate()
          .map((Element e) => e.widget)
          .cast<FadeTransition>()
          .toList();
      expect(transitions.length, 2);
      final left = transitions[0];
      final right = transitions[1];

      expect(left.opacity.value, equals(1.0));
      expect(right.opacity.value, equals(1.0));
    },
        variant: const TargetPlatformVariant(
            <TargetPlatform>{TargetPlatform.iOS, TargetPlatform.macOS}));

    testWidgets('Long press shows handles and toolbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex('abc def ghi'),
            ),
          ),
        ),
      );

      // Long press at 'e' in 'def'.
      final ePos = textOffsetToCaretPosition(tester, 5);
      await tester.longPressAt(ePos);
      await tester.pumpAndSettle();

      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      expect(selectableMath.selectionOverlay!.handlesAreVisible, isTrue);
      expect(selectableMath.selectionOverlay!.toolbarIsVisible, isTrue);
    });

    testWidgets('Double tap shows handles and toolbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex('abc def ghi'),
            ),
          ),
        ),
      );

      // Double tap at 'e' in 'def'.
      final ePos = textOffsetToCaretPosition(tester, 5);
      await tester.tapAt(ePos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(ePos);
      await tester.pump();

      final selectableMath = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      expect(selectableMath.selectionOverlay!.handlesAreVisible, isTrue);
      expect(selectableMath.selectionOverlay!.toolbarIsVisible, isTrue);
    });

    testWidgets(
      'Mouse tap does not show handles nor toolbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: SelectableMath.tex('abc def ghi'),
              ),
            ),
          ),
        );

        // Long press to trigger the selectable text.
        final ePos = textOffsetToCaretPosition(tester, 5);
        final gesture = await tester.startGesture(
          ePos,
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.up();
        await tester.pump();

        final selectableMath = tester.state<InternalSelectableMathState>(
            find.byType(InternalSelectableMath));
        expect(selectableMath.selectionOverlay!.toolbarIsVisible, isFalse);
        expect(selectableMath.selectionOverlay!.handlesAreVisible, isFalse);
      },
    );

    testWidgets(
      'Mouse long press does not show handles nor toolbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: SelectableMath.tex('abc def ghi'),
              ),
            ),
          ),
        );

        // Long press to trigger the selectable text.
        final ePos = textOffsetToCaretPosition(tester, 5);
        final gesture = await tester.startGesture(
          ePos,
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await tester.pump(const Duration(seconds: 2));
        await gesture.up();
        await tester.pump();

        final selectableMath = tester.state<InternalSelectableMathState>(
            find.byType(InternalSelectableMath));
        expect(selectableMath.selectionOverlay!.toolbarIsVisible, isFalse);
        expect(selectableMath.selectionOverlay!.handlesAreVisible, isFalse);
      },
    );

    testWidgets(
      'Mouse double tap does not show handles nor toolbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: SelectableMath.tex('abc def ghi'),
              ),
            ),
          ),
        );

        // Double tap to trigger the selectable text.
        final selectableTextPos = tester.getCenter(find.byType(SelectableMath));
        final gesture = await tester.startGesture(
          selectableTextPos,
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
        await gesture.down(selectableTextPos);
        await tester.pump();
        await gesture.up();
        await tester.pump();

        final selectableMath = tester.state<InternalSelectableMathState>(
            find.byType(InternalSelectableMath));
        expect(selectableMath.selectionOverlay!.toolbarIsVisible, isFalse);
        expect(selectableMath.selectionOverlay!.handlesAreVisible, isFalse);
      },
    );

    testWidgets('changes mouse cursor when hovered',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex('test'),
            ),
          ),
        ),
      );

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 1);
      await gesture.addPointer(
          location: tester.getCenter(find.byType(SelectableMath)));
      addTearDown(gesture.removePointer);

      await tester.pump();

      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.text);
    });

    testWidgets(
      'The handles show after pressing Select All',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: SelectableMath.tex('abc def ghi'),
              ),
            ),
          ),
        );

        // Long press at 'e' in 'def'.
        final ePos = textOffsetToCaretPosition(tester, 5);
        await tester.longPressAt(ePos);
        await tester.pumpAndSettle();

        expect(find.text('Select all'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Paste'), findsNothing);
        expect(find.text('Cut'), findsNothing);
        var selectableMath = tester.state<InternalSelectableMathState>(
            find.byType(InternalSelectableMath));
        expect(selectableMath.selectionOverlay!.handlesAreVisible, isTrue);
        expect(selectableMath.selectionOverlay!.toolbarIsVisible, isTrue);

        await tester.tap(find.text('Select all'));
        await tester.pump();
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Select all'), findsNothing);
        expect(find.text('Paste'), findsNothing);
        expect(find.text('Cut'), findsNothing);
        selectableMath = tester.state<InternalSelectableMathState>(
            find.byType(InternalSelectableMath));
        expect(selectableMath.selectionOverlay!.handlesAreVisible, isTrue);
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      }),
    );

    testWidgets('Does not show handles when updated from the web engine',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SelectableMath.tex('abc def ghi'),
            ),
          ),
        ),
      );

      // Interact with the selectable text to establish the input connection.
      final topLeft = tester.getTopLeft(find.byType(SelectableMath));
      final gesture = await tester.startGesture(
        topLeft + const Offset(0.0, 5.0),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      final state = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      expect(state.selectionOverlay!.handlesAreVisible, isFalse);
      expect(
        state.currentTextEditingValue.selection,
        const TextSelection.collapsed(offset: 0),
      );

      if (kIsWeb) {
        tester.testTextInput.updateEditingValue(const TextEditingValue(
          selection: TextSelection(baseOffset: 2, extentOffset: 7),
        ));
        // Wait for all the `setState` calls to be flushed.
        await tester.pumpAndSettle();
        expect(
          state.currentTextEditingValue.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7),
        );
        expect(state.selectionOverlay!.handlesAreVisible, isFalse);
      }
    });

    // testWidgets('onSelectionChanged is called when selection changes',
    //     (WidgetTester tester) async {
    //   int onSelectionChangedCallCount = 0;

    //   await tester.pumpWidget(
    //     MaterialApp(
    //       home: Material(
    //         child: SelectableText(
    //           'abc def ghi',
    //           onSelectionChanged:
    //               (TextSelection selection, SelectionChangedCause cause) {
    //             onSelectionChangedCallCount += 1;
    //           },
    //         ),
    //       ),
    //     ),
    //   );

    //   // Long press to select 'abc'.
    //   final Offset aLocation = textOffsetToPosition(tester, 1);
    //   await tester.longPressAt(aLocation);
    //   await tester.pump();
    //   expect(onSelectionChangedCallCount, equals(1));

    //   // Tap on 'Select all' option to select the whole text.
    //   await tester.longPressAt(textOffsetToPosition(tester, 5));
    //   await tester.pump();
    //   await tester.tap(find.text('Select all'));
    //   expect(onSelectionChangedCallCount, equals(2));
    // });
  });
}
