import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../../core/models/context_operation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/theme_factory.dart';
import 'context_node_divider.dart';

@Preview(
  name: 'Context dividers · light',
  group: 'Chat context',
  size: Size(620, 180),
)
Widget contextOperationPreview() => _preview(false);
@Preview(
  name: 'Context dividers · dark',
  group: 'Chat context',
  size: Size(620, 180),
)
Widget contextOperationDarkPreview() => _preview(true);

Widget _preview(bool dark) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          for (final kind in ContextOperationKind.values) ...[
            ContextOperationDivider(
              operation: ContextOperation(
                id: kind.name,
                kind: kind,
                anchorGroupId: 'a',
                appliedAfterGroupId: 'b',
                sourceGroups: const ['a'],
                dependencies: const [],
                createdAt: DateTime(2026),
                summary: '',
                originalSummary: '',
              ),
              onOpen: () {},
              onUndo: () {},
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  ),
);
