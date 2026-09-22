import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/home/services/local_tool_toggle.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:Kelivo/features/settings/pages/phone_control_settings_page.dart';
import 'package:Kelivo/features/settings/search/settings_search_index.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';

import '../../../support/business_test_harness.dart';

const _channel = MethodChannel('app.device_tools');
const _enabled = Assistant(
  id: 'phone',
  name: 'Phone',
  localToolIds: [LocalToolNames.phoneControl],
);
late SettingsProvider _settings;

Widget _app(Widget home) => ChangeNotifierProvider.value(
  value: _settings,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    _settings = SettingsProvider(createBusinessTestPreferences());
    await _settings.loaded;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    _settings.dispose();
  });

  testWidgets(
    'phone tool and search entry are Android-only, including restored assistants',
    (tester) async {
      final android = defaultTargetPlatform == TargetPlatform.android;
      final definitions = LocalToolsService.buildToolDefinitions(
        assistant: _enabled,
        supportsTools: true,
      );
      expect(definitions.isNotEmpty, android);
      expect(
        SettingsSearchIndex(
          AppLocalizationsEn(),
          platform: defaultTargetPlatform,
        ).entries.any(
          (e) => e.destination == SettingsSearchDestination.phoneControl,
        ),
        android,
      );
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return '{"success":true}';
      });
      final result = await LocalToolsService.tryHandleToolCall(
        LocalToolNames.phoneControl,
        {'action': 'home'},
        _enabled,
      );
      expect(result != null, android);
      expect(calls.length, android ? 1 : 0);
      expect(
        LocalToolsService.buildToolDefinitions(
          assistant: _enabled,
          supportsTools: false,
        ),
        isEmpty,
      );
    },
    variant: TargetPlatformVariant.all(),
  );

  testWidgets(
    'disabled assistants never reach the native control API',
    (tester) async {
      messenger.setMockMethodCallHandler(
        _channel,
        (call) async => fail('Unexpected ${call.method}'),
      );
      expect(
        await LocalToolsService.tryHandleToolCall(LocalToolNames.phoneControl, {
          'action': 'home',
        }, const Assistant(id: 'off', name: 'Off')),
        isNull,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'tool preserves structured errors and exact Unicode input',
    (tester) async {
      final arguments = {
        'action': 'set_text',
        'snapshot_id': 'snapshot',
        'node_id': 'n2',
        'text': '你好 👋\nline 2',
      };
      messenger.setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'phoneControl');
        expect(jsonDecode(call.arguments as String), arguments);
        return '{"error":"STALE_SCREEN","message":"read again"}';
      });
      final result = await LocalToolsService.tryHandleToolCall(
        LocalToolNames.phoneControl,
        arguments,
        _enabled,
      );
      expect(jsonDecode(result!)['error'], 'STALE_SCREEN');
      messenger.setMockMethodCallHandler(
        _channel,
        (call) async => throw PlatformException(code: 'SERVICE_UNAVAILABLE'),
      );
      expect(
        jsonDecode(
          (await LocalToolsService.tryHandleToolCall(
            LocalToolNames.phoneControl,
            arguments,
            _enabled,
          ))!,
        )['error'],
        'SERVICE_UNAVAILABLE',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'settings refresh after resume and distinguish disconnected service',
    (tester) async {
      var status = {'enabled': false, 'connected': false};
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call.method);
        return call.method == 'phoneControlStatus' ? status : null;
      });
      await tester.pumpWidget(_app(const PhoneControlSettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Not enabled'), findsOneWidget);
      await tester.tap(find.text('Open accessibility settings'));
      await tester.pumpAndSettle();
      expect(calls, contains('openAccessibilitySettings'));
      status = {'enabled': true, 'connected': false};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enabled, but not connected.'),
        findsOneWidget,
      );
      status = {'enabled': true, 'connected': true};
      await tester.tap(find.byTooltip('Refresh status'));
      await tester.pumpAndSettle();
      expect(find.text('Enabled and connected'), findsOneWidget);
      expect(find.text('Accessibility switch unavailable?'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a stale status query cannot overwrite a newer refresh',
    (tester) async {
      final first = Completer<Map<String, bool>>();
      var count = 0;
      messenger.setMockMethodCallHandler(_channel, (_) async {
        if (count++ == 0) return first.future;
        return {'enabled': true, 'connected': true};
      });
      await tester.pumpWidget(_app(const PhoneControlSettingsPage()));
      await tester.pump();
      await tester.tap(find.byTooltip('Refresh status'));
      await tester.pumpAndSettle();
      first.complete({'enabled': false, 'connected': false});
      await tester.pumpAndSettle();
      expect(find.text('Enabled and connected'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'status failure stays unknown instead of claiming permission is disabled',
    (tester) async {
      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => throw MissingPluginException(),
      );
      await tester.pumpWidget(_app(const PhoneControlSettingsPage()));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to read service status. Refresh to try again.'),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'enabling requires consent and preserves assistant edits made while settings is open',
    (tester) async {
      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => {'enabled': false, 'connected': false},
      );
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      addTearDown(assistants.dispose);
      await assistants.loaded;
      final id = await assistants.addAssistant(name: 'Original');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: assistants,
          child: _app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => setLocalToolEnabled(
                    context,
                    assistant: assistants.getById(id)!,
                    toolId: LocalToolNames.phoneControl,
                    value: true,
                  ),
                  child: const Text('Enable'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(assistants.getById(id)!.localToolIds, isEmpty);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(assistants.getById(id)!.localToolIds, isEmpty);
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      await assistants.updateAssistant(
        assistants
            .getById(id)!
            .copyWith(
              name: 'Updated',
              localToolIds: [LocalToolNames.calculate],
            ),
      );
      final allow = find.text('Allow this assistant to use phone control');
      await tester.scrollUntilVisible(allow, 250);
      await tester.pumpAndSettle();
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(assistants.getById(id)!.name, 'Updated');
      expect(
        assistants.getById(id)!.localToolIds,
        containsAll([LocalToolNames.calculate, LocalToolNames.phoneControl]),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'disabling permission revokes an already-built tool handler',
    (tester) async {
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final mcp = McpProvider(preferences: createBusinessTestPreferences());
      final tools = McpToolService();
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(assistants.dispose);
      addTearDown(mcp.dispose);
      addTearDown(tools.dispose);
      addTearDown(settings.dispose);
      await assistants.loaded;
      await settings.loaded;
      final id = await assistants.addAssistant(name: 'Phone');
      await assistants.updateAssistant(
        assistants
            .getById(id)!
            .copyWith(localToolIds: [LocalToolNames.phoneControl]),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: assistants),
            ChangeNotifierProvider.value(value: mcp),
            ChangeNotifierProvider.value(value: tools),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      final handler = ToolHandlerService(
        contextProvider: tester.element(find.byType(SizedBox)),
      ).buildToolCallHandler(settings, assistants.getById(id))!;
      await assistants.updateAssistant(
        assistants.getById(id)!.copyWith(localToolIds: []),
      );
      messenger.setMockMethodCallHandler(
        _channel,
        (call) async => fail('Revoked tool reached native code'),
      );
      final result = await handler(LocalToolNames.phoneControl, {
        'action': 'home',
      });
      expect(
        jsonDecode(result as String)['error'],
        'permission_denied',
        reason: result,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('settings layout accommodates narrow screens and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PhoneControlSettingsView(
            status: const PhoneControlStatus(enabled: true, connected: false),
            loading: false,
            onRefresh: () {},
            onOpenSettings: () {},
            onOpenAppSettings: () {},
            onEnable: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Allow this assistant to use phone control'),
      200,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget preview is interactive without application providers', (
    tester,
  ) async {
    await tester.pumpWidget(phoneControlSettingsPreview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('前往无障碍设置'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
