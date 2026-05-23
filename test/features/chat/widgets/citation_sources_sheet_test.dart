import 'package:flutter/material.dart';
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
}
