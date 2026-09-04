import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';

import '../../support/business_test_harness.dart';

void main() {
  testWidgets('items render, tap pops then calls onTap, destructive colour', (
    tester,
  ) async {
    var tapped = false;
    final order = <String>[];
    final observer = _PopObserver(() => order.add('pop'));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          navigatorObservers: [observer],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    showMobileActionSheet(
                      context,
                      items: [
                        ActionSheetItem(
                          icon: Lucide.Pencil,
                          label: 'Edit',
                          onTap: () {
                            order.add('tap');
                            tapped = true;
                          },
                        ),
                        const ActionSheetItem(
                          icon: Lucide.Trash2,
                          label: 'Delete',
                          destructive: true,
                          onTap: _noop,
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.byIcon(Lucide.Pencil), findsOneWidget);
    expect(find.byIcon(Lucide.Trash2), findsOneWidget);

    final error = Theme.of(
      tester.element(find.text('Delete')),
    ).colorScheme.error;
    expect(tester.widget<Icon>(find.byIcon(Lucide.Trash2)).color, error);
    expect(tester.widget<Text>(find.text('Delete')).style?.color, error);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('Edit'), findsNothing);
    expect(order, ['pop', 'tap']);
  });
}

void _noop() {}

class _PopObserver extends NavigatorObserver {
  _PopObserver(this.onPop);

  final VoidCallback onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop();
  }
}
