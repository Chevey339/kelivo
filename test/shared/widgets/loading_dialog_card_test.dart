import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/shared/widgets/loading_dialog_card.dart';

void main() {
  group('LoadingDialogCard', () {
    testWidgets('renders activity indicator without label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingDialogCard())),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders optional label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingDialogCard(label: '正在加载')),
        ),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('正在加载'), findsOneWidget);
    });
  });
}
