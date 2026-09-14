import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/provider/pages/oauth_provider_detail_page.dart';
import 'package:Kelivo/features/provider/widgets/add_provider_sheet.dart';
import 'package:Kelivo/features/provider/widgets/oauth_account_card.dart';
import 'package:Kelivo/features/provider/widgets/oauth_message_recovery.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  setUp(() async {
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setProviderConfig(
      'oauth-test',
      ProviderConfig(
        id: 'oauth-test',
        name: 'ChatGPT',
        enabled: true,
        apiKey: '',
        baseUrl: OAuthProvider.chatgpt.baseUrl,
        oauthProvider: OAuthProvider.chatgpt,
        providerType: ProviderKind.openai,
      ),
    );
  });
  tearDown(() => settings.dispose());

  Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme:
              (brightness == Brightness.dark
                      ? buildDarkTheme(null)
                      : buildLightTheme(null))
                  .copyWith(
                    textTheme:
                        (brightness == Brightness.dark
                                ? buildDarkTheme(null)
                                : buildLightTheme(null))
                            .textTheme
                            .apply(fontFamily: 'OAuth QA'),
                  ),
          home: Scaffold(body: child),
        ),
      );

  Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
    const directory = String.fromEnvironment('OAUTH_QA_DIR');
    if (directory.isEmpty) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'account usage renders on narrow screens in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const directory = String.fromEnvironment('OAUTH_QA_DIR');
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
              ..addFont(
                rootBundle.load(
                  'packages/lucide_icons_flutter/assets/lucide.ttf',
                ),
              );
            await icons.load();
            final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
            if (await font.exists()) {
              final loader = FontLoader('OAuth QA')
                ..addFont(
                  font.readAsBytes().then((data) => ByteData.sublistView(data)),
                );
              await loader.load();
            }
          });
        }
        final key = GlobalKey();
        var expanded = false;
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) => OAuthAccountCard(
                    avatar: const Icon(LucideIcons.bot, size: 40),
                    name: 'ChatGPT',
                    email: 'a.long.account.name@example.com',
                    plan: 'ChatGPT Plus',
                    usage: ProviderUsageSnapshot(
                      fetchedAt: DateTime(2026, 9, 13, 12),
                      allowed: true,
                      limitReached: false,
                      resetCredits: 2,
                      windows: [
                        ProviderUsageWindow(
                          id: 'primary',
                          duration: const Duration(hours: 5),
                          usedPercent: 62,
                          resetsAt: DateTime(2026, 9, 14, 5),
                        ),
                        const ProviderUsageWindow(
                          id: 'secondary',
                          duration: Duration(days: 7),
                        ),
                      ],
                    ),
                    showDetails: expanded,
                    onRefresh: () {},
                    onDetails: () => setState(() => expanded = !expanded),
                  ),
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('62%'), findsOneWidget);
        expect(find.text('Available usage resets: 2'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        await tester.tap(find.text('Usage details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Resets'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapshot(tester, key, 'oauth-account-${brightness.name}');
      },
    );
  }

  testWidgets(
    'Kimi quota failure keeps the account connected and displays the server reason',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cfg = settings.providerConfigs['oauth-test']!.copyWith(
        name: 'Kimi Code',
        oauthProvider: OAuthProvider.kimi,
        oauthCredentials: ProviderOAuthCredentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          sessionId: 'session',
        ),
      );
      await tester.runAsync(() => settings.setProviderConfig(cfg.id, cfg));
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'code': 'resource_exhausted',
              'message': 'insufficient balance',
              'details': [
                {
                  'debug': {
                    'reason': 'REASON_QUOTA_EXCEEDED',
                    'localizedMessage': {'message': 'Credits used up.'},
                  },
                },
              ],
            }),
            429,
          );
        }),
      )..bind(settings);
      await tester.pumpWidget(
        app(OAuthProviderDetailPage(providerId: cfg.id, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.textContaining('This account has no available quota.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('HTTP 429 / resource_exhausted'),
        findsOneWidget,
      );
      expect(find.textContaining('insufficient balance'), findsOneWidget);
      expect(find.textContaining('Check your network'), findsNothing);
      expect(calls, 1);
      expect(
        settings.providerConfigs[cfg.id]!.oauthCredentials!.requiresLogin,
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account login is the fourth add tab and has only the three implemented providers',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: app(
            Builder(
              builder: (context) => Center(
                child: IosTileButton(
                  label: 'Add',
                  icon: LucideIcons.plus,
                  onTap: () => showAddProviderSheet(context),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('OpenAI'), findsWidgets);
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      expect(find.text('ChatGPT'), findsOneWidget);
      expect(find.text('Grok'), findsOneWidget);
      expect(find.text('Kimi Code'), findsNWidgets(2));
      expect(find.text('Log in'), findsNWidgets(3));
      expect(find.text('API Key'), findsNothing);
      expect(tester.takeException(), isNull);
      await snapshot(tester, key, 'oauth-add-accounts');
    },
  );

  testWidgets(
    'OAuth detail is separate from API key forms and reveals a copyable endpoint',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => IosTileButton(
              label: 'Open',
              icon: LucideIcons.user,
              onTap: () => showOAuthProviderDetails(context, 'oauth-test'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('API Key'), findsNothing);
      expect(find.text('Log in'), findsNothing);
      expect(find.text('Log in again'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Connection details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Connection details'));
      await tester.pumpAndSettle();
      expect(find.text(OAuthProvider.chatgpt.baseUrl), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(LucideIcons.pencil));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'My account');
      await tester.pumpAndSettle();
      expect(settings.providerConfigs['oauth-test']!.name, 'My account');
      expect(tester.takeException(), isNull);
    },
  );

  for (final desktop in [false, true]) {
    testWidgets('connected account detail layout desktop=$desktop', (
      tester,
    ) async {
      tester.view.physicalSize = desktop
          ? const Size(800, 760)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cfg = settings.providerConfigs['oauth-test']!.copyWith(
        models: ['gpt-5.4', 'gpt-5.4-mini'],
        oauthCredentials: ProviderOAuthCredentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          sessionId: 'session',
          accountId: 'workspace',
          email: 'account@example.com',
          plan: 'Plus',
        ),
      );
      await tester.runAsync(() => settings.setProviderConfig(cfg.id, cfg));
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'rate_limit': {
                'primary_window': {
                  'used_percent': 62,
                  'limit_window_seconds': 18000,
                },
                'secondary_window': {
                  'used_percent': 41,
                  'limit_window_seconds': 604800,
                },
              },
            }),
            200,
          ),
        ),
      )..bind(settings);
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: key,
            child: OAuthProviderDetailPage(
              providerId: cfg.id,
              embedded: desktop,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('account@example.com'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('API Key'), findsNothing);
      expect(tester.takeException(), isNull);
      await snapshot(
        tester,
        key,
        desktop ? 'oauth-desktop-detail' : 'oauth-mobile-detail',
      );
    });
  }

  Future<void> openModelEditor(
    WidgetTester tester, {
    required bool desktop,
    required Map<String, dynamic> metadata,
  }) async {
    tester.view.physicalSize = desktop
        ? const Size(1280, 900)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = settings.providerConfigs['oauth-test']!.copyWith(
      name: 'Kimi Code',
      baseUrl: OAuthProvider.kimi.baseUrl,
      oauthProvider: OAuthProvider.kimi,
      models: ['kimi-test-alias'],
      modelOverrides: {
        'kimi-test-alias': {
          'apiModelId': 'k3',
          'name': 'Synced Kimi',
          'type': 'chat',
          'input': ['text'],
          'output': ['text'],
          'abilities': ['tool', 'reasoning'],
          'builtInTools': ['image_generation'],
          ...metadata,
        },
      },
    );
    await tester.runAsync(() => settings.setProviderConfig(config.id, config));
    await tester.pumpWidget(
      app(OAuthProviderDetailPage(providerId: config.id, embedded: desktop)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Synced Kimi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Synced Kimi'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.byType(BottomSheet), desktop ? findsNothing : findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  const anthropicMetadata = <String, dynamic>{
    'oauthProtocol': 'anthropic',
    'oauthThinkingMode': 'enabled',
    'oauthThinkingRequired': true,
    'oauthThinkingEfforts': <String>[],
    'oauthThinkingDefaultEffort': null,
  };
  const openaiMetadata = <String, dynamic>{
    'oauthProtocol': 'openai',
    'oauthThinkingMode': 'adaptive',
    'oauthThinkingRequired': false,
    'oauthThinkingEfforts': ['low', 'high'],
    'oauthThinkingDefaultEffort': 'high',
  };

  void expectMetadata(Map saved, Map<String, dynamic> metadata) {
    for (final entry in metadata.entries) {
      expect(saved, containsPair(entry.key, entry.value));
    }
  }

  for (final desktop in [false, true]) {
    for (final metadata in [anthropicMetadata, openaiMetadata]) {
      testWidgets(
        'model Confirm preserves ${metadata['oauthProtocol']} OAuth metadata desktop=$desktop',
        (tester) async {
          await openModelEditor(tester, desktop: desktop, metadata: metadata);
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();

          final config = settings.providerConfigs['oauth-test']!;
          final saved = config.modelOverrides['kimi-test-alias'] as Map;
          expectMetadata(saved, metadata);
          expect(config.models, ['kimi-test-alias']);
          expect(saved['apiModelId'], 'k3');
          expect(saved['name'], 'Synced Kimi');
          expect(saved['abilities'], unorderedEquals(['tool', 'reasoning']));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'model edits preserve metadata refreshed while the editor is open desktop=$desktop',
      (tester) async {
        await openModelEditor(
          tester,
          desktop: desktop,
          metadata: anthropicMetadata,
        );
        await tester.enterText(find.byType(TextField).at(1), 'My Kimi');
        final current = settings.providerConfigs['oauth-test']!;
        await tester.runAsync(
          () => settings.setProviderConfig(
            current.id,
            current.copyWith(
              modelOverrides: {
                ...current.modelOverrides,
                'kimi-test-alias': {
                  ...(current.modelOverrides['kimi-test-alias'] as Map),
                  ...openaiMetadata,
                },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        final saved =
            settings
                    .providerConfigs['oauth-test']!
                    .modelOverrides['kimi-test-alias']
                as Map;
        expectMetadata(saved, openaiMetadata);
        expect(saved['name'], 'My Kimi');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'model type edits still clear chat fields while preserving OAuth metadata desktop=$desktop',
      (tester) async {
        await openModelEditor(
          tester,
          desktop: desktop,
          metadata: openaiMetadata,
        );
        await tester.ensureVisible(find.text('Embedding'));
        await tester.tap(find.text('Embedding'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        final saved =
            settings
                    .providerConfigs['oauth-test']!
                    .modelOverrides['kimi-test-alias']
                as Map;
        expectMetadata(saved, openaiMetadata);
        expect(saved['type'], 'embedding');
        expect(saved, isNot(contains('output')));
        expect(saved, isNot(contains('abilities')));
        expect(saved, isNot(contains('builtInTools')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('expired chat recovery becomes a confirmation after login', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const OAuthMessageRecovery(
          error: ProviderAuthErrorPart(providerId: 'oauth-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ChatGPT login has expired'), findsOneWidget);
    final config = settings.providerConfigs['oauth-test']!;
    await tester.runAsync(
      () => settings.setProviderConfig(
        config.id,
        config.copyWith(
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'secret',
            refreshToken: 'refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            sessionId: 'new',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Use the message retry button'), findsOneWidget);
    expect(find.text('Log in again'), findsNothing);
    expect(find.text('secret'), findsNothing);
  });
}
