import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
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
      link: links.length == 1 ? links.first : null,
      changedLinks: links,
      changedFiles: files,
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

  test('marks image links', () {
    final entries = collectProducedFileEntries([
      _write(links: ['kelivo://workspace/plot.PNG']),
      _write(links: ['kelivo://workspace/note.txt']),
    ]);
    expect(entries[0].isImage, isTrue);
    expect(entries[1].isImage, isFalse);
  });

  testWidgets('limits visible chips and shows +N', (tester) async {
    final parts = <WorkspaceToolPart>[
      for (var i = 0; i < 15; i++)
        _write(links: ['kelivo://workspace/file_$i.txt']),
    ];
    expect(collectProducedFileEntries(parts), hasLength(15));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProducedFilesRow(parts: parts, conversationId: 'c1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(ProducedFilesRow.rowKey), findsOneWidget);
    expect(find.byKey(ProducedFilesRow.moreKey), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('file_0.txt'), findsOneWidget);
    expect(find.text('file_14.txt'), findsNothing);
  });
}
