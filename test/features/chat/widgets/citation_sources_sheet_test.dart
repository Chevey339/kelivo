import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/chat/widgets/citation_sources_sheet.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';

void main() {
  testWidgets(
    'citation source card uses favicone.com favicon and document style',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationSourceCard(
              item: const CitationSourceItem(
                title: 'Kelivo release notes',
                url: 'https://example.com/releases/1',
                text: 'A concise source summary',
                sourceName: 'Example',
                publishedText: '2026-05-23',
              ),
              displayIndex: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(
        (image.image as NetworkImage).url,
        'https://favicone.com/example.com',
      );
      expect(image.width, 14);
      expect(image.height, 14);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Kelivo release notes'), findsOneWidget);
      expect(
        find.text('2026-05-23 - A concise source summary'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'citation sources sheet renders search results header and cards',
    (tester) async {
      var opened = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationSourcesSheet(
              title: '搜索结果',
              count: 2,
              closeSemanticLabel: '关闭',
              items: const [
                CitationSourceItem(
                  title: 'First source',
                  url: 'example.com/first',
                  text: 'First quote',
                ),
                CitationSourceItem(
                  title: 'Second source',
                  url: 'https://docs.example.org/second',
                  text: 'Second quote',
                ),
              ],
              onDismiss: () {},
              onOpen: (item) => opened = item.url,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('First source'), findsOneWidget);
      expect(find.text('Second source'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CitationSourceCard).first).dy,
        greaterThan(tester.getBottomLeft(find.text('搜索结果')).dy),
      );
      expect(
        tester.getTopLeft(find.byType(CitationSourceCard).first).dx -
            tester.getTopLeft(find.byKey(CustomBottomSheet.panelKey)).dx,
        12,
      );
      expect(
        tester.getTopRight(find.byKey(CustomBottomSheet.panelKey)).dx -
            tester.getTopRight(find.byType(CitationSourceCard).first).dx,
        12,
      );
      expect(
        tester.getTopLeft(find.text('First source')).dx,
        tester.getTopLeft(find.text('搜索结果')).dx,
      );
      expect(
        tester
            .getTopRight(
              find.byKey(
                const ValueKey<String>('citation_source_index_badge_1'),
              ),
            )
            .dx,
        tester.getTopRight(find.byKey(CustomBottomSheet.closeButtonKey)).dx,
      );

      await tester.tap(find.text('First source'));
      expect(opened, 'example.com/first');
    },
  );

  testWidgets('citation sources opener uses dialog on desktop targets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    try {
      var opened = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showCitationSourcesBottomSheet(
                      context: context,
                      title: '搜索结果',
                      closeSemanticLabel: '关闭',
                      items: const [
                        CitationSourceItem(
                          title: 'Desktop source',
                          url: 'https://desktop.example.com/source',
                          text: 'Desktop quote',
                        ),
                      ],
                      onOpen: (item) => opened = item.url,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CitationSourcesDialog), findsOneWidget);
      expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.byType(CitationSourceCard), findsOneWidget);
      expect(find.text('Desktop source'), findsOneWidget);

      await tester.tap(find.text('Desktop source'));
      expect(opened, 'https://desktop.example.com/source');

      await tester.tap(find.byKey(CitationSourcesDialog.closeButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(CitationSourcesDialog), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('citation sources opener keeps bottom sheet on mobile targets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showCitationSourcesBottomSheet(
                      context: context,
                      title: '搜索结果',
                      closeSemanticLabel: '关闭',
                      items: const [
                        CitationSourceItem(
                          title: 'Mobile source',
                          url: 'https://mobile.example.com/source',
                          text: 'Mobile quote',
                        ),
                      ],
                      onOpen: (_) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CitationSourcesDialog), findsNothing);
      expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
      expect(find.text('Mobile source'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
