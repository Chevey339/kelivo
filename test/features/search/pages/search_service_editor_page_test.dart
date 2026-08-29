import 'dart:async';

import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/search_service_usage_service.dart';
import 'package:Kelivo/features/search/pages/search_api_keys_page.dart';
import 'package:Kelivo/features/search/pages/search_service_editor_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not show the provider description', (tester) async {
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'old-key'),
      onResult: (_) {},
    );

    expect(
      find.text(
        'AI search API optimized for LLMs. Provides high-quality, relevant results.',
      ),
      findsNothing,
    );
  });

  testWidgets('centers provider identity and has no bottom save bar', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'old-key'),
      onResult: (_) {},
    );

    final providerHeader = tester.widget<Row>(
      find.byKey(const ValueKey('search-service-provider-header')),
    );
    expect(providerHeader.crossAxisAlignment, CrossAxisAlignment.center);

    final editorScaffold = find.descendant(
      of: find.byType(SearchServiceEditorPage),
      matching: find.byType(Scaffold),
    );
    expect(editorScaffold, findsOneWidget);
    expect(tester.widget<Scaffold>(editorScaffold).bottomNavigationBar, isNull);
  });

  testWidgets('queries existing provider usage when the editor opens', (
    tester,
  ) async {
    var queryCount = 0;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'old-key'),
      autoQueryUsage: true,
      usageFetcher: (options) async {
        queryCount++;
        expect(options, isA<TavilyOptions>());
        return const SearchServiceUsageInfo(
          remaining: 850,
          used: 150,
          limit: 1000,
        );
      },
      onResult: (_) {},
    );

    expect(queryCount, 1);
    expect(find.text('850 credits remaining'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('tavily-usage-progress')),
          )
          .value,
      0.15,
    );
  });

  testWidgets('keeps cached usage visible and reports refresh failures', (
    tester,
  ) async {
    final service = TavilyOptions(id: 'cached-tavily', apiKey: 'cached-key');
    await _pumpEditor(
      tester,
      initialService: service,
      autoQueryUsage: true,
      usageFetcher: (_) async =>
          const SearchServiceUsageInfo(remaining: 400, used: 600, limit: 1000),
      onResult: (_) {},
    );
    await tester.tap(find.byIcon(Lucide.ArrowLeft));
    await tester.pumpAndSettle();

    final refreshedUsage = Completer<SearchServiceUsageInfo>();
    await _pumpEditor(
      tester,
      initialService: service,
      autoQueryUsage: true,
      usageFetcher: (_) => refreshedUsage.future,
      settle: false,
      onResult: (_) {},
    );

    expect(find.text('400 credits remaining'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-refreshing')), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-loading')), findsNothing);

    refreshedUsage.complete(
      const SearchServiceUsageInfo(remaining: 350, used: 650, limit: 1000),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('350 credits remaining'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-refreshing')), findsNothing);

    await tester.tap(find.byIcon(Lucide.ArrowLeft));
    await tester.pumpAndSettle();
    await _pumpEditor(
      tester,
      initialService: service,
      autoQueryUsage: true,
      usageFetcher: (_) async =>
          throw const SearchServiceUsageException('refresh denied'),
      onResult: (_) {},
    );

    expect(find.text('350 credits remaining'), findsOneWidget);
    expect(find.text('Could not query usage: refresh denied'), findsOneWidget);
  });

  testWidgets('ignores test search results from an obsolete query', (
    tester,
  ) async {
    final firstSearch = Completer<SearchResult>();
    final secondSearch = Completer<SearchResult>();
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'test-search', apiKey: 'key'),
      searchFetcher: (query, _) => switch (query) {
        'first' => firstSearch.future,
        'second' => secondSearch.future,
        _ => throw StateError('Unexpected query: $query'),
      },
      onResult: (_) {},
    );

    await tester.dragUntilVisible(
      _testQueryField(),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.enterText(_testQueryField(), 'first');
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.Play));
    await tester.pump();

    await tester.enterText(_testQueryField(), 'second');
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.Play));
    await tester.pump();

    secondSearch.complete(SearchResult(answer: 'second result', items: []));
    await tester.pumpAndSettle();
    expect(find.text('second result'), findsOneWidget);

    firstSearch.complete(SearchResult(answer: 'first result', items: []));
    await tester.pumpAndSettle();
    expect(find.text('second result'), findsOneWidget);
    expect(find.text('first result'), findsNothing);
  });

  testWidgets('ignores usage errors from an obsolete configuration', (
    tester,
  ) async {
    final staleUsage = Completer<SearchServiceUsageInfo>();
    final currentUsage = Completer<SearchServiceUsageInfo>();
    var requestCount = 0;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'usage-generation', apiKey: 'old-key'),
      autoQueryUsage: true,
      usageFetcher: (options) {
        requestCount++;
        if (requestCount == 1) {
          expect((options as TavilyOptions).apiKey, 'old-key');
          return staleUsage.future;
        }
        expect((options as TavilyOptions).apiKey, 'new-key');
        return currentUsage.future;
      },
      settle: false,
      onResult: (_) {},
    );

    await tester.enterText(_apiKeyField(), 'new-key');
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.RefreshCw));
    await tester.pump();

    staleUsage.completeError(Exception('stale failure'));
    await tester.pump();
    expect(find.text('Could not query usage: stale failure'), findsNothing);
    expect(find.byKey(const ValueKey('usage-refreshing')), findsOneWidget);

    currentUsage.complete(
      const SearchServiceUsageInfo(remaining: 900, used: 100, limit: 1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('900 credits remaining'), findsOneWidget);
    expect(requestCount, 2);
  });

  testWidgets('does not cache usage from an obsolete request', (tester) async {
    final olderUsage = Completer<SearchServiceUsageInfo>();
    final newerUsage = Completer<SearchServiceUsageInfo>();
    var requestCount = 0;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'usage-cache-order', apiKey: 'key-a'),
      autoQueryUsage: true,
      usageFetcher: (_) {
        requestCount++;
        return requestCount == 1 ? olderUsage.future : newerUsage.future;
      },
      settle: false,
      onResult: (_) {},
    );

    await tester.enterText(_apiKeyField(), 'key-b');
    await tester.pump();
    await tester.enterText(_apiKeyField(), 'key-a');
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.RefreshCw));
    await tester.pump();

    newerUsage.complete(
      const SearchServiceUsageInfo(remaining: 900, used: 100, limit: 1000),
    );
    await tester.pumpAndSettle();
    olderUsage.complete(
      const SearchServiceUsageInfo(remaining: 100, used: 900, limit: 1000),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_apiKeyField(), 'key-b');
    await tester.pump();
    await tester.enterText(_apiKeyField(), 'key-a');
    await tester.pump();

    expect(find.text('900 credits remaining'), findsOneWidget);
    expect(find.text('100 credits remaining'), findsNothing);
    expect(requestCount, 2);
  });

  testWidgets('opens only normalized HTTP search result URLs', (tester) async {
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    var searchCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          if (call.method == 'launch') {
            launchedUrl = (call.arguments as Map)['url'] as String?;
            return true;
          }
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, null);
    });

    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'test-links', apiKey: 'key'),
      searchFetcher: (_, _) async {
        searchCount++;
        return SearchResult(
          items: [
            SearchResultItem(
              title: 'No scheme',
              url: 'example.com/path',
              text: '',
            ),
            SearchResultItem(
              title: 'Unsafe scheme',
              url: 'intent://danger',
              text: '',
            ),
            SearchResultItem(
              title: 'Host port',
              url: 'localhost:3000/status',
              text: '',
            ),
          ],
        );
      },
      onResult: (_) {},
    );

    await tester.dragUntilVisible(
      _testQueryField(),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.enterText(_testQueryField(), 'links');
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.Play));
    await tester.pumpAndSettle();
    expect(searchCount, 1);

    await tester.dragUntilVisible(
      find.text('No scheme'),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.tap(find.text('No scheme'));
    await tester.pump();
    expect(launchedUrl, 'https://example.com/path');

    launchedUrl = null;
    await tester.dragUntilVisible(
      find.text('Host port'),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.tap(find.text('Host port'));
    await tester.pump();
    expect(launchedUrl, 'https://localhost:3000/status');

    launchedUrl = null;
    await tester.dragUntilVisible(
      find.text('Unsafe scheme'),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.tap(find.text('Unsafe scheme'));
    await tester.pump();
    expect(launchedUrl, isNull);
  });

  testWidgets('saves edited provider settings from the full page', (
    tester,
  ) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'old-key'),
      onResult: (value) => result = value,
    );

    await tester.enterText(_apiKeyField(), 'new-key');
    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result?.deleted, isFalse);
    expect(result?.service, isA<TavilyOptions>());
    expect((result!.service! as TavilyOptions).apiKey, 'new-key');
  });

  testWidgets('preserves Firecrawl sources and categories when saving', (
    tester,
  ) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: FirecrawlOptions(
        id: 'firecrawl',
        apiKey: 'old-key',
        sources: const ['web', 'news'],
        categories: const ['github'],
        country: 'US',
      ),
      onResult: (value) => result = value,
    );

    await tester.enterText(_apiKeyField(), 'new-key');
    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result?.deleted, isFalse);
    expect(result?.service, isA<FirecrawlOptions>());
    final saved = result!.service! as FirecrawlOptions;
    expect(saved.apiKey, 'new-key');
    expect(saved.sources, ['web', 'news']);
    expect(saved.categories, ['github']);
    expect(saved.country, 'US');
  });

  testWidgets('saves Firecrawl without an API key', (tester) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: FirecrawlOptions(id: 'firecrawl', apiKey: ''),
      onResult: (value) => result = value,
    );

    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result?.deleted, isFalse);
    expect(result?.service, isA<FirecrawlOptions>());
    expect((result!.service! as FirecrawlOptions).apiKey, isEmpty);
  });

  testWidgets('saves AnySearch without an API key', (tester) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: AnySearchOptions(id: 'anysearch', apiKey: ''),
      onResult: (value) => result = value,
    );

    expect(find.text(AnySearchOptions.defaultUrl), findsOneWidget);
    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result?.deleted, isFalse);
    expect(result?.service, isA<AnySearchOptions>());
    expect((result!.service! as AnySearchOptions).apiKey, isEmpty);
  });

  testWidgets('returns a delete action after confirmation', (tester) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'key'),
      canDelete: true,
      onResult: (value) => result = value,
    );

    await tester.tap(find.byIcon(Lucide.Trash2));
    await tester.pumpAndSettle();
    expect(find.text('Delete search service?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result?.deleted, isTrue);
    expect(result?.service, isNull);
  });

  testWidgets('shows Tavily usage as a determinate progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(tavilySearchUsageCardPreview());

    expect(find.text('账户用量'), findsOneWidget);
    expect(find.text('查询用量'), findsNothing);
    expect(find.text('剩余 750 额度'), findsOneWidget);
    expect(find.text('已使用 250 / 1,000 额度'), findsOneWidget);

    final queryAction = find.byKey(
      const ValueKey('search-service-usage-query'),
    );
    expect(queryAction, findsOneWidget);
    expect(
      find.descendant(of: queryAction, matching: find.byIcon(Lucide.RefreshCw)),
      findsOneWidget,
    );
    expect(tester.widget<Tooltip>(queryAction).message, '查询用量');

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('tavily-usage-progress')),
    );
    expect(progress.value, 0.25);

    final titleCenter = tester.getCenter(find.text('账户用量'));
    final queryCenter = tester.getCenter(queryAction);
    expect((titleCenter.dy - queryCenter.dy).abs(), lessThan(4));
    expect(queryCenter.dx, greaterThan(titleCenter.dx));
  });

  testWidgets('shows LinkUp as a balance without a progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(linkUpSearchUsageCardPreview());

    expect(find.text('余额 123.46'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('manages the full key pool on the API keys page', (tester) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(id: 'tavily', apiKey: 'primary-key'),
      onResult: (value) => result = value,
    );

    expect(find.text('1 keys'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('search-service-multikey-entry')),
    );
    await tester.pumpAndSettle();

    final page = find.byType(SearchApiKeysPage);
    expect(page, findsOneWidget);
    final popScope = tester.widget<PopScope<List<String>>>(
      find.descendant(of: page, matching: find.byType(PopScope<List<String>>)),
    );
    expect(popScope.canPop, isTrue);
    // The primary key is auto-imported as the first row.
    expect(find.text('prim••••-key'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);

    // Batch paste: newline and comma separated keys.
    await tester.enterText(
      find.byKey(const ValueKey('search-api-keys-batch-field')),
      'tvly-a\ntvly-b,tvly-c',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Added 3, skipped 0 duplicate(s)'), findsOneWidget);

    // Duplicates of existing keys are skipped.
    await tester.enterText(
      find.byKey(const ValueKey('search-api-keys-batch-field')),
      'primary-key',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Added 0, skipped 1 duplicate(s)'), findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.byIcon(Lucide.Trash2)),
      findsNWidgets(4),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('4 keys'), findsOneWidget);

    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    final saved = result?.service;
    expect(saved, isA<TavilyOptions>());
    expect((saved as TavilyOptions?)?.apiKey, 'primary-key');
    expect(saved?.extraApiKeys, ['tvly-a', 'tvly-b', 'tvly-c']);
  });

  testWidgets('deleting the primary key promotes the next one', (tester) async {
    SearchServiceEditorResult? result;
    await _pumpEditor(
      tester,
      initialService: TavilyOptions(
        id: 'tavily',
        apiKey: 'primary-key',
        extraApiKeys: const ['k2', 'k3'],
      ),
      onResult: (value) => result = value,
    );

    expect(find.text('3 keys'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('search-service-multikey-entry')),
    );
    await tester.pumpAndSettle();

    final page = find.byType(SearchApiKeysPage);
    await tester.tap(
      find.descendant(of: page, matching: find.byIcon(Lucide.Trash2)).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: page, matching: find.byIcon(Lucide.Trash2)),
      findsNWidgets(2),
    );

    await tester.tap(
      find.descendant(of: page, matching: find.byIcon(Lucide.ArrowLeft)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    final saved = result?.service;
    expect(saved, isA<TavilyOptions>());
    expect((saved as TavilyOptions?)?.apiKey, 'k2');
    expect(saved?.extraApiKeys, ['k3']);
  });
}

Finder _apiKeyField() {
  return find.descendant(
    of: find.byKey(const ValueKey('search-service-field-apiKey')),
    matching: find.byType(TextFormField),
  );
}

Finder _testQueryField() {
  return find.byKey(const ValueKey('search-service-test-query'));
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required SearchServiceOptions initialService,
  required ValueChanged<SearchServiceEditorResult?> onResult,
  bool canDelete = false,
  bool autoQueryUsage = false,
  SearchServiceUsageFetcher? usageFetcher,
  SearchServiceTestFetcher? searchFetcher,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<SearchServiceEditorResult>(
                      MaterialPageRoute(
                        builder: (_) => SearchServiceEditorPage(
                          initialService: initialService,
                          commonOptions: const SearchCommonOptions(),
                          canDelete: canDelete,
                          autoQueryUsage: autoQueryUsage,
                          usageFetcher: usageFetcher,
                          searchFetcher: searchFetcher,
                        ),
                      ),
                    );
                onResult(result);
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}
