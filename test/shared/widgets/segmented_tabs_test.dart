import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/segmented_tabs.dart';

void main() {
  testWidgets(
    'renders three tabs, reports tap index, and centers selected primary label',
    (tester) async {
      var index = 0;
      final changed = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SegmentedTabs(
                  tabs: const [
                    SegmentedTab(label: 'One'),
                    SegmentedTab(label: 'Two'),
                    SegmentedTab(label: 'Three'),
                  ],
                  index: index,
                  onChanged: (value) {
                    changed.add(value);
                    setState(() => index = value);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);

      for (final label in ['One', 'Two', 'Three']) {
        expect(
          tester.widget<Text>(find.text(label)).textAlign,
          TextAlign.center,
        );
      }

      final cs = Theme.of(
        tester.element(find.byType(SegmentedTabs)),
      ).colorScheme;
      expect(tester.widget<Text>(find.text('One')).style?.color, cs.primary);

      await tester.tap(find.text('Two'));
      await tester.pump();

      expect(changed, [1]);
      expect(tester.widget<Text>(find.text('Two')).style?.color, cs.primary);
    },
  );
}
