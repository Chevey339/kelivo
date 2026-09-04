import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/chat/widgets/unified_diff_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  test('classifies unified diff lines', () {
    expect(classifyUnifiedDiffLine('+added'), UnifiedDiffLineKind.add);
    expect(classifyUnifiedDiffLine('-removed'), UnifiedDiffLineKind.remove);
    expect(
      classifyUnifiedDiffLine('@@ -1,2 +3,4 @@'),
      UnifiedDiffLineKind.hunk,
    );
    expect(
      classifyUnifiedDiffLine('--- a/file'),
      UnifiedDiffLineKind.fileHeader,
    );
    expect(
      classifyUnifiedDiffLine('+++ b/file'),
      UnifiedDiffLineKind.fileHeader,
    );
    expect(classifyUnifiedDiffLine(' context'), UnifiedDiffLineKind.context);
  });

  testWidgets('tints add / remove / hunk lines', (tester) async {
    const diff = '''
--- a/a.txt
+++ b/a.txt
@@ -1,2 +1,2 @@
 keep
-old
+new
''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UnifiedDiffView(diff: diff)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(UnifiedDiffView.viewKey), findsOneWidget);
    expect(find.textContaining('+new'), findsOneWidget);
    expect(find.textContaining('-old'), findsOneWidget);
    expect(find.textContaining('@@'), findsOneWidget);

    Color? colorOf(String text) {
      final selectable = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains(text) ?? false),
        ),
      );
      return selectable.style?.color;
    }

    final add = colorOf('+new')!;
    final remove = colorOf('-old')!;
    final hunk = colorOf('@@')!;
    expect(add.g, greaterThan(add.r));
    expect(remove.r, greaterThan(remove.g));
    expect(hunk.a, lessThan(add.a + 0.01));
  });

  testWidgets('virtualizes diffs over 500 lines', (tester) async {
    final buffer = StringBuffer();
    for (var i = 0; i < 520; i++) {
      buffer.writeln('+line $i');
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: UnifiedDiffView(diff: buffer.toString()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ListView), findsWidgets);
    expect(find.textContaining('+line 0'), findsOneWidget);
    expect(find.textContaining('+line 519'), findsNothing);
  });

  testWidgets('optional header shows file and counts', (tester) async {
    const diff = '''
--- a/a.txt
+++ b/a.txt
@@ -1,2 +1,2 @@
 keep
-old
+new
''';
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UnifiedDiffView(
              diff: diff,
              showHeader: true,
              fileName: 'a.txt',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(UnifiedDiffView.headerKey), findsOneWidget);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
  });
}
