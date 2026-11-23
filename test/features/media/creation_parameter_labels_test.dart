import 'package:Kelivo/features/media/widgets/creation_ratio_grid.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/sliding_segmented_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'parameter labels and selected size fit at large text sizes in ${direction.name}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: Directionality(
                  textDirection: direction,
                  child: Material(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 288,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CreationRatioGrid(
                              values: const ['auto', '1:1', '3:2', '2:3'],
                              selected: 'auto',
                              onChanged: (_) {},
                            ),
                            SlidingSegmentedTabs(
                              fitLabels: true,
                              index: 2,
                              tabs: const [
                                SegmentedTab(label: '1024×1024'),
                                SegmentedTab(label: '1536×1024'),
                                SegmentedTab(label: '1024×1536'),
                              ],
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final ratio = find.byType(CreationRatioGrid);
        final label = AppLocalizations.of(tester.element(ratio))!.creationAuto;
        for (final value in [label, '2:3', '1024×1536']) {
          final text = find.text(value);
          expect(text.hitTestable(), findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
          );
          final rect = tester.getRect(text);
          expect(rect.left, greaterThanOrEqualTo(tester.getRect(ratio).left));
          expect(rect.right, lessThanOrEqualTo(tester.getRect(ratio).right));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
