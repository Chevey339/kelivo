import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

Widget _app(
  UiContextText text, {
  bool dark = false,
  bool stale = false,
  bool readOnly = false,
  double scale = 1,
  VoidCallback? remove,
}) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 360,
        child: GenUiContextChip(
          content: text,
          stale: stale,
          readOnly: readOnly,
          onRemove: remove,
        ),
      ),
    ),
  ),
);

void main() {
  final frozen = UiContextText(
    title: 'Curve',
    body: 'Slope: 3.1\nIntercept: 1',
  );
  testWidgets(
    'expanded chip exposes the exact frozen text across appearance changes',
    (tester) async {
      await tester.pumpWidget(_app(frozen));
      expect(find.text(frozen.exactText), findsNothing);
      await tester.tap(find.byKey(const ValueKey('genui-context-expand')));
      await tester.pumpAndSettle();
      expect(find.text(frozen.exactText), findsOneWidget);
      await tester.pumpWidget(_app(frozen, dark: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(find.text(frozen.exactText), findsOneWidget);
      expect(tester.takeException(), isNull);
      final replacement = UiContextText(title: 'Curve', body: 'Slope: 5');
      await tester.pumpWidget(_app(replacement));
      await tester.pumpAndSettle();
      expect(find.text(frozen.exactText), findsNothing);
      expect(find.text(replacement.exactText), findsNothing);
    },
  );
  testWidgets('stale chip remains inspectable and can be removed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var removed = 0;
    await tester.pumpWidget(_app(frozen, stale: true, remove: () => removed++));
    expect(
      find.text('Source unavailable — remove or attach again'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Remove attached UI'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('genui-context-expand')));
    await tester.pumpAndSettle();
    expect(find.text(frozen.exactText), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('genui-context-remove')));
    expect(removed, 1);
    semantics.dispose();
  });
  testWidgets('sent chip shows a summary without composer controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(frozen, readOnly: true));
    expect(find.text('Curve'), findsOneWidget);
    expect(find.text('Slope: 3.1 · Intercept: 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('genui-context-remove')), findsNothing);
    expect(find.byKey(const ValueKey('genui-context-expand')), findsNothing);
    expect(find.text(frozen.exactText), findsNothing);
  });
}
