import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('evicted native paragraphs are released after replacement layout', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText(
      'a' * 10000,
      const CodeLineOptions(plainText: true),
    );
    late CodeIndicatorValueNotifier indicator;
    late StateSetter update;
    var fontSize = 16.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CodeEditor(
                controller: controller,
                readOnly: true,
                wordWrap: true,
                style: CodeEditorStyle(fontSize: fontSize),
                indicatorBuilder: (context, editing, chunks, notifier) {
                  indicator = notifier;
                  return const SizedBox(width: 0);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    // Inspect the engine resource itself; counting cache entries would not
    // detect resources left waiting for a later GC weak-handle sweep.
    ui.Paragraph current() =>
        (indicator.value!.paragraphs.first.paragraph as dynamic).paragraph
            as ui.Paragraph;
    final original = current();
    expect(original.debugDisposed, isFalse);
    controller.editDocument(
      TextEditingValue(
        text: 'a' * 9999,
        selection: const TextSelection.collapsed(offset: 0),
      ),
      replacedRange: const TextRange(start: 0, end: 1),
    );
    expect(
      original.debugDisposed,
      isFalse,
      reason:
          'The currently installed layout must remain usable until replacement',
    );
    await tester.pump();
    expect(original.debugDisposed, isTrue);
    final edited = current();
    expect(edited.debugDisposed, isFalse);
    update(() => fontSize = 18);
    expect(edited.debugDisposed, isFalse);
    await tester.pump();
    expect(edited.debugDisposed, isTrue);
    final resized = current();
    expect(resized.debugDisposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(resized.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
