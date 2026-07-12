import 'package:Kelivo/features/chat/widgets/bounded_large_text_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(String text) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: BoundedLargeTextView(text, style: const TextStyle(fontSize: 12)),
      ),
    ),
  );

  testWidgets('small tool result remains a simple selectable paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(harness('small result'));

    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bounded-large-text-toggle')),
      findsNothing,
    );
  });

  testWidgets('D5 tool result is collapsed then virtualized in chunks', (
    tester,
  ) async {
    final text = List<String>.generate(
      10000,
      (index) => 'result-$index',
    ).join('\n');
    await tester.pumpWidget(harness(text));

    expect(find.textContaining('result-0'), findsOneWidget);
    expect(find.textContaining('result-9999'), findsNothing);
    expect(
      find.byKey(const ValueKey('bounded-large-text-preview')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('bounded-large-text-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('bounded-large-text-toggle')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('virtualized-large-text-list')),
      findsOneWidget,
    );
    expect(find.byType(Text), findsWidgets);
    expect(find.textContaining('result-9999'), findsNothing);
  });
}
