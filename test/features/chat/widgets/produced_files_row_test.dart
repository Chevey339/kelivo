import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/chat/widgets/produced_files_row.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

WorkspaceToolPart _write({required List<String> links, List<String>? files}) {
  return WorkspaceToolPart(
    id: links.join('|'),
    toolName: 'write_file',
    metadata: WorkspaceToolMetadata(
      tool: 'write_file',
      status: 'ok',
      path: files?.first ?? links.first,
      files: [
        for (var i = 0; i < links.length; i++)
          WorkspaceToolFile(
            path: files != null && i < files.length
                ? files[i]
                : KelivoLink.tryParse(links[i])?.relativePath ?? links[i],
            link: links[i],
            role: WorkspaceFileRole.modified,
          ),
      ],
    ).toJson(),
  );
}

void main() {
  test('dedupes produced files by first appearance', () {
    final entries = collectProducedFileEntries([
      _write(links: ['kelivo://workspace/a.txt']),
      _write(links: ['kelivo://workspace/b.txt']),
      _write(links: ['kelivo://workspace/a.txt']),
    ]);
    expect(entries.map((e) => e.dedupeKey).toList(), [
      'kelivo://workspace/a.txt',
      'kelivo://workspace/b.txt',
    ]);
  });

  test(
    'collects confirmed shell changes, excluding reads, logs, temp and denials',
    () {
      WorkspaceToolPart part(
        String tool,
        WorkspaceToolFile file, {
        String status = 'ok',
        String? id,
      }) => WorkspaceToolPart(
        id: id ?? tool,
        toolName: tool,
        metadata: WorkspaceToolMetadata(
          tool: tool,
          status: status,
          files: [file],
        ).toJson(),
      );
      const result = WorkspaceToolFile(
        path: '/workspace/result.csv',
        link: 'kelivo://workspace/result.csv',
        role: WorkspaceFileRole.created,
      );
      final entries = collectProducedFileEntries([
        part(
          'read_file',
          const WorkspaceToolFile(path: '/workspace/input.txt'),
        ),
        part('grep', const WorkspaceToolFile(path: '/workspace/found.txt')),
        part('shell', result, status: 'error'),
        part('edit_file', result, id: 'edit-again'),
        part(
          'shell',
          const WorkspaceToolFile(
            path: '/chat/outputs/log.txt',
            role: WorkspaceFileRole.log,
          ),
        ),
        part(
          'write_file',
          const WorkspaceToolFile(
            path: '/tmp/temp.txt',
            role: WorkspaceFileRole.created,
            temporary: true,
          ),
        ),
        part(
          'write_file',
          const WorkspaceToolFile(
            path: '/workspace/denied.txt',
            role: WorkspaceFileRole.created,
          ),
          status: 'denied',
        ),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.link, result.link);
      expect(entries.single.revision, 'edit-again');
    },
  );

  test('marks image links', () {
    final entries = collectProducedFileEntries([
      _write(links: ['kelivo://workspace/plot.PNG']),
      _write(links: ['kelivo://workspace/note.txt']),
    ]);
    expect(entries[0].isImage, isTrue);
    expect(entries[1].isImage, isFalse);
  });

  test(
    'decodes link-only labels once and preserves their original targets',
    () {
      const cases = {
        'kelivo://workspace/%E6%96%B0%E6%96%87%E4%BB%B6.txt': '新文件.txt',
        'kelivo://chat/outputs/报告%20終稿.txt': '报告 終稿.txt',
        'kelivo://workspace/資料/한글.txt': '資料/한글.txt',
        'kelivo://workspace/literal%2520%25.txt': 'literal%20%.txt',
        'kelivo://workspace/invalid%ZZ.txt':
            'kelivo://workspace/invalid%ZZ.txt',
      };
      for (final testCase in cases.entries) {
        final entry = collectProducedFileEntries([
          _write(links: [testCase.key]),
        ]).single;
        expect(entry.label, testCase.value);
        expect(entry.link, testCase.key);
        expect(entry.dedupeKey, testCase.key);
      }
    },
  );

  test('keeps explicit file paths literal', () {
    const path = '/workspace/原始%20文件.txt';
    final entry = collectProducedFileEntries([
      _write(links: ['kelivo://workspace/原始%2520文件.txt'], files: [path]),
    ]).single;
    expect(entry.label, path);
  });

  testWidgets('shows a decoded CJK name in the produced file chip', (
    tester,
  ) async {
    const link = 'kelivo://workspace/%E6%96%B0%E6%96%87%E4%BB%B6.txt';
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProducedFilesRow(
              parts: [
                _write(links: [link]),
              ],
              conversationId: 'c1',
            ),
          ),
        ),
      ),
    );

    expect(find.text('新文件.txt'), findsOneWidget);
    expect(find.text('%E6%96%B0%E6%96%87%E4%BB%B6.txt'), findsNothing);
    final chip = tester.widget<WorkspaceFileChip>(
      find.byType(WorkspaceFileChip),
    );
    expect(chip.link, link);
    expect(chip.conversationId, 'c1');
    expect(find.byTooltip('新文件.txt'), findsOneWidget);
  });

  testWidgets('limits visible chips and shows +N', (tester) async {
    final parts = <WorkspaceToolPart>[
      for (var i = 0; i < 15; i++)
        _write(links: ['kelivo://workspace/file_$i.txt']),
    ];
    expect(collectProducedFileEntries(parts), hasLength(15));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProducedFilesRow(parts: parts, conversationId: 'c1'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(ProducedFilesRow.rowKey), findsOneWidget);
    expect(find.byKey(ProducedFilesRow.moreKey), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('file_0.txt'), findsOneWidget);
    expect(find.text('file_14.txt'), findsNothing);
    await tester.tap(find.byKey(ProducedFilesRow.moreKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('file_14.txt'), 300);
    expect(find.text('file_14.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
