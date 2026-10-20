import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_library.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'history clear action shares the search row and requires confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final store = _MemoryStore({
        'history': List.generate(
          20,
          (index) => BrowserHistoryEntry(
            url: 'https://example.com/$index',
            title: 'Saved page $index',
            visitedAt: DateTime.now().subtract(Duration(minutes: index)),
          ).toJson(),
        ),
      });
      final service = BrowserService(store: store);
      await service.initialize();
      final errors = <Object>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrowserManagementPage(
            title: 'History',
            child: BrowserLibrary(
              service: service,
              section: BrowserLibrarySection.history,
              onOpen: (_) {},
              onError: errors.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final clear = find.byTooltip('Clear history');
      final search = find.byType(BrowserTextField);
      expect(clear, findsOneWidget);
      expect(find.text('Clear history'), findsNothing);
      final clearBounds = tester.getRect(clear);
      final searchBounds = tester.getRect(search);
      expect(clearBounds.size, const Size(44, 44));
      expect(clearBounds.center.dy, closeTo(searchBounds.center.dy, .01));
      expect(clearBounds.left, greaterThan(searchBounds.right));
      final list = find.byType(CustomScrollView);
      expect(tester.getRect(list), const Rect.fromLTWH(0, 0, 390, 844));
      final back = tester.getRect(
        find.byKey(const ValueKey('browserManagementBack')),
      );
      expect(searchBounds.top, greaterThan(back.bottom));
      await tester.drag(list, const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(clear.hitTestable(), findsNothing);
      expect(tester.getRect(list), const Rect.fromLTWH(0, 0, 390, 844));
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(service.history, hasLength(20));
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(service.history, hasLength(20));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.history, hasLength(20));
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(service.history, isEmpty);
      expect(clear, findsNothing);
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await tester.pumpAndSettle();
    },
  );
  for (final section in BrowserLibrarySection.values) {
    testWidgets(
      'mobile $section offers header search and cancelling restores entries',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final service = BrowserService(
          store: _MemoryStore({
            'bookmarks': [
              for (final name in ['Keep', 'Hide'])
                BrowserBookmark(
                  url: 'https://example.com/$name',
                  title: name,
                  createdAt: DateTime.now(),
                ).toJson(),
            ],
            'history': [
              for (final name in ['Keep', 'Hide'])
                BrowserHistoryEntry(
                  url: 'https://example.com/$name',
                  title: name,
                  visitedAt: DateTime.now(),
                ).toJson(),
            ],
            'downloads': [
              for (final name in ['Keep', 'Hide'])
                BrowserDownload(
                  id: name,
                  url: 'https://example.com/$name',
                  fileName: name,
                  status: BrowserDownloadStatus.completed,
                ).toJson(),
            ],
          }),
        );
        await service.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BrowserLibrary(
              service: service,
              section: section,
              mobileManagement: true,
              onOpen: (_) {},
              onError: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BrowserManagementPage), findsOneWidget);
        expect(find.byType(BrowserTextField), findsNothing);
        expect(find.text('Keep'), findsOneWidget);
        expect(find.text('Hide'), findsOneWidget);
        final search = find.byKey(const ValueKey('browserLibrarySearchAction'));
        final backBounds = tester.getRect(
          find.byKey(const ValueKey('browserManagementBack')),
        );
        final searchBounds = tester.getRect(search);
        expect(searchBounds.size, const Size(48, 48));
        expect(searchBounds.center.dy, closeTo(backBounds.center.dy, .01));
        expect(searchBounds.center.dx, greaterThan(195));
        expect(
          tester.getRect(find.text('Keep')).top,
          greaterThan(backBounds.bottom),
        );
        await tester.tap(search);
        await tester.pumpAndSettle();
        final field = find.byType(BrowserTextField);
        expect(field, findsOneWidget);
        expect(
          tester.widget<BrowserTextField>(field).focusNode!.hasFocus,
          isTrue,
        );
        expect(tester.getRect(field).top, greaterThan(backBounds.bottom));
        await tester.enterText(field, 'Keep');
        await tester.pumpAndSettle();
        expect(find.text('Hide'), findsNothing);
        expect(find.text('Keep'), findsWidgets);
        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(BrowserTextField), findsNothing);
        expect(find.text('Keep'), findsOneWidget);
        expect(find.text('Hide'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'mobile history clear stays in its header and preserves confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = BrowserService(
        store: _MemoryStore({
          'history': [
            for (var i = 0; i < 25; i++)
              BrowserHistoryEntry(
                url: 'https://example.com/$i',
                title: 'Entry $i',
                visitedAt: DateTime.now(),
              ).toJson(),
          ],
        }),
      );
      await service.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrowserLibrary(
            service: service,
            section: BrowserLibrarySection.history,
            mobileManagement: true,
            onOpen: (_) {},
            onError: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final clear = find.byKey(
        const ValueKey('browserLibraryClearHistoryAction'),
      );
      final search = find.byKey(const ValueKey('browserLibrarySearchAction'));
      final clearBounds = tester.getRect(clear);
      expect(clearBounds.size, const Size(48, 48));
      expect(clearBounds.left, closeTo(tester.getRect(search).right, .01));
      final searchIcon = tester.widget<Icon>(
        find.descendant(of: search, matching: find.byType(Icon)),
      );
      final deleteIcon = tester.widget<Icon>(
        find.descendant(of: clear, matching: find.byType(Icon)),
      );
      final scheme = Theme.of(tester.element(search)).colorScheme;
      expect(searchIcon.color, scheme.onSurface);
      expect(deleteIcon.color, scheme.error);
      final group = find.byKey(const ValueKey('browserLibraryHistoryActions'));
      expect(tester.getSize(group), const Size(96, 48));
      expect(
        find.descendant(of: group, matching: find.byType(BrowserGlass)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: group, matching: find.byType(BrowserPress)),
        findsOneWidget,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(clear), clearBounds);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserTextField).hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.history, hasLength(25));
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(service.history, isEmpty);
      expect(tester.widget<BrowserSurfaceIconButton>(clear).onPressed, isNull);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.text('Clear history'), findsNothing);
      expect(find.byType(BrowserTextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await tester.pumpAndSettle();
    },
  );

  for (final section in BrowserLibrarySection.values) {
    testWidgets(
      '$section ignores native page progress but refreshes its entries',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late _ProgressEngine engine;
        final service = _LibraryService(
          store: _MemoryStore({}),
          engineFactory:
              ({
                required tab,
                required settings,
                required onChanged,
                required onDownload,
                required onNewWindow,
                required isAgentActive,
              }) async => engine = _ProgressEngine(onChanged),
        );
        await service.initialize();
        await service.createTab(url: 'https://example.com');
        await service.navigate('https://example.com');
        var style = BrowserSurfaceStyle.liquid;
        late StateSetter setStyle;
        final library = BrowserLibrary(
          service: service,
          section: section,
          mobileManagement: true,
          onOpen: (_) {},
          onError: (_) {},
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StatefulBuilder(
                builder: (_, setter) {
                  setStyle = setter;
                  return BrowserGlassScope(style: style, child: library);
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          Widget header() => tester.widget(find.byType(BrowserManagementPage));
          Widget list() => tester.widget(find.byType(CustomScrollView));
          final initialHeader = header();
          final initialList = list();
          for (var i = 0; i < 20; i++) {
            engine.onChanged(
              BrowserPageState(isLoading: true, progress: i / 100),
            );
            await tester.pump();
          }
          expect(identical(header(), initialHeader), isTrue);
          expect(identical(list(), initialList), isTrue);
          switch (section) {
            case BrowserLibrarySection.bookmarks:
              await service.addBookmark(
                url: 'https://example.com/saved',
                title: 'Added entry',
              );
            case BrowserLibrarySection.history:
              engine.onChanged(
                const BrowserPageState(
                  title: 'Added entry',
                  isLoading: false,
                  completedNavigation: true,
                ),
              );
            case BrowserLibrarySection.downloads:
              service.publishDownload(
                const BrowserDownload(
                  id: 'download',
                  url: 'https://example.com/file',
                  fileName: 'Added entry',
                  receivedBytes: 25,
                  totalBytes: 100,
                ),
              );
          }
          await tester.pumpAndSettle();
          expect(find.text('Added entry'), findsOneWidget);
          expect(identical(header(), initialHeader), isFalse);
          expect(identical(list(), initialList), isFalse);
          final populatedHeader = header();
          final populatedList = list();
          engine.onChanged(
            const BrowserPageState(isLoading: true, progress: .8),
          );
          if (section == BrowserLibrarySection.bookmarks) {
            engine.onChanged(
              const BrowserPageState(
                title: 'Unrelated history',
                completedNavigation: true,
              ),
            );
          } else {
            await service.addBookmark(
              url: 'https://other.example',
              title: 'Unrelated bookmark',
            );
          }
          await tester.pumpAndSettle();
          expect(identical(header(), populatedHeader), isTrue);
          expect(identical(list(), populatedList), isTrue);
          if (section == BrowserLibrarySection.downloads) {
            expect(
              tester
                  .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator),
                  )
                  .value,
              .25,
            );
            service.publishDownload(
              service.downloads.single.copyWith(receivedBytes: 75),
            );
            await tester.pumpAndSettle();
            expect(find.text('75 B'), findsOneWidget);
            expect(
              tester
                  .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator),
                  )
                  .value,
              .75,
            );
          }
          // Material dependencies must still update below the cached selector.
          final beforeStyle = header();
          setStyle(() => style = BrowserSurfaceStyle.frosted);
          await tester.pumpAndSettle();
          final search = find.byKey(
            const ValueKey('browserLibrarySearchAction'),
          );
          expect(identical(header(), beforeStyle), isTrue);
          expect(
            BrowserGlassScope.of(tester.element(search)),
            BrowserSurfaceStyle.frosted,
          );
          final material = section == BrowserLibrarySection.history
              ? find.byKey(const ValueKey('browserLibraryHistoryActions'))
              : search;
          expect(
            find.descendant(
              of: material,
              matching: find.byType(BackdropFilter),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          service.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('empty downloads keep the full viewport with large type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final service = BrowserService(store: _MemoryStore({}));
    await service.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(3)),
          child: child!,
        ),
        home: BrowserManagementPage(
          title: 'Downloads',
          child: BrowserLibrary(
            service: service,
            section: BrowserLibrarySection.downloads,
            onOpen: (_) {},
            onError: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(CustomScrollView)),
      const Rect.fromLTWH(0, 0, 320, 844),
    );
    final search = tester.getRect(find.byType(BrowserTextField));
    final back = tester.getRect(
      find.byKey(const ValueKey('browserManagementBack')),
    );
    expect(search.top, greaterThan(back.bottom));
    expect(find.byType(BrowserEmptyState), findsOneWidget);
    final message = find.text('Downloaded files appear here.');
    expect(message, findsOneWidget);
    expect(tester.getRect(message).top, greaterThan(search.bottom));
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(message).bottom, lessThanOrEqualTo(844 - 34));
    expect(tester.getRect(message).top, greaterThan(back.bottom));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await tester.pumpAndSettle();
  });
}

class _MemoryStore extends BrowserStore {
  _MemoryStore(this.state);
  Map<String, dynamic> state;
  @override
  Future<Map<String, dynamic>> read() async => state;
  @override
  Future<void> write(Map<String, Object?> value) async {
    state = Map<String, dynamic>.from(value);
  }
}

// Download callbacks are internal to BrowserService's network task. Publish
// identical immutable snapshots here to isolate the widget subscription contract.
class _LibraryService extends BrowserService {
  _LibraryService({required super.store, required super.engineFactory});
  List<BrowserDownload> _items = [];
  @override
  List<BrowserDownload> get downloads => List.unmodifiable(_items);
  void publishDownload(BrowserDownload item) {
    _items = [item];
    notifyListeners();
  }
}

class _ProgressEngine extends BrowserEngine {
  _ProgressEngine(this.onChanged);
  final void Function(BrowserPageState) onChanged;
  @override
  Future<void> navigate(String url) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected engine call: ${invocation.memberName}');
}
