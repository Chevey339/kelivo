import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/context_impact_dialog.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_actions.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';

class _Chat extends ChatService {
  int previewReads = 0;
  String? requestedRevision;
  final preview =
      Completer<
        ({List<ChatMessage> messages, List<ContextOperation> operations})
      >();
  @override
  Future<ContextMutationState> loadContextMutationState(String id) async => (
    revision: 'approved-revision',
    operations: [
      ContextOperationMetadata(
        id: 'summary',
        kind: ContextOperationKind.compress,
        anchorGroupId: 'u',
        appliedAfterGroupId: 'a',
        sourceGroups: ['u'],
        dependencies: [],
        createdAt: DateTime(2026),
      ),
    ],
  );
  @override
  Future<({List<ChatMessage> messages, List<ContextOperation> operations})>
  loadContextMutationPreview(String id, {required String expectedState}) {
    requestedRevision = expectedState;
    previewReads++;
    return preview.future;
  }
}

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
      'source confirmation is interactive before budget loads: confirm=$confirm',
      (tester) async {
        final chat = _Chat();
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (value) {
                context = value;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        );
        final approval = confirmContextSourceMutation(
          context,
          chat: chat,
          conversationId: 'c',
          groups: {'u'},
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(ContextImpactDialog), findsOneWidget);
        expect(chat.previewReads, 1);
        expect(chat.requestedRevision, 'approved-revision');
        expect(chat.preview.isCompleted, isFalse);
        final l10n = AppLocalizationsEn();
        await tester.tap(
          find.text(
            confirm ? l10n.contextImpactConfirm(1) : l10n.homePageCancel,
          ),
        );
        await tester.pumpAndSettle();
        expect(await approval, confirm ? 'approved-revision' : null);
        chat.preview.complete((
          messages: <ChatMessage>[],
          operations: <ContextOperation>[],
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unaffected source skips body and budget reads', (tester) async {
    final chat = _Chat();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      await confirmContextSourceMutation(
        context,
        chat: chat,
        conversationId: 'c',
        groups: {'outside'},
      ),
      'approved-revision',
    );
    expect(chat.previewReads, 0);
    expect(find.byType(ContextImpactDialog), findsNothing);
  });
}
