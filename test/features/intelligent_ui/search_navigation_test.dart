import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_search_navigation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

void main() {
  testWidgets(
    'block navigation reveals only the addressed surface and consumes one request',
    (tester) async {
      final navigation = UiSearchNavigation();
      final scroll = ScrollController();
      addTearDown(navigation.dispose);
      addTearDown(scroll.dispose);
      Widget surface(String id) => UiSearchReveal(
        conversationId: 'c',
        owner: UiSurfaceOwner(revisionId: 'r', surfaceKey: id),
        child: SizedBox(
          key: ValueKey(id),
          height: 100,
          child: Text('Surface $id'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UiSearchNavigationScope(
              navigation: navigation,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    surface('0:0'),
                    const SizedBox(height: 1200),
                    surface('0:1'),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      navigation.reveal('wrong', 'r', '0:1');
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      navigation.reveal('c', 'r', '0:1');
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(1000));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('0:1'))).dy,
        lessThan(500),
      );
      expect(navigation.value, isNull);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
    },
  );
  testWidgets(
    'a request waits for the addressed block to mount and never affects export snapshots',
    (tester) async {
      final navigation = UiSearchNavigation();
      final scroll = ScrollController();
      addTearDown(navigation.dispose);
      addTearDown(scroll.dispose);
      Widget app(bool exporting) => MaterialApp(
        home: Scaffold(
          body: UiSearchNavigationScope(
            navigation: navigation,
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 1500),
                  UiSearchReveal(
                    conversationId: 'c',
                    owner: const UiSurfaceOwner(
                      revisionId: 'r',
                      surfaceKey: '0:2',
                    ),
                    enabled: !exporting,
                    child: const SizedBox(height: 100, child: Text('Target')),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      navigation.reveal('c', 'r', '0:2');
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(navigation.value, isNotNull);
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(1000));
      expect(navigation.value, isNull);
    },
  );
}
