import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/avatar_config.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../support/business_test_harness.dart';
import 'package:Kelivo/desktop/setting/search_services_pane.dart';
import 'package:Kelivo/features/search/widgets/search_service_avatar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('360px search dialog edits and saves credentials', (
    tester,
  ) async {
    DesktopSearchServiceEdit? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          DeepSeekOptions(id: 'narrow', apiKey: 'old'),
        );
      },
    );
    tester.view.physicalSize = const Size(360, 640);
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'compact-key');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((updated!.service as DeepSeekOptions).apiKey, 'compact-key');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desktop adds DeepSeek from its provider picker', (tester) async {
    SearchServiceOptions? created;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        created = await showDesktopAddSearchServiceDialog(context);
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _selectServiceType(tester, 'DeepSeek');
    expect(find.byType(BottomSheet), findsNothing);
    await tester.enterText(find.byType(TextField), 'deepseek-key');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(created, isA<DeepSeekOptions>());
    expect((created! as DeepSeekOptions).apiKey, 'deepseek-key');
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('desktop edits DeepSeek without losing extra keys', (
    tester,
  ) async {
    DesktopSearchServiceEdit? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          DeepSeekOptions(
            id: 'deepseek',
            apiKey: 'old-key',
            extraApiKeys: const ['extra-key'],
          ),
          initialAvatar: const AvatarConfig(
            type: AvatarType.emoji,
            value: '🔎',
          ),
        );
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('old-key'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.enterText(find.byType(TextField), 'new-key');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = updated!.service as DeepSeekOptions;
    expect(
      updated?.avatar,
      const AvatarConfig(type: AvatarType.emoji, value: '🔎'),
    );
    expect(saved.id, 'deepseek');
    expect(saved.apiKey, 'new-key');
    expect(saved.extraApiKeys, ['extra-key']);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('desktop icon picker resets an existing custom icon', (
    tester,
  ) async {
    DesktopSearchServiceEdit? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          const BingLocalOptions(id: 'bing'),
          initialAvatar: const AvatarConfig(
            type: AvatarType.emoji,
            value: '🔎',
          ),
        );
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change icon'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(updated?.service.id, 'bing');
    expect(updated?.avatar, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desktop editor stays open until a selected icon is imported', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('search-icon-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/chosen.svg')
      ..writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2 2">'
        '<rect width="2" height="2"/></svg>',
      );
    DesktopSearchServiceEdit? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          DeepSeekOptions(id: 'deepseek', apiKey: 'existing'),
        );
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final previousPaths = PathProviderPlatform.instance;
    final paths = _ImportPaths();
    PathProviderPlatform.instance = paths;
    addTearDown(() => PathProviderPlatform.instance = previousPaths);
    tester
        .widget<SearchServiceAvatarButton>(
          find.byType(SearchServiceAvatarButton),
        )
        .onChanged(AvatarConfig(type: AvatarType.file, value: source.path));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    final multiKey = find.text('Multi-key rotation');
    expect(multiKey, findsOneWidget);
    await tester.tapAt(tester.getCenter(multiKey));
    await tester.pumpAndSettle();
    expect(multiKey, findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(updated, isNull);

    paths.support.complete(directory.path);
    for (var attempt = 0; attempt < 100 && updated == null; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(updated?.avatar?.value, startsWith('kelivo-file:///avatars/'));
    expect(updated?.avatar?.value, endsWith('.svg'));
    expect((updated?.service as DeepSeekOptions?)?.apiKey, 'existing');
    expect(find.text('Save'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desktop changes page reader through a dropdown', (tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setSearchServices([
      const BingLocalOptions(id: 'bing'),
      TavilyOptions(id: 'tavily', apiKey: 'key'),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DesktopSearchServicesPane()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = find.byKey(const ValueKey('desktop-web-fetch-mode'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Tavily').last);
    await tester.pumpAndSettle();
    expect(settings.webFetchMode, 'tavily');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('desktop adds keyless Exa MCP with its default endpoint', (
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
    await _selectServiceType(tester, 'Exa MCP');
    expect(find.text('API Key (optional)'), findsOneWidget);
    expect(find.text(ExaMcpOptions.defaultUrl), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final saved = created! as ExaMcpOptions;
    expect(saved.apiKey, isEmpty);
    expect(saved.resolvedUrl, ExaMcpOptions.defaultUrl);
  });

  testWidgets('desktop edits Exa MCP without losing extra keys', (
    tester,
  ) async {
    DesktopSearchServiceEdit? updated;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        updated = await showDesktopEditSearchServiceDialog(
          context,
          ExaMcpOptions(
            id: 'mcp',
            apiKey: 'key',
            extraApiKeys: const ['extra'],
          ),
        );
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final urlField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == ExaMcpOptions.defaultUrl,
    );
    await tester.enterText(urlField, ' https://example.com/mcp ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = updated!.service as ExaMcpOptions;
    expect(saved.id, 'mcp');
    expect(saved.apiKey, 'key');
    expect(saved.extraApiKeys, ['extra']);
    expect(saved.url, 'https://example.com/mcp');
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

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
    DesktopSearchServiceEdit? updated;
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

    expect(updated?.service, isA<KagiOptions>());
    final saved = updated!.service as KagiOptions;
    expect(saved.id, 'kagi');
    expect(saved.apiKey, 'new-key');
    expect(saved.extraApiKeys, ['backup-key']);
  });
  testWidgets('desktop add dialog saves Kimi with the selected mode', (
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
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('desktop edit dialog preserves Kimi keys and changes mode', (
    tester,
  ) async {
    DesktopSearchServiceEdit? updated;
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

    final saved = updated!.service as KimiOptions;
    expect(saved.id, 'kimi');
    expect(saved.apiKey, 'kimi-key');
    expect(saved.mode, 'pro');
    expect(saved.extraApiKeys, ['extra-key']);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('desktop adds 4get and scopes its masked pass to the instance', (
    tester,
  ) async {
    SearchServiceOptions? configured;
    await _pumpDialogHost(
      tester,
      onOpen: (context) async {
        final existing = configured;
        if (existing == null) {
          configured = await showDesktopAddSearchServiceDialog(context);
        } else {
          configured = (await showDesktopEditSearchServiceDialog(
            context,
            existing,
          ))?.service;
        }
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _selectServiceType(tester, '4get');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'https://search.example/4get');
    await tester.enterText(fields.at(1), 'brave');
    await tester.enterText(fields.at(2), 'old-pass');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final created = configured! as FourGetOptions;
    expect(created.passToken, 'old-pass');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isTrue);
    await tester.enterText(fields.at(0), 'https://search.example/search');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, 'old-pass');
    await tester.enterText(fields.at(2), 'updated-pass');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = configured! as FourGetOptions;
    expect(saved.id, created.id);
    expect(saved.url, 'https://search.example/search');
    expect(saved.scraper, 'brave');
    expect(saved.passToken, 'updated-pass');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(0), 'https://other.example/4get');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final moved = configured! as FourGetOptions;
    expect(moved.url, 'https://other.example/4get');
    expect(moved.passToken, isEmpty);
  });

  testWidgets('desktop edit dialog saves You.com content mode', (tester) async {
    DesktopSearchServiceEdit? updated;
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

    expect(updated?.service, isA<YouSearchOptions>());
    expect(
      (updated!.service as YouSearchOptions).contentMode,
      YouSearchOptions.snippetsMode,
    );
  });

  testWidgets(
    'desktop edit dialog keeps an existing token value when input is invalid',
    (tester) async {
      DesktopSearchServiceEdit? updated;
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

class _ImportPaths extends PathProviderPlatform {
  final support = Completer<String>();

  @override
  Future<String?> getApplicationSupportPath() => support.future;
}

Future<void> _pumpDialogHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onOpen,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final settings = SettingsProvider(createBusinessTestPreferences());
  addTearDown(settings.dispose);
  await settings.loaded;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
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
