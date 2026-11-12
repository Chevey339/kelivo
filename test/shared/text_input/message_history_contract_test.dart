import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'document history matches Flutter coalescing, composing and redo while typing',
    (tester) async {
      final document = MessageEditingController(nativeInputEnabled: true);
      final reference = TextEditingController();
      final focus = FocusNode();
      final key = GlobalKey<UndoHistoryState<TextEditingValue>>();
      const initial = TextEditingValue(
        text: 'A',
        selection: TextSelection.collapsed(offset: 1),
      );
      document.value = reference.value = initial;
      await tester.pumpWidget(
        MaterialApp(
          home: UndoHistory<TextEditingValue>(
            key: key,
            value: reference,
            focusNode: focus,
            shouldChangeUndoStack: (previous, next) =>
                next.selection.isValid &&
                (previous == null ||
                    previous.text != next.text ||
                    previous.composing != next.composing),
            undoStackModifier: (value) =>
                value.copyWith(composing: TextRange.empty),
            onTriggered: (value) => reference.value = value,
            child: const SizedBox(),
          ),
        ),
      );
      void compare() {
        expect(document.value, reference.value);
        expect(document.history!.canUndo, key.currentState!.canUndo);
        expect(document.history!.canRedo, key.currentState!.canRedo);
      }

      void insert(String text, {bool composing = false}) {
        final next = reference.value.replaced(reference.selection, text);
        reference.value = document.value = composing
            ? next.copyWith(
                composing: TextRange(
                  start: next.selection.start - text.length,
                  end: next.selection.end,
                ),
              )
            : next;
        compare();
      }

      void undo() {
        key.currentState!.undo();
        document.history!.undo();
        compare();
      }

      void redo() {
        key.currentState!.redo();
        document.history!.redo();
        compare();
      }

      await tester.pump(const Duration(milliseconds: 600));
      insert('B');
      await tester.pump(const Duration(milliseconds: 600));
      insert('C');
      undo();
      redo();
      undo();
      insert('X');
      redo();
      await tester.pump(const Duration(milliseconds: 600));
      compare();
      undo();
      insert('ni', composing: true);
      await tester.pump(const Duration(milliseconds: 600));
      compare();
      undo();
      redo();
      await tester.pumpWidget(const SizedBox());
      document.dispose();
      reference.dispose();
      focus.dispose();
    },
  );
}
