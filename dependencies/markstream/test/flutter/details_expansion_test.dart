import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host;

Finder foldToggle(int index) => find.descendant(
  of: find.byType(MarkstreamDetailsBlock).at(index),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.expanded != null,
  ),
);

Finder foldBody(int index) => find.descendant(
  of: find.byType(MarkstreamDetailsBlock).at(index),
  matching: find.byKey(const ValueKey('markstream-details-body')),
);

void main() {
  testWidgets('details expansion survives append, finish and remount', (
    tester,
  ) async {
    final store = DetailsExpansionState();
    const prefix = '<details>\n<summary>Summary</summary>\n\n';
    Widget view(String body, {bool streaming = true}) => host(
      MarkstreamView(
        source: '$prefix$body',
        streaming: streaming,
        detailsExpansionState: store,
        detailsStateKey: 'message/text-0',
      ),
    );

    await tester.pumpWidget(view('Secret body'));
    expect(foldBody(0), findsNothing);
    await tester.tap(foldToggle(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(view('Secret body appended'));
    expect(foldBody(0), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      view('Secret body appended offscreen\n\n</details>', streaming: false),
    );
    await tester.pumpAndSettle();
    expect(foldBody(0), findsOneWidget);

    // Replacing even the newly observed suffix invalidates the old choice.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      view('Secret body appended changed\n\n</details>', streaming: false),
    );
    await tester.pumpAndSettle();
    expect(foldBody(0), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final html in [false, true]) {
    testWidgets(
      'identical ${html ? 'HTML' : 'Markdown'} details stay separate',
      (tester) async {
        final store = DetailsExpansionState();
        const fold = '<details><summary>Same summary</summary>Body</details>';
        final source = html ? '<div>$fold$fold</div>' : '$fold\n\n$fold';
        Widget view({Object identity = 'message/text-1'}) => host(
          MarkstreamView(
            source: source,
            detailsExpansionState: store,
            detailsStateKey: identity,
          ),
        );
        await tester.pumpWidget(view());
        expect(find.byType(MarkstreamDetailsBlock), findsNWidgets(2));
        await tester.tap(foldToggle(0));
        await tester.pumpAndSettle();
        expect(foldBody(0), findsOneWidget);
        expect(foldBody(1), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(view());
        await tester.pumpAndSettle();
        expect(foldBody(0), findsOneWidget);
        expect(foldBody(1), findsNothing);

        await tester.pumpWidget(view(identity: 'message/text-2'));
        await tester.pumpAndSettle();
        expect(foldBody(0), findsNothing);
        expect(foldBody(1), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('manual collapse of open details survives remount', (
    tester,
  ) async {
    final store = DetailsExpansionState();
    Widget view() => host(
      MarkstreamView(
        source: '<details open><summary>Open summary</summary>Body</details>',
        detailsExpansionState: store,
        detailsStateKey: 'message/open-details',
      ),
    );
    await tester.pumpWidget(view());
    expect(foldBody(0), findsOneWidget);
    await tester.tap(foldToggle(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(foldBody(0), findsNothing);
  });

  test(
    'details memory is bounded and validates the complete observed source',
    () {
      final store = DetailsExpansionState(capacity: 2);
      store.remember('document', 0, '<details>first body', true);
      store.remember('document', 100, '<details>second body', false);
      expect(store.read('document', 0, '<details>first body appended'), isTrue);
      store.remember('other', 0, '<details>third body', true);
      expect(store.read('document', 100, '<details>second body'), isNull);
      expect(store.read('document', 0, '<details>first body replaced'), isNull);
      expect(store.read('other', 1, '<details>third body'), isNull);
      expect(store.read('other', 0, '<details>'), isNull);
    },
  );
}
