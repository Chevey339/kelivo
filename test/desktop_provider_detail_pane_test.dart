import 'dart:convert';
import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import "support/business_test_harness.dart";
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/widgets/desktop_form_dialog.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/provider/widgets/provider_custom_request_editor.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/model_tag_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ProviderConfig _providerConfig(String id) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: 'test-key',
    baseUrl: 'https://example.test/v1',
    providerType: ProviderKind.openai,
    chatPath: '/chat/completions',
    models: const ['same-model'],
    proxyEnabled: true,
    proxyType: 'http',
    proxyHost: '127.0.0.1',
    proxyPort: '',
    proxyUsername: '',
    proxyPassword: '',
  );
}

Widget _harness(
  SettingsProvider settings, {
  required String initialProviderKey,
  TextScaler textScaler = TextScaler.noScaling,
  Widget? body,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<AssistantProvider>(
        create: (_) =>
            AssistantProvider(preferences: createBusinessTestPreferences()),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body:
            body ?? DesktopSettingsPage(initialProviderKey: initialProviderKey),
      ),
    ),
  );
}

Future<SettingsProvider> _buildSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(const {});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.runAsync(_waitForSettingsLoad);
  await settings.setProviderConfig('ProviderA', _providerConfig('ProviderA'));
  await settings.setProviderConfig('ProviderB', _providerConfig('ProviderB'));
  await settings.setProvidersOrder(const ['ProviderA', 'ProviderB']);
  return settings;
}

Future<void> _pumpProviderSettings(
  WidgetTester tester,
  SettingsProvider settings, {
  String initialProviderKey = 'ProviderA',
  double width = 1400,
  TextScaler textScaler = TextScaler.noScaling,
  Widget? body,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _harness(
      settings,
      initialProviderKey: initialProviderKey,
      textScaler: textScaler,
      body: body,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'global balance defaults are reachable by keyboard from the provider list',
    (tester) async {
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);
      await _pumpProviderSettings(tester, settings, width: 360);
      await tester.tap(find.byKey(const ValueKey('desktop-pane-back')).last);
      await tester.pumpAndSettle();

      Future<void> focus(Finder control) async {
        final node = Focus.of(tester.element(control));
        for (var i = 0; i < 64 && !node.hasPrimaryFocus; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(node.hasPrimaryFocus, isTrue, reason: control.toString());
      }

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      await focus(find.text('ProviderB'));
      await press(LogicalKeyboardKey.enter);
      await focus(
        find.descendant(
          of: find.byKey(const ValueKey('desktop-provider-settings-ProviderB')),
          matching: find.byType(Icon),
        ),
      );
      await press(LogicalKeyboardKey.enter);
      await focus(find.text('This provider'));
      await press(LogicalKeyboardKey.enter);
      await press(LogicalKeyboardKey.arrowDown);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Global defaults'))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await press(LogicalKeyboardKey.space);
      await focus(find.text('Off'));
      await press(LogicalKeyboardKey.enter);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.enter);
      await focus(find.text('Refresh after replies'));
      expect(settings.balanceRefreshOnReply, isTrue);
      await press(LogicalKeyboardKey.space);
      expect(settings.balanceRefreshInterval, 5);
      expect(settings.balanceRefreshOnReply, isFalse);
      final config = settings.getProviderConfig('ProviderB');
      expect(config.balanceRefreshInterval, isNull);
      expect(config.balanceRefreshOnReply, isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'first desktop refresh override preserves a preset display name',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('zh')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);
      await _pumpProviderSettings(
        tester,
        settings,
        initialProviderKey: 'Aliyun',
        textScaler: const TextScaler.linear(2),
      );
      final detail = find.byType(DesktopProviderDetailPane);
      final l10n = AppLocalizations.of(tester.element(detail))!;
      expect(l10n.providersPageAliyunName, '阿里云千问');
      expect(
        tester.widget<DesktopProviderDetailPane>(detail).displayName,
        l10n.providersPageAliyunName,
      );
      expect(settings.providerConfigs.containsKey('Aliyun'), isFalse);

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byKey(const ValueKey('desktop-provider-settings-Aliyun')));
      final inheritedReply = find.text(
        l10n.providerBalanceFollowDefault(l10n.providerBalanceRefreshOn),
      );
      expect(
        tester.renderObject<RenderParagraph>(inheritedReply).didExceedMaxLines,
        isFalse,
      );
      await tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is DesktopSelectDropdown &&
              widget.semanticLabel == l10n.providerBalanceInterval,
        ),
      );
      await tap(find.text(l10n.providerBalanceRefreshMinutes(5)));
      final config = settings.providerConfigs['Aliyun']!;
      expect(config.name, l10n.providersPageAliyunName);
      expect(config.balanceRefreshInterval, 5);
      expect(config.balanceEnabled, isNot(true));
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    '360px settings navigates provider list and preserves edits on resize',
    (tester) async {
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);
      await _pumpProviderSettings(tester, settings);
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopProviderDetailPane), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('search-icon')));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('search-field'));
      await tester.enterText(search, 'same');
      final state = tester.state(find.byType(DesktopProviderDetailPane));
      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(DesktopProviderDetailPane)), same(state));
      expect(tester.widget<TextField>(search).controller!.text, 'same');
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('desktop-pane-back')).last);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopProviderDetailPane), findsNothing);
      expect(find.text('Automatic balance refresh'), findsNothing);
      expect(find.text('Timed refresh'), findsNothing);
      await tester.tap(find.text('ProviderB').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DesktopProviderDetailPane>(
              find.byType(DesktopProviderDetailPane),
            )
            .providerKey,
        'ProviderB',
      );
      await tester.tap(find.byKey(const ValueKey('desktop-pane-back')).first);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopProviderDetailPane), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop conversation cache key switch saves and restores', (
    tester,
  ) async {
    final settings = await _buildSettings(tester);
    addTearDown(settings.dispose);
    await _pumpProviderSettings(tester, settings);
    final settingsButton = find.byKey(
      const ValueKey('desktop-provider-settings-ProviderA'),
    );
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();
    final cacheSwitch = find.byWidgetPredicate(
      (widget) =>
          widget is IosSwitch &&
          widget.semanticLabel == 'Send Conversation Cache Key',
    );
    expect(cacheSwitch, findsOneWidget);
    expect(tester.widget<IosSwitch>(cacheSwitch).value, isFalse);
    await tester.ensureVisible(cacheSwitch);
    await tester.tap(cacheSwitch);
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('ProviderA').promptCacheKeyEnabled,
      isTrue,
    );
    Navigator.of(tester.element(cacheSwitch)).pop();
    await tester.pumpAndSettle();
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();
    expect(tester.widget<IosSwitch>(cacheSwitch).value, isTrue);
    await tester.ensureVisible(cacheSwitch);
    await tester.tap(cacheSwitch);
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('ProviderA').promptCacheKeyEnabled,
      isFalse,
    );
    await settings.setProviderConfig(
      'ProviderA',
      settings
          .getProviderConfig('ProviderA')
          .copyWith(providerType: ProviderKind.claude),
    );
    await tester.pumpAndSettle();
    expect(cacheSwitch, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop model selection state is cleared when provider changes',
    (tester) async {
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);

      await _pumpProviderSettings(tester, settings);

      await tester.tap(find.byTooltip('Multi-select').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('same-model').last);
      await tester.pump(const Duration(milliseconds: 300));

      final selectedCheckbox = tester.widget<IosCheckbox>(
        find.byType(IosCheckbox).last,
      );
      expect(selectedCheckbox.value, isTrue);

      await tester.tap(find.text('ProviderB').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(IosCheckbox), findsNothing);
    },
  );

  testWidgets(
    'desktop saves a cross-group drop even when the sort dialog closes immediately',
    (tester) async {
      final storage = (await tester.runAsync(createBusinessTestHarness))!;
      final models = [
        'zeta/regular',
        'alpha/vision',
        'beta/fast',
        for (var i = 0; i < 697; i++) 'bulk/model-$i',
      ];
      const disabledModel = 'alpha/vision';
      final settings = (await tester.runAsync(() async {
        final settings = SettingsProvider(storage.preferences);
        await settings.loaded;
        await settings.setProviderConfig(
          'ProviderA',
          _providerConfig(
            'ProviderA',
          ).copyWith(models: models, disabledModels: const {disabledModel}),
        );
        await settings.setProvidersOrder(const ['ProviderA']);
        return settings;
      }))!;
      addTearDown(settings.dispose);
      await _pumpProviderSettings(tester, settings);

      final reorderButton = find.byTooltip('Reorder models');
      await tester.ensureVisible(reorderButton);
      await tester.tap(reorderButton);
      await tester.pumpAndSettle();

      final dialog = find.byType(DesktopFormDialog);
      final handles = find.descendant(
        of: dialog,
        matching: find.byType(ReorderableDragStartListener),
      );
      expect(handles.evaluate().length, lessThan(models.length));
      final first = tester.getCenter(handles.at(0));
      final destination = tester.getCenter(handles.at(2)) + const Offset(0, 18);
      final mouse = await tester.startGesture(
        first,
        kind: PointerDeviceKind.mouse,
      );
      for (var step = 1; step <= 12; step++) {
        await mouse.moveTo(Offset.lerp(first, destination, step / 12)!);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 300));
      final expected = [models[1], models[2], models[0], ...models.skip(3)];
      final saved = await tester.runAsync(() async {
        await mouse.up();
        await tester.pump();
        await tester.tap(
          find.descendant(of: dialog, matching: find.byTooltip('Close')),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
        await storage.preferences.flushPendingWrites();
        final providers = await storage.repository.readEntities(
          BusinessEntityKind.provider,
        );
        final row = providers.singleWhere((row) => row.id == 'ProviderA');
        return ProviderConfig.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        );
      });
      expect(settings.getProviderConfig('ProviderA').models, expected);
      expect(saved!.models, expected);
      expect(saved.disabledModels, {disabledModel});

      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop model reorder is unavailable during filtering or selection',
    (tester) async {
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);
      await settings.setProviderConfig(
        'ProviderA',
        _providerConfig(
          'ProviderA',
        ).copyWith(models: ['alpha-one', 'beta-two']),
      );
      await _pumpProviderSettings(tester, settings);

      final reorderButton = find.byTooltip('Reorder models');
      expect(reorderButton, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('search-icon')));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('search-field'));
      await tester.enterText(search, 'alpha');
      await tester.pumpAndSettle();
      expect(reorderButton, findsNothing);

      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(reorderButton, findsOneWidget);
      await tester.tap(find.byTooltip('Multi-select').first);
      await tester.pumpAndSettle();
      expect(reorderButton, findsNothing);
    },
  );

  testWidgets('provider pane can switch between OAuth and API settings', (
    tester,
  ) async {
    final settings = await _buildSettings(tester);
    addTearDown(settings.dispose);
    await settings.setProviderConfig(
      'Account',
      _providerConfig('Account').copyWith(oauthProvider: OAuthProvider.chatgpt),
    );
    await settings.setProvidersOrder(const [
      'ProviderA',
      'Account',
      'ProviderB',
    ]);
    await _pumpProviderSettings(tester, settings);
    await tester.tap(find.text('Account').first);
    await tester.pumpAndSettle();
    expect(find.text('API Key'), findsNothing);
    final accountSettings = find.byKey(
      const ValueKey('desktop-provider-settings-Account'),
    );
    expect(accountSettings, findsOneWidget);
    await tester.tap(accountSettings);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-provider-settings-dialog')),
      findsOneWidget,
    );
    expect(find.text(OAuthProvider.chatgpt.baseUrl), findsOneWidget);
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('desktop-provider-settings-dialog')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ProviderB').first);
    await tester.pumpAndSettle();
    expect(find.text('API Key'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('desktop-provider-settings-ProviderB')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-provider-settings-dialog')),
      findsOneWidget,
    );
    expect(find.text(OAuthProvider.chatgpt.baseUrl), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop provider proxy port input preserves typed order', (
    tester,
  ) async {
    final settings = await _buildSettings(tester);
    addTearDown(settings.dispose);

    await _pumpProviderSettings(tester, settings);

    await tester.tap(
      find.byKey(const ValueKey('desktop-provider-settings-ProviderA')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('desktop-provider-settings-dialog')),
      findsOneWidget,
    );

    final portField = find.byKey(
      const ValueKey('desktop-provider-proxy-port-field'),
    );
    await tester.ensureVisible(portField);
    await tester.pumpAndSettle();
    await tester.tap(portField);
    await tester.pump();
    await tester.enterText(portField, '1');
    await tester.pump();

    var fieldWidget = tester.widget<TextField>(portField);
    expect(fieldWidget.controller?.selection.baseOffset, 1);

    await tester.enterText(portField, '12345');
    await tester.pump(const Duration(milliseconds: 300));

    expect(settings.getProviderConfig('ProviderA').proxyPort, '12345');

    fieldWidget = tester.widget<TextField>(portField);
    expect(fieldWidget.controller?.text, '12345');
  });

  testWidgets('desktop LobeHub icon dialog uses provider settings flow', (
    tester,
  ) async {
    final settings = await _buildSettings(tester);
    addTearDown(settings.dispose);

    await _pumpProviderSettings(tester, settings);

    await tester.tap(
      find.byKey(const ValueKey('desktop-provider-settings-ProviderA')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('desktop-provider-settings-dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('desktop-provider-settings-avatar-ProviderA')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter LobeHub Icon'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('desktop-provider-lobehub-icon-dialog')),
      findsOneWidget,
    );

    final iconField = find.byKey(
      const ValueKey('desktop-provider-lobehub-icon-field'),
    );
    await tester.enterText(iconField, 'openai');
    await tester.pump();
    await tester.tap(find.text('Monochrome'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final cfg = settings.getProviderConfig('ProviderA');
    expect(cfg.avatarType, 'lobehub');
    expect(cfg.avatarValue, 'openai');
    expect(cfg.avatarMonochrome, isTrue);
  });

  testWidgets('desktop provider settings persist custom request rows', (
    tester,
  ) async {
    final settings = await _buildSettings(tester);
    addTearDown(settings.dispose);

    await _pumpProviderSettings(tester, settings);
    await tester.tap(
      find.byKey(const ValueKey('desktop-provider-settings-ProviderA')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final customRequestEditor = tester.widget<ProviderCustomRequestEditor>(
      find.byKey(const ValueKey('desktop-provider-custom-request-ProviderA')),
    );
    expect(
      customRequestEditor.key,
      const ValueKey('desktop-provider-custom-request-ProviderA'),
    );

    final addBody = find.byKey(const ValueKey('provider-custom-body-add'));
    await tester.ensureVisible(addBody);
    await tester.pumpAndSettle();
    await tester.tap(addBody);
    await tester.pump();

    expect(settings.getProviderConfig('ProviderA').customBody, hasLength(1));
    await tester.enterText(
      find.byKey(const ValueKey('provider-custom-body-name-0')),
      'desktop',
    );
    await tester.enterText(
      find.byKey(const ValueKey('provider-custom-body-value-0')),
      'true',
    );
    await tester.pump();

    expect(settings.getProviderConfig('ProviderA').customBody, [
      {'key': 'desktop', 'value': 'true'},
    ]);
  });

  for (final (width, textScale, oauth) in const [
    (1400.0, 1.0, false),
    (360.0, 1.0, false),
    (1400.0, 2.0, false),
    (760.0, 1.0, true),
    (360.0, 1.0, true),
  ]) {
    testWidgets(
      'desktop provider model rows retain full names and working actions '
      '(width=$width, textScale=$textScale, oauth=$oauth)',
      (tester) async {
        final settings = await _buildSettings(tester);
        addTearDown(settings.dispose);
        const modelId = 'long-model';
        const name =
            'vendor/long-context-multimodal-reasoning-extended-thinking-'
            'instruct-preview-128k-2026-11-04-experimental';
        await settings.setProviderConfig(
          'ProviderA',
          _providerConfig('ProviderA').copyWith(
            oauthProvider: oauth ? OAuthProvider.chatgpt : null,
            models: const [modelId],
            modelOverrides: const {
              modelId: {
                'name': name,
                'input': ['text', 'image', 'audio', 'video', 'pdf'],
                'output': ['text', 'image'],
                'abilities': ['tool', 'reasoning'],
                'contextWindow': 1000000,
              },
            },
          ),
        );
        await _pumpProviderSettings(
          tester,
          settings,
          width: width,
          textScaler: TextScaler.linear(textScale),
          body: oauth
              ? const DesktopProviderDetailPane(
                  providerKey: 'ProviderA',
                  displayName: 'ProviderA',
                )
              : null,
        );
        await tester.pumpAndSettle();

        void expectFullName() {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(name),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
        }

        expectFullName();
        final capabilities = find.byType(ModelCapsulesRow);
        expect(capabilities, findsOneWidget);
        expect(
          find.descendant(of: capabilities, matching: find.byType(Tooltip)),
          findsNWidgets(8),
        );
        expect(find.text('1M'), findsOneWidget);

        final edit = find.byKey(
          const ValueKey('desktop-provider-model-settings-$modelId'),
        );
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        final dialog = find.byKey(const ValueKey('model-spec-edit-dialog'));
        expect(dialog, findsOneWidget);
        Navigator.of(tester.element(dialog)).pop();
        await tester.pumpAndSettle();

        if (oauth) {
          final toggle = find.byKey(
            const ValueKey('oauth-model-enabled-$modelId'),
          );
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            settings.getProviderConfig('ProviderA').isModelEnabled(modelId),
            isFalse,
          );
          expect(
            settings.getProviderConfig('ProviderA').models,
            contains(modelId),
          );
          expectFullName();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            settings.getProviderConfig('ProviderA').isModelEnabled(modelId),
            isTrue,
          );
        } else {
          final multiSelect = find.byTooltip('Multi-select').first;
          await tester.ensureVisible(multiSelect);
          await tester.tap(multiSelect);
          await tester.pumpAndSettle();
          expectFullName();
          expect(capabilities, findsNothing);
          await tester.ensureVisible(find.text(name));
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
          expect(
            tester.widget<IosCheckbox>(find.byType(IosCheckbox).last).value,
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'desktop provider model rows pin action icons to a shared right edge',
    (tester) async {
      final settings = await _buildSettings(tester);
      addTearDown(settings.dispose);
      await settings.setProviderConfig(
        'ProviderA',
        _providerConfig('ProviderA').copyWith(
          models: const ['wide-ctx', 'narrow-ctx'],
          modelOverrides: const {
            'wide-ctx': {
              'name': 'Wide Context',
              'type': 'chat',
              'input': ['text', 'image'],
              'abilities': ['tool'],
              'contextWindow': 1000000,
            },
            'narrow-ctx': {
              'name': 'Narrow Context',
              'type': 'chat',
              'input': ['text', 'image'],
              'abilities': ['tool'],
              'contextWindow': 262144,
            },
          },
        ),
      );
      await _pumpProviderSettings(tester, settings);

      expect(find.text('1M'), findsOneWidget);
      expect(find.text('262.1k'), findsOneWidget);

      final wideSettings = tester.getRect(
        find.byKey(const ValueKey('desktop-provider-model-settings-wide-ctx')),
      );
      final narrowSettings = tester.getRect(
        find.byKey(
          const ValueKey('desktop-provider-model-settings-narrow-ctx'),
        ),
      );
      final wideRemove = tester.getRect(
        find.byKey(const ValueKey('desktop-provider-model-remove-wide-ctx')),
      );
      final narrowRemove = tester.getRect(
        find.byKey(const ValueKey('desktop-provider-model-remove-narrow-ctx')),
      );

      expect(wideSettings.right, closeTo(narrowSettings.right, 0.5));
      expect(wideRemove.right, closeTo(narrowRemove.right, 0.5));
    },
  );
}
