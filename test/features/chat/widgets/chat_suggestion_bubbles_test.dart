import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/chat/widgets/chat_suggestion_bubbles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders suggestion bubbles and reports taps', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatSuggestionBubbles(
            suggestions: const ['继续', '举例', '总结'],
            onTap: tapped.add,
          ),
        ),
      ),
    );

    expect(find.text('继续'), findsOneWidget);
    expect(find.text('举例'), findsOneWidget);
    expect(find.text('总结'), findsOneWidget);

    await tester.tap(find.text('举例'));
    await tester.pump();

    expect(tapped, ['举例']);
  });
}
