import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/desktop/setting/search_services_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop add dialog rejects invalid Brave maximum tokens', (
    tester,
  ) async {
    SearchServiceOptions? created;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        created = await showDesktopAddSearchServiceDialog(context);
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await _selectServiceType(tester, 'Brave Search');
    await _selectLlmContext(tester);

    final tokensField = find.byKey(
      const ValueKey('desktop-search-service-field-maximumNumberOfTokens'),
    );
    expect(tokensField, findsOneWidget);

    await tester.enterText(tokensField, 'abc');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(created, isNull);
    expect(
      find.text('Maximum tokens must be between 1024 and 32768.'),
      findsOneWidget,
    );
    expect(find.text('Add Search Service'), findsOneWidget);

    await tester.enterText(tokensField, '2048');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(created, isA<BraveOptions>());
    expect((created! as BraveOptions).maximumNumberOfTokens, 2048);
    expect((created! as BraveOptions).mode, BraveOptions.llmContextMode);
  });

  testWidgets('desktop add dialog saves Parallel mode from the styled select', (
    tester,
  ) async {
    SearchServiceOptions? created;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        created = await showDesktopAddSearchServiceDialog(context);
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await _selectServiceType(tester, 'Parallel');
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(DropdownMenu<String>), findsNothing);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turbo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(created, isA<ParallelOptions>());
    expect((created! as ParallelOptions).mode, 'turbo');
  });

  testWidgets('desktop add dialog saves Kagi credentials', (tester) async {
    SearchServiceOptions? created;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        created = await showDesktopAddSearchServiceDialog(context);
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await _selectServiceType(tester, 'Kagi');
    await tester.enterText(find.byType(TextField).last, 'kagi-key');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(created, isA<KagiOptions>());
    expect((created! as KagiOptions).apiKey, 'kagi-key');
  });

  testWidgets('desktop edit dialog updates Kagi credentials', (tester) async {
    SearchServiceOptions? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          KagiOptions(
            id: 'kagi',
            apiKey: 'old-key',
            extraApiKeys: const ['backup-key'],
          ),
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'new-key');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updated, isA<KagiOptions>());
    final saved = updated! as KagiOptions;
    expect(saved.id, 'kagi');
    expect(saved.apiKey, 'new-key');
    expect(saved.extraApiKeys, ['backup-key']);
  });
  testWidgets(
    'desktop add dialog saves Kimi with the selected mode',
    (tester) async {
      SearchServiceOptions? created;
      await _pumpDialogHost(
        tester,
        onOpen: (context) async {
          created = await showDesktopAddSearchServiceDialog(context);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _selectServiceType(tester, 'Kimi');
      await tester.enterText(find.byType(TextField), 'kimi-key');
      await tester.tap(find.text('Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final saved = created! as KimiOptions;
      expect(saved.apiKey, 'kimi-key');
      expect(saved.mode, 'basic');
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'desktop edit dialog preserves Kimi keys and changes mode',
    (tester) async {
      SearchServiceOptions? updated;
      await _pumpDialogHost(
        tester,
        onOpen: (context) async {
          updated = await showDesktopEditSearchServiceDialog(
            context,
            KimiOptions(
              id: 'kimi',
              apiKey: 'kimi-key',
              mode: 'basic',
              extraApiKeys: const ['extra-key'],
            ),
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pro').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = updated! as KimiOptions;
      expect(saved.id, 'kimi');
      expect(saved.apiKey, 'kimi-key');
      expect(saved.mode, 'pro');
      expect(saved.extraApiKeys, ['extra-key']);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets('desktop edit dialog saves You.com content mode', (tester) async {
    SearchServiceOptions? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          YouSearchOptions(
            id: 'you',
            apiKey: 'you-key',
            contentMode: YouSearchOptions.highlightsMode,
          ),
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.tap(find.text('Highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snippets').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updated, isA<YouSearchOptions>());
    expect(
      (updated! as YouSearchOptions).contentMode,
      YouSearchOptions.snippetsMode,
    );
  });

  testWidgets(
    'desktop edit dialog keeps an existing token value when input is invalid',
    (tester) async {
      SearchServiceOptions? updated;
      await _pumpDialogHost(
        tester,
        onOpen: (context) async {
          updated = await showDesktopEditSearchServiceDialog(
            context,
            BraveOptions(
              id: 'brave',
              apiKey: 'brave-key',
              mode: BraveOptions.llmContextMode,
              maximumNumberOfTokens: 2048,
            ),
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final tokensField = find.byKey(
        const ValueKey('desktop-search-service-field-maximumNumberOfTokens'),
      );
      await tester.enterText(tokensField, '50000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(updated, isNull);
      expect(
        find.text('Maximum tokens must be between 1024 and 32768.'),
        findsOneWidget,
      );
      expect(find.text('Brave Search'), findsOneWidget);
    },
  );
}

Future<void> _pumpDialogHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onOpen,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => onOpen(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _selectServiceType(WidgetTester tester, String label) async {
  await tester.tap(find.text('Bing (Local)'));
  await tester.pumpAndSettle();
  final option = find.text(label);
  await tester.dragUntilVisible(
    option,
    find.byType(SingleChildScrollView).last,
    const Offset(0, -80),
  );
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

Future<void> _selectLlmContext(WidgetTester tester) async {
  await tester.tap(find.text('Web Search'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('LLM Context').last);
  await tester.pumpAndSettle();
}
