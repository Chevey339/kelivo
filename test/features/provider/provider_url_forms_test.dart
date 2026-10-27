import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/add_provider_dialog.dart';
import 'package:Kelivo/features/provider/pages/provider_detail_page.dart';
import 'package:Kelivo/features/provider/widgets/add_provider_sheet.dart';
import 'package:Kelivo/features/provider/widgets/provider_base_url_field.dart';
import 'package:Kelivo/features/provider/widgets/provider_input_row.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import '../../support/business_test_harness.dart';

Future<SettingsProvider> mount(
  WidgetTester tester,
  bool desktop, {
  String key = 'Relay',
  bool adding = false,
  ProviderKind kind = ProviderKind.openai,
  bool responses = false,
  ValueNotifier<String>? selectedProvider,
}) async {
  tester.view.physicalSize = desktop
      ? const Size(1100, 900)
      : const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await settings.setProviderConfig(
    key,
    ProviderConfig(
      id: key,
      enabled: true,
      name: key,
      apiKey: 'test-key',
      baseUrl: 'https://saved.example.com',
      providerType: kind,
      useResponseApi: responses,
      chatPath: '/chat/completions',
      models: ['test-model'],
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => AppSnackBarOverlay(child: child!),
        home: adding
            ? Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      if (desktop) {
                        showDesktopAddProviderDialog(context);
                      } else {
                        showAddProviderSheet(context);
                      }
                    },
                    child: const Text('Open add'),
                  ),
                ),
              )
            : desktop
            ? Scaffold(
                body: selectedProvider == null
                    ? DesktopProviderDetailPane(
                        providerKey: key,
                        displayName: key,
                      )
                    : ValueListenableBuilder<String>(
                        valueListenable: selectedProvider,
                        builder: (_, key, _) => key.isEmpty
                            ? const SizedBox()
                            : DesktopProviderDetailPane(
                                providerKey: key,
                                displayName: key,
                              ),
                      ),
              )
            : ProviderDetailPage(keyName: key, displayName: key),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    AppSnackBarManager().dismissAll();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  if (adding) {
    await tester.tap(find.text('Open add'));
    await tester.pumpAndSettle();
  }
  return settings;
}

Finder get baseField => find
    .descendant(
      of: find.byType(ProviderBaseUrlField),
      matching: find.byType(TextField),
    )
    .first;
Future<void> edit(WidgetTester tester, String value) async {
  await tester.ensureVisible(baseField);
  await tester.enterText(baseField, value);
  await tester.pumpAndSettle();
}

Future<void> blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

String value(WidgetTester tester) =>
    tester.widget<TextField>(baseField).controller!.text;

void formTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      AppSnackBarManager().dismissAll();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  for (final swipe in [false, true]) {
    formTest('mobile saves the URL before opening models with swipe=$swipe', (
      tester,
    ) async {
      final settings = await mount(tester, false);
      await edit(tester, 'https://edited.example.com/v3');
      if (swipe) {
        await tester.dragFrom(
          tester.getTopRight(find.byType(PageView)) + const Offset(-8, 12),
          const Offset(-380, 0),
        );
      } else {
        await tester.tap(find.text('Models').last);
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      expect(
        settings.getProviderConfig('Relay').baseUrl,
        'https://edited.example.com/v3',
      );
      expect(find.text('test-model').hitTestable(), findsOneWidget);
    });
  }
  formTest('mobile model tab keeps auto-version undo usable', (tester) async {
    final settings = await mount(tester, false);
    await edit(tester, 'https://edited.example.com');
    await tester.tap(find.text('Models').last);
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://edited.example.com/v1',
    );
    AppSnackBarManager().activeToasts.first.notification.onAction!();
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://edited.example.com',
    );
    expect(settings.getProviderConfig('Relay').autoVersionDisabled, isTrue);
  });

  formTest('closing desktop pane saves its focused URL draft', (tester) async {
    final settings = await mount(tester, true);
    await edit(tester, 'https://edited.example.com/v3');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://edited.example.com/v3',
    );
  });
  formTest('leaving the desktop pane normalizes and preserves undo', (
    tester,
  ) async {
    final selected = ValueNotifier('Relay');
    addTearDown(selected.dispose);
    final settings = await mount(tester, true, selectedProvider: selected);
    await edit(tester, 'https://edited.example.com');
    selected.value = '';
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://edited.example.com/v1',
    );
    AppSnackBarManager().activeToasts.first.notification.onAction!();
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://edited.example.com',
    );
    expect(settings.getProviderConfig('Relay').autoVersionDisabled, isTrue);
  });
  formTest('disposing an invalid desktop draft preserves the saved URL', (
    tester,
  ) async {
    final settings = await mount(tester, true);
    await edit(tester, '');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('Relay').baseUrl,
      'https://saved.example.com',
    );
  });
  formTest('desktop path saves final IME composition on blur', (tester) async {
    final settings = await mount(tester, true);
    final row = find.byWidgetPredicate(
      (w) => w is ProviderInputRow && w.label == 'API Path',
    );
    final field = find.descendant(of: row, matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.showKeyboard(field);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '/special/chat',
        selection: TextSelection.collapsed(offset: 13),
        composing: TextRange(start: 0, end: 13),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '/special/chat',
        selection: TextSelection.collapsed(offset: 13),
      ),
    );
    await tester.pump();
    await blur(tester);
    expect(settings.getProviderConfig('Relay').chatPath, '/special/chat');
  });

  formTest(
    'desktop switching provider commits its draft without affecting the next provider',
    (tester) async {
      final selected = ValueNotifier('Relay');
      addTearDown(selected.dispose);
      final settings = await mount(tester, true, selectedProvider: selected);
      await settings.setProviderConfig(
        'Other',
        settings
            .getProviderConfig('Relay')
            .copyWith(id: 'Other', baseUrl: 'https://other.example.com/v3'),
      );
      await edit(tester, 'https://edited.example.com');
      selected.value = 'Other';
      await tester.pumpAndSettle();
      expect(
        settings.getProviderConfig('Relay').baseUrl,
        'https://edited.example.com/v1',
      );
      expect(value(tester), 'https://other.example.com/v3');
      AppSnackBarManager().activeToasts.first.notification.onAction!();
      await tester.pumpAndSettle();
      expect(
        settings.getProviderConfig('Relay').baseUrl,
        'https://edited.example.com',
      );
      expect(value(tester), 'https://other.example.com/v3');
      expect(tester.takeException(), isNull);
    },
  );
  formTest(
    'mobile returning from detail commits the draft and leaves undo usable',
    (tester) async {
      final settings = await mount(tester, false);
      final navigator = Navigator.of(tester.element(baseField));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const ProviderDetailPage(keyName: 'Relay', displayName: 'Relay'),
        ),
      );
      await tester.pumpAndSettle();
      await edit(tester, 'https://edited.example.com');
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        settings.getProviderConfig('Relay').baseUrl,
        'https://edited.example.com/v1',
      );
      AppSnackBarManager().activeToasts.first.notification.onAction!();
      await tester.pumpAndSettle();
      expect(
        settings.getProviderConfig('Relay').baseUrl,
        'https://edited.example.com',
      );
      expect(tester.takeException(), isNull);
    },
  );
  formTest('mobile keyboard leaves the field and helper visible', (
    tester,
  ) async {
    await mount(tester, false);
    await edit(tester, 'https://api.example.com');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final helper = find.text(
      'No version in URL; /v1 will be added when you leave the field',
    );
    expect(tester.getBottomRight(helper).dy, lessThanOrEqualTo(552));
    expect(tester.takeException(), isNull);
    await blur(tester);
  });
  for (final desktop in [false, true]) {
    final platform = desktop ? 'desktop' : 'mobile';
    formTest(
      '$platform stale undo cannot change a newer draft after changing tabs',
      (tester) async {
        await mount(tester, desktop, adding: true);
        await edit(tester, 'https://first.example.com');
        await blur(tester);
        final oldUndo =
            AppSnackBarManager().activeToasts.first.notification.onAction!;
        await edit(tester, 'https://second.example.com');
        await blur(tester);
        await tester.tap(find.text('Claude').first);
        await tester.pumpAndSettle();
        oldUndo();
        await tester.pumpAndSettle();
        await tester.tap(find.text('OpenAI').first);
        await tester.pumpAndSettle();
        expect(value(tester), 'https://second.example.com/v1');
      },
    );
    formTest(
      '$platform old tab undo cannot change a different created provider',
      (tester) async {
        final settings = await mount(tester, desktop, adding: true);
        await edit(tester, 'https://shared.example.com');
        await blur(tester);
        final oldUndo =
            AppSnackBarManager().activeToasts.first.notification.onAction!;
        await tester.tap(find.text('Claude').first);
        await tester.pumpAndSettle();
        await edit(tester, 'https://shared.example.com');
        await blur(tester);
        final add = find.text('Add', skipOffstage: true).last;
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        final id = settings.providersOrder.first;
        oldUndo();
        await tester.pumpAndSettle();
        expect(
          settings.getProviderConfig(id).providerType,
          ProviderKind.claude,
        );
        expect(
          settings.getProviderConfig(id).baseUrl,
          'https://shared.example.com/v1',
        );
        expect(settings.getProviderConfig(id).autoVersionDisabled, isFalse);
      },
    );

    formTest(
      '$platform empty and invalid stay visible without changing saved URL',
      (tester) async {
        final settings = await mount(tester, desktop);
        expect(
          settings.getProviderConfig('Relay').baseUrl,
          'https://saved.example.com',
        );
        await edit(tester, '');
        await blur(tester);
        expect(find.text('Required to send requests'), findsOneWidget);
        expect(
          tester.widget<TextField>(baseField).decoration!.hintText,
          startsWith('e.g. '),
        );
        expect(
          settings.getProviderConfig('Relay').baseUrl,
          'https://saved.example.com',
        );
        await settings.setProviderConfig(
          'Relay',
          settings.getProviderConfig('Relay').copyWith(apiKey: 'new-key'),
        );
        await tester.pumpAndSettle();
        expect(value(tester), '');
        await edit(tester, 'htps://bad.example.com');
        await blur(tester);
        expect(
          find.text('Invalid URL; must start with http:// or https://'),
          findsOneWidget,
        );
        expect(
          settings.getProviderConfig('Relay').baseUrl,
          'https://saved.example.com',
        );
        expect(tester.takeException(), isNull);
      },
    );
    formTest('$platform preview, normalization, undo and endpoint splitting', (
      tester,
    ) async {
      final settings = await mount(tester, desktop);
      await edit(tester, 'https://api.example.com');
      expect(
        find.textContaining(
          'https://api.example.com/v1/chat/completions',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No version in URL; /v1 will be added when you leave the field',
        ),
        findsOneWidget,
      );
      await blur(tester);
      expect(value(tester), 'https://api.example.com/v1');
      expect(settings.getProviderConfig('Relay').baseUrl, value(tester));
      final toast = AppSnackBarManager().activeToasts.first;
      expect(toast.notification.actionLabel, 'Undo');
      toast.notification.onAction!();
      await tester.pumpAndSettle();
      expect(value(tester), 'https://api.example.com');
      expect(settings.getProviderConfig('Relay').autoVersionDisabled, isTrue);
      await edit(tester, 'https://x.com/v2/chat/completions');
      await blur(tester);
      expect(value(tester), 'https://x.com/v2');
      expect(settings.getProviderConfig('Relay').chatPath, '/chat/completions');
      expect(
        find.text(
          'Full endpoint detected; /chat/completions moved to API Path',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    formTest(
      '$platform deleting the added version disables future completion',
      (tester) async {
        final settings = await mount(tester, desktop);
        await edit(tester, 'https://api.example.com');
        await blur(tester);
        await edit(tester, 'https://api.example.com');
        await blur(tester);
        expect(value(tester), 'https://api.example.com');
        expect(settings.getProviderConfig('Relay').autoVersionDisabled, isTrue);
      },
    );
    formTest('$platform built-in empty URL can be restored', (tester) async {
      final settings = await mount(tester, desktop, key: 'OpenAI');
      await edit(tester, '');
      await blur(tester);
      expect(find.byTooltip('Restore default'), findsOneWidget);
      await tester.tap(find.byTooltip('Restore default'));
      await tester.pumpAndSettle();
      expect(value(tester), 'https://api.openai.com/v1');
      expect(settings.getProviderConfig('OpenAI').baseUrl, value(tester));
      expect(find.text('Required to send requests'), findsNothing);
    });
    formTest(
      '$platform clear appears only while focused and API key uses eye',
      (tester) async {
        await mount(tester, desktop);
        expect(find.byTooltip('Clear'), findsNothing);
        await edit(tester, 'https://api.example.com/v3');
        expect(find.byTooltip('Clear'), findsOneWidget);
        await tester.tap(find.byTooltip('Clear'));
        await tester.pumpAndSettle();
        expect(value(tester), '');
        expect(find.byTooltip('Clear'), findsNothing);
        final keyRow = find.byWidgetPredicate(
          (w) => w is ProviderInputRow && w.trailing == TrailingKind.eye,
        );
        await tester.ensureVisible(keyRow);
        await tester.tap(
          find.descendant(of: keyRow, matching: find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        final key = tester.widget<TextField>(
          find.descendant(of: keyRow, matching: find.byType(TextField)),
        );
        expect(key.obscureText, isFalse);
        expect(key.style!.fontFamily, 'monospace');
      },
    );
    formTest('$platform add form rejects empty URL and saves normalized URL', (
      tester,
    ) async {
      final settings = await mount(tester, desktop, adding: true);
      final before = settings.providerConfigs.length;
      await edit(tester, '');
      await blur(tester);
      final add = find.text('Add', skipOffstage: true).last;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(settings.providerConfigs.length, before);
      expect(find.text('Required to send requests'), findsOneWidget);
      await edit(tester, 'https://relay.example.com/v3/chat/completions');
      await blur(tester);
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final created = settings.getProviderConfig(settings.providersOrder.first);
      expect(created.baseUrl, 'https://relay.example.com/v3');
      expect(created.chatPath, '/chat/completions');
    });

    formTest('$platform add completion can be undone after the dialog closes', (
      tester,
    ) async {
      final settings = await mount(tester, desktop, adding: true);
      await edit(tester, 'https://new.example.com');
      final add = find.text('Add', skipOffstage: true).last;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final id = settings.providersOrder.first;
      expect(
        settings.getProviderConfig(id).baseUrl,
        'https://new.example.com/v1',
      );
      AppSnackBarManager().activeToasts.first.notification.onAction!();
      await tester.pumpAndSettle();
      expect(settings.getProviderConfig(id).baseUrl, 'https://new.example.com');
      expect(settings.getProviderConfig(id).autoVersionDisabled, isTrue);
    });
    for (final kind in [ProviderKind.claude, ProviderKind.google]) {
      formTest(
        '$platform ${kind.name} hides API path and previews its endpoint',
        (tester) async {
          await mount(tester, desktop, kind: kind);
          await tester.ensureVisible(baseField);
          expect(
            find.byWidgetPredicate(
              (w) => w is ProviderInputRow && w.label == 'API Path',
            ),
            findsNothing,
          );
          final suffix = kind == ProviderKind.claude
              ? '/messages'
              : '/models/{模型}:streamGenerateContent';
          expect(
            find.textContaining(
              'https://saved.example.com$suffix',
              findRichText: true,
            ),
            findsOneWidget,
          );
        },
      );
    }
    formTest('$platform Responses hides API path and previews responses', (
      tester,
    ) async {
      await mount(tester, desktop, responses: true);
      await tester.ensureVisible(baseField);
      expect(
        find.byWidgetPredicate(
          (w) => w is ProviderInputRow && w.label == 'API Path',
        ),
        findsNothing,
      );
      expect(
        find.textContaining(
          'https://saved.example.com/responses',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  }
}
