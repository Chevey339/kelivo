import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/quote_chip.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/quote_syntax.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'desktop hover delays preview, permits pointer transfer and removes the whole quote',
    (tester) async {
      var removed = false;
      final reference = QuoteRef(
        id: 'q',
        messageId: 'source',
        start: 0,
        end: 40,
        text: 'Full original source is available in the preview',
        model: 'Model',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: QuoteChip(
                quote: reference,
                onRemove: () => removed = true,
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(QuoteChip)));
      await tester.pump(const Duration(milliseconds: 399));
      expect(find.text(reference.text), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.text(reference.text), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.text(reference.text)));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text(reference.text), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.byType(QuoteChip)));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byIcon(LucideIcons.x));
      expect(removed, isTrue);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'jump highlight expires after 1.5 seconds while draft source highlights persist',
    (tester) async {
      final actions = QuoteInteractionController(
        onQuote: (_) async {},
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      final quote = QuoteRef(
        id: 'q',
        messageId: 'source',
        start: 4,
        end: 12,
        text: 'original',
        model: null,
        createdAt: DateTime(2026),
      );
      actions.reveal(quote);
      expect(actions.highlightsFor('source').single, quote);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(actions.highlightsFor('source'), isNotEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(actions.highlightsFor('source'), isEmpty);
      actions.setDraftQuotes([quote]);
      actions.reveal(quote);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(actions.highlightsFor('source').single, quote);
    },
  );

  for (final text in [
    '**Before** \uFFFC and \uFFFC after',
    'Before `call(\uFFFC)` and `\uFFFC` after',
    'Before\n\n```dart\nfinal value = \uFFFC;\n```\n\nAfter \uFFFC',
  ]) {
    testWidgets('sent Markdown preserves code/prose reference tokens: $text', (
      tester,
    ) async {
      final refs = [
        for (var i = 0; i < 2; i++)
          QuoteRef(
            id: '$i',
            messageId: 'm$i',
            start: 0,
            end: 6,
            text: 'source$i',
            model: 'Model',
            createdAt: DateTime(2026),
          ),
      ];
      final jumps = <String>[];
      final actions = QuoteInteractionController(
        onQuote: (_) async {},
        onJump: (quote) async {
          jumps.add(quote.messageId);
          return true;
        },
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: QuoteInteractionScope(
                controller: actions,
                child: QuoteRenderScope(
                  source: text,
                  quotes: refs,
                  child: MarkdownWithCodeHighlight(text: text),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuoteChip), findsNWidgets(2));
      await tester.tap(find.byType(QuoteChip).last);
      await tester.pumpAndSettle();
      expect(jumps, ['m1']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'mobile draft preview exposes jump and removal and missing-source styling',
    (tester) async {
      var removed = false;
      final actions = QuoteInteractionController(
        onQuote: (_) async {},
        onJump: (_) async => false,
        sourceExists: (_) async => false,
      );
      addTearDown(actions.dispose);
      final quote = QuoteRef(
        id: 'q',
        messageId: 'gone',
        start: 0,
        end: 4,
        text: 'Full original quote preserved even after deletion',
        model: 'Model',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuoteInteractionScope(
              controller: actions,
              child: Center(
                child: QuoteChip(quote: quote, onRemove: () => removed = true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(QuoteChip));
      await tester.pumpAndSettle();
      expect(find.text(quote.text), findsOneWidget);
      expect(find.text('Jump to source'), findsOneWidget);
      expect(find.text('Source no longer exists'), findsOneWidget);
      await tester.tap(find.text('Remove quote'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}
