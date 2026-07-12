import 'package:Kelivo/features/home/widgets/timeline_jump_to_latest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('jump capsule is accessible and invokes the explicit action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineJumpToLatest(
            label: 'Jump to latest',
            isGenerating: false,
            bottomOffset: 12,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Jump to latest'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('timeline-jump-semantics')),
      ),
      matchesSemantics(
        label: 'Jump to latest',
        isButton: true,
        isLiveRegion: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('timeline-jump-to-latest')));
    expect(taps, 1);
  });

  testWidgets(
    'jump capsule exposes streaming progress without changing label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineJumpToLatest(
              label: 'Jump to latest',
              isGenerating: true,
              bottomOffset: 12,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Jump to latest'), findsOneWidget);
    },
  );
}
