import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/tip_icon.dart';

void main() {
  testWidgets('TipIcon exposes the message for tap / long-press', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TipIcon(message: 'hello tip')),
      ),
    );

    expect(find.byType(TipIcon), findsOneWidget);
    expect(find.byTooltip('hello tip'), findsOneWidget);
  });
}
