import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';
import 'package:Kelivo/shared/widgets/throttled_progress_label.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void _expectNoMaterialChrome() {
  expect(find.byType(LinearProgressIndicator), findsNothing);
  expect(find.byType(InkWell), findsNothing);
  expect(find.byType(TextButton), findsNothing);
  expect(find.byType(FilledButton), findsNothing);
}

void main() {
  testWidgets('determinate bar width follows fraction', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 200,
          child: AnimatedProgressBar(fraction: 0.5, height: 6),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(AnimatedProgressBar.fillKey)).width, 100);
    _expectNoMaterialChrome();
  });

  testWidgets('throttled percent text changes at most once per 1200ms', (
    tester,
  ) async {
    var text = '0%';
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                ThrottledProgressLabel(
                  text: text,
                  builder: (context, displayText) => Text(displayText),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    text = '${int.parse(text.replaceAll('%', '')) + 1}%';
                  }),
                  child: const Text('tick'),
                ),
              ],
            );
          },
        ),
      ),
    );
    expect(find.text('0%'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('tick'));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('0%'), findsOneWidget);
    await tester.pump(ThrottledProgressLabel.displayInterval);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('cancel button is absent when not cancellable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TaskProgressDialogCard(
          title: 'Export',
          phaseLabel: 'Packing',
          fraction: 0.4,
          cancellable: false,
          cancelLabel: 'Cancel',
          onCancel: () {},
        ),
      ),
    );
    expect(find.byType(IosTileButton), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    _expectNoMaterialChrome();
  });

  testWidgets('PopScope cancels when cancellable and ignores when not', (
    tester,
  ) async {
    var cancelled = 0;
    await tester.pumpWidget(
      _wrap(
        TaskProgressDialogCard(
          title: 'Export',
          phaseLabel: 'Packing',
          fraction: 0.4,
          cancellable: true,
          cancelLabel: 'Cancel',
          onCancel: () => cancelled++,
        ),
      ),
    );
    final cancellableScope = tester.widget<PopScope<Object?>>(
      find.byKey(const Key('task_progress_pop_scope')),
    );
    expect(cancellableScope.canPop, isFalse);
    cancellableScope.onPopInvokedWithResult?.call(false, null);
    expect(cancelled, 1);

    await tester.pumpWidget(
      _wrap(
        TaskProgressDialogCard(
          title: 'Export',
          phaseLabel: 'Committing',
          fraction: 0.9,
          cancellable: false,
          cancelLabel: 'Cancel',
          onCancel: () => cancelled++,
        ),
      ),
    );
    final lockedScope = tester.widget<PopScope<Object?>>(
      find.byKey(const Key('task_progress_pop_scope')),
    );
    lockedScope.onPopInvokedWithResult?.call(false, null);
    expect(cancelled, 1);
    expect(find.byType(IosTileButton), findsNothing);
  });

  testWidgets('indeterminate state shows a spinner and no percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TaskProgressDialogCard(
          title: 'Export',
          phaseLabel: 'Preparing',
          fraction: null,
          phaseIcon: Lucide.Loader,
        ),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(ReelText), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byKey(AnimatedProgressBar.indeterminateKey), findsOneWidget);
    _expectNoMaterialChrome();
  });
}
