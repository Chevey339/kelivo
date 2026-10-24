import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/widgets/mini_map_sheet.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

void main() {
  final messages = [
    ChatMessage(
      id: 'user-1',
      role: 'user',
      content: 'alpha user prompt',
      conversationId: 'conversation',
    ),
    ChatMessage(
      id: 'asst-1',
      role: 'assistant',
      content: 'first assistant reply',
      conversationId: 'conversation',
    ),
    ChatMessage(
      id: 'user-2',
      role: 'user',
      content: 'beta user prompt',
      conversationId: 'conversation',
    ),
    ChatMessage(
      id: 'asst-2',
      role: 'assistant',
      content: 'second assistant reply',
      conversationId: 'conversation',
    ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    Future<List<MiniMapSearchHit>> Function(String query)? onSearch,
    ValueChanged<MiniMapSearchHit>? onSearchHitSelected,
    ValueChanged<String?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showMiniMapSheet(
                      context,
                      messages,
                      onSearch: onSearch,
                      onSearchHitSelected: onSearchHitSelected,
                    ).then<void>((value) {
                      onResult?.call(value);
                    }),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Lucide.Search));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('miniMapSearchField')), findsOneWidget);
  }

  testWidgets('debounces onSearch until 250ms have elapsed', (tester) async {
    final queries = <String>[];
    await pumpSheet(
      tester,
      onSearch: (query) async {
        queries.add(query);
        return const <MiniMapSearchHit>[];
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump();
    expect(queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 249));
    expect(queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(queries, ['needle']);
  });

  testWidgets('drops stale search results', (tester) async {
    final first = Completer<List<MiniMapSearchHit>>();
    final second = Completer<List<MiniMapSearchHit>>();
    await pumpSheet(
      tester,
      onSearch: (query) {
        if (query == 'alpha') return first.future;
        return second.future;
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    first.complete([
      const MiniMapSearchHit(
        messageId: 'asst-1',
        matchCount: 1,
        snippet: 'stale-snippet-token',
        snippetStart: 0,
      ),
    ]);
    await tester.pump();
    expect(find.text('stale-snippet-token', findRichText: true), findsNothing);

    second.complete([
      const MiniMapSearchHit(
        messageId: 'asst-2',
        matchCount: 2,
        snippet: 'fresh-snippet-token',
        snippetStart: 0,
      ),
    ]);
    await tester.pump();
    expect(
      find.text('fresh-snippet-token', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('drops in-flight results after the query changes', (
    tester,
  ) async {
    final first = Completer<List<MiniMapSearchHit>>();
    await pumpSheet(
      tester,
      onSearch: (query) {
        if (query == 'alpha') return first.future;
        return Future.value(const <MiniMapSearchHit>[]);
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump();

    first.complete([
      const MiniMapSearchHit(
        messageId: 'asst-1',
        matchCount: 1,
        snippet: 'stale-snippet-token',
        snippetStart: 0,
      ),
    ]);
    await tester.pump();
    expect(find.text('stale-snippet-token', findRichText: true), findsNothing);
  });

  testWidgets('renders snippet and match count from onSearch hits', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      onSearch: (query) async {
        return const [
          MiniMapSearchHit(
            messageId: 'asst-1',
            matchCount: 4,
            snippet: 'visible-snippet-token',
            snippetStart: 0,
          ),
        ];
      },
    );
    await openSearch(tester);

    expect(find.text('alpha user prompt'), findsOneWidget);
    expect(find.text('beta user prompt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'visible');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(
      find.text('visible-snippet-token', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('beta user prompt'), findsNothing);
    expect(find.text('first assistant reply'), findsNothing);
  });

  testWidgets('clearing search restores the full pair list', (tester) async {
    await pumpSheet(
      tester,
      onSearch: (query) async {
        return const [
          MiniMapSearchHit(
            messageId: 'asst-1',
            matchCount: 1,
            snippet: 'only-first-hit',
            snippetStart: 0,
          ),
        ];
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'only');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('beta user prompt'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('alpha user prompt'), findsOneWidget);
    expect(find.text('beta user prompt'), findsOneWidget);
    expect(find.text('only-first-hit', findRichText: true), findsNothing);
  });

  testWidgets('flattens snippet newlines so the keyword stays visible', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      onSearch: (query) async {
        return const [
          MiniMapSearchHit(
            messageId: 'asst-1',
            matchCount: 1,
            snippet: 'context\nvisible-needle',
            snippetStart: 0,
          ),
        ];
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'visible-needle');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(
      find.text('context visible-needle', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('highlights a flattened needle after collapsing snippet spaces', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      onSearch: (query) async {
        return const [
          MiniMapSearchHit(
            messageId: 'asst-1',
            matchCount: 1,
            snippet: 'prefix foo  bar suffix',
            snippetStart: 0,
          ),
        ];
      },
    );
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'foo  bar');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(
      find.text('prefix foo bar suffix', findRichText: true),
      findsOneWidget,
    );

    final highlight = tester
        .element(find.byType(TextField))
        .appColors
        .searchHighlight;
    final highlighted = <String>[];
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      final root = rich.text;
      if (root is! TextSpan) continue;
      if (root.toPlainText() != 'prefix foo bar suffix') continue;
      void walk(InlineSpan span) {
        if (span is! TextSpan) return;
        if (span.style?.backgroundColor == highlight && span.text != null) {
          highlighted.add(span.text!);
        }
        span.children?.forEach(walk);
      }

      walk(root);
    }
    expect(highlighted, ['foo bar']);
  });
  testWidgets(
    'selecting a semantic hit returns its revision and explicit surface address',
    (tester) async {
      const hit = MiniMapSearchHit(
        messageId: 'asst-1',
        matchCount: 1,
        snippet: 'Target result: 42',
        snippetStart: 0,
        matchedSurfaceKey: '0:1',
      );
      MiniMapSearchHit? selected;
      String? revision;
      await pumpSheet(
        tester,
        onSearch: (_) async => [hit],
        onSearchHitSelected: (value) => selected = value,
        onResult: (value) => revision = value,
      );
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'Target');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Target result: 42', findRichText: true));
      await tester.pumpAndSettle();
      expect(selected, same(hit));
      expect(revision, 'asst-1');
    },
  );
}
