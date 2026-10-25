import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/context_compression_task.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_widgets.dart';
import 'package:Kelivo/features/chat/widgets/context_compression_status.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  final op = ContextOperation(
    id: 'summary',
    kind: ContextOperationKind.compress,
    anchorGroupId: 'a',
    appliedAfterGroupId: 'b',
    sourceGroups: const ['u', 'a'],
    dependencies: const [],
    createdAt: DateTime(2026),
    summary: 'Actual request summary',
    originalSummary: 'Actual request summary',
    keepUserMessages: 6,
  );
  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  testWidgets(
    'marker and close have independent actions with accessible labels',
    (tester) async {
      var opens = 0;
      var undos = 0;
      await tester.pumpWidget(
        app(
          ContextOperationDivider(
            operation: op,
            onOpen: () => opens++,
            onUndo: () => undos++,
          ),
        ),
      );
      await tester.tap(find.text('Context compressed'));
      await tester.pump();
      expect(opens, 1);
      expect(undos, 0);
      await tester.tap(find.byKey(const ValueKey('undo-context-summary')));
      await tester.pump();
      expect(undos, 1);
      expect(opens, 1);
      expect(find.byTooltip('Undo this context operation'), findsOneWidget);
      await tester.pumpWidget(
        app(
          ContextOperationDivider(
            operation: op.copyWith(revoked: true),
            onOpen: () {},
            onUndo: () => undos++,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('undo-context-summary')), findsNothing);
    },
  );

  testWidgets(
    'editing is explicit, cancel discards draft and whitespace cannot be saved',
    (tester) async {
      final saves = <String>[];
      await tester.pumpWidget(
        app(
          ContextOperationContent(
            operation: op,
            onClose: () {},
            onSave: (value) async {
              saves.add(value);
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'unsaved');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(saves, isEmpty);
      expect(find.text('Actual request summary'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saves, isEmpty);
      await tester.enterText(find.byType(TextField), 'edited decision');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saves, ['edited decision']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 440), const Size(1000, 720)]) {
    testWidgets('details and task controls fit $size with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.4),
            ),
            child: ContextOperationContent(
              operation: op,
              onClose: () {},
              onSave: (_) async => true,
              onUndo: () async => true,
              budget: (usedTokens: 3200, contextWindow: 4000),
              undoBudget: (usedTokens: 18000, contextWindow: 4000),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final task = ContextCompressionTask(
        id: 'job',
        conversationId: 'chat',
        options: const CompressContextOptions(
          mode: CompressContextLimitMode.unlimited,
        ),
        phase: CompressionPhase.failed,
      )..error = 'context_changed';
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: ContextCompressionStatus(
              task: task,
              onCancel: () {},
              onRetry: () {},
              onReview: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('Retry compression'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
