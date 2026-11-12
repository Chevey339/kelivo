import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/visible_route_theme.dart';
import 'package:Kelivo/shared/widgets/interactive_drawer.dart';

void main() {
  final first = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Colors.blue,
    ),
  );
  final second = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.dark,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Colors.orange,
    ),
  );

  for (final opaque in [true, false]) {
    testWidgets(
      'theme follows visible routes and defers opaque=$opaque coverage',
      (tester) async {
        final theme = ValueNotifier(first);
        final navigator = GlobalKey<NavigatorState>();
        final scroll = ScrollController();
        final input = TextEditingController();
        var builds = 0;
        Color? primary, selection, ambient;
        Brightness? brightness;
        final home = VisibleRouteTheme(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                builds++;
                primary = Theme.of(context).colorScheme.primary;
                brightness = Theme.of(context).brightness;
                selection = DefaultSelectionStyle.of(context).selectionColor;
                return SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(height: 700),
                      TextField(controller: input),
                      const SizedBox(height: 700),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpWidget(
          ValueListenableBuilder<ThemeData>(
            valueListenable: theme,
            builder: (_, value, _) => MaterialApp(
              navigatorKey: navigator,
              theme: value,
              themeAnimationDuration: const Duration(milliseconds: 200),
              home: home,
              builder: (context, child) {
                ambient = Theme.of(context).colorScheme.primary;
                return child!;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        input.value = const TextEditingValue(
          text: 'retained draft',
          selection: TextSelection(baseOffset: 2, extentOffset: 8),
        );
        scroll.jumpTo(500);
        await tester.pumpAndSettle();
        final field = tester.state(find.byType(EditableText));
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            opaque: opaque,
            transitionDuration: const Duration(milliseconds: 100),
            reverseTransitionDuration: const Duration(milliseconds: 100),
            pageBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        );
        await tester.pumpAndSettle();
        final before = builds;
        theme.value = second;
        await tester.pump();
        final afterDispatch = builds;
        await tester.pump(const Duration(milliseconds: 75));
        expect(ambient, isNot(first.colorScheme.primary));
        expect(ambient, isNot(second.colorScheme.primary));
        if (opaque) {
          expect(builds, afterDispatch);
          expect(primary, first.colorScheme.primary);
          expect(selection, Colors.blue);
        } else {
          expect(builds, greaterThan(before));
          expect(primary, ambient);
          expect(selection, Colors.orange);
        }
        await tester.pumpAndSettle();
        if (opaque) expect(builds, afterDispatch);
        navigator.currentState!.pop();
        await tester.pump();
        expect(primary, second.colorScheme.primary);
        expect(brightness, Brightness.dark);
        expect(selection, Colors.orange);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EditableText)), same(field));
        expect(find.text('retained draft'), findsOneWidget);
        expect(
          input.selection,
          const TextSelection(baseOffset: 2, extentOffset: 8),
        );
        expect(scroll.offset, 500);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        theme.dispose();
        scroll.dispose();
        input.dispose();
      },
    );
  }

  for (final fromDescendant in [false, true]) {
    testWidgets(
      'dialogs from descendant=$fromDescendant follow the app theme',
      (tester) async {
        final theme = ValueNotifier(first);
        Color? dialogColor;
        await tester.pumpWidget(
          ValueListenableBuilder<ThemeData>(
            valueListenable: theme,
            builder: (_, value, _) => MaterialApp(
              theme: value,
              home: Builder(
                builder: (pageContext) => VisibleRouteTheme(
                  child: Scaffold(
                    body: Builder(
                      builder: (childContext) => TextButton(
                        onPressed: () => showDialog<void>(
                          context: fromDescendant ? childContext : pageContext,
                          builder: (context) {
                            dialogColor = Theme.of(context).colorScheme.primary;
                            return const AlertDialog(
                              content: Text('Live theme'),
                            );
                          },
                        ),
                        child: const Text('Open dialog'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        expect(dialogColor, first.colorScheme.primary);
        theme.value = second;
        await tester.pumpAndSettle();
        expect(dialogColor, second.colorScheme.primary);
        await tester.pumpWidget(const SizedBox.shrink());
        theme.dispose();
      },
    );
  }

  testWidgets('font ancestor changes retain the open drawer and its controls', (
    tester,
  ) async {
    final font = ValueNotifier(false);
    final navigator = GlobalKey<NavigatorState>();
    final drawer = InteractiveDrawerController();
    final home = VisibleRouteTheme(
      child: InteractiveDrawer(
        controller: drawer,
        drawerWidth: 240,
        drawer: TextButton(
          onPressed: drawer.close,
          child: const Text('Switch topic'),
        ),
        child: const Scaffold(body: TextField()),
      ),
    );
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: font,
        builder: (_, customFont, _) => MaterialApp(
          navigatorKey: navigator,
          home: home,
          builder: (_, child) => customFont
              ? DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'custom'),
                  child: child!,
                )
              : child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final drawerState = tester.state(find.byType(InteractiveDrawer));
    final inputState = tester.state(find.byType(EditableText));
    await tester.enterText(find.byType(TextField), 'draft');
    await drawer.open();
    await tester.pumpAndSettle();
    for (final enabled in [true, false, true]) {
      font.value = enabled;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(InteractiveDrawer)), same(drawerState));
      expect(tester.state(find.byType(EditableText)), same(inputState));
      expect(drawer.isOpen, isTrue);
      await tester.tap(find.text('Switch topic'));
      await tester.pumpAndSettle();
      expect(drawer.isClosed, isTrue);
      await drawer.open();
      await tester.pumpAndSettle();
    }
    expect(find.text('draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    font.dispose();
    drawer.dispose();
  });

  testWidgets(
    'revealing during a theme animation uses the current interpolated theme',
    (tester) async {
      final theme = ValueNotifier(first);
      final navigator = GlobalKey<NavigatorState>();
      Color? visible, ambient;
      final home = VisibleRouteTheme(
        child: Builder(
          builder: (context) {
            visible = Theme.of(context).colorScheme.primary;
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeData>(
          valueListenable: theme,
          builder: (_, value, _) => MaterialApp(
            navigatorKey: navigator,
            theme: value,
            home: home,
            builder: (context, child) {
              ambient = Theme.of(context).colorScheme.primary;
              return child!;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
      );
      await tester.pumpAndSettle();
      theme.value = second;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(visible, first.colorScheme.primary);
      navigator.currentState!.pop();
      await tester.pump();
      expect(visible, ambient);
      expect(visible, isNot(first.colorScheme.primary));
      expect(visible, isNot(second.colorScheme.primary));
      await tester.pumpAndSettle();
      expect(visible, second.colorScheme.primary);
      await tester.pumpWidget(const SizedBox.shrink());
      theme.dispose();
    },
  );
}
