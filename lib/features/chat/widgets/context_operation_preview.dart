import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/models/context_operation.dart';
import '../../../l10n/app_localizations.dart';
import 'context_operation_widgets.dart';

@Preview(name: 'Context · mobile', group: 'Chat context', size: Size(360, 640))
@Preview(name: 'Context · desktop', group: 'Chat context', size: Size(760, 680))
Widget contextOperationPreview() => const _ContextPreview();

class _ContextPreview extends StatefulWidget {
  const _ContextPreview();
  @override
  State<_ContextPreview> createState() => _ContextPreviewState();
}

class _ContextPreviewState extends State<_ContextPreview> {
  var operation = ContextOperation(
    id: 'preview',
    kind: ContextOperationKind.compress,
    anchorGroupId: 'a',
    appliedAfterGroupId: 'b',
    sourceGroups: const ['u', 'a'],
    dependencies: const [],
    createdAt: DateTime(2026, 10, 24),
    keepUserMessages: 6,
    model: 'Compression model',
    inputTokens: 1800,
    inputMode: 'keepRecent',
    summary: '项目决定：保留最近 6 条用户消息和完整工具过程。压缩期间的输入复用现有待发功能。',
    originalSummary: '项目决定：保留最近 6 条用户消息和完整工具过程。压缩期间的输入复用现有待发功能。',
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ContextOperationDivider(
              operation: operation,
              onOpen: () {},
              onUndo: () =>
                  setState(() => operation = operation.copyWith(revoked: true)),
            ),
            Expanded(
              child: ContextOperationContent(
                key: ValueKey(operation.summary),
                operation: operation,
                budget: (usedTokens: 2500, contextWindow: 32000),
                undoBudget: (usedTokens: 4200, contextWindow: 32000),
                onClose: () {},
                onSave: (summary) async {
                  setState(
                    () => operation = operation.copyWith(summary: summary),
                  );
                  return true;
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
