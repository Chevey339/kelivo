import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/terminal/pages/terminal_page.dart';
import 'package:Kelivo/features/terminal/providers/terminal_ai_tool_provider.dart';
import 'package:Kelivo/features/terminal/services/terminal_native_bridge.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

class _FakeTerminalBridge extends TerminalNativeBridge {
  _FakeTerminalBridge({this.bootingFailuresBeforeSuccess = 0});

  final int bootingFailuresBeforeSuccess;
  int startCalls = 0;
  final diagnostics = <String>[];
  final writes = <Map<String, String>>[];
  final eventBatches = <List<Map<Object?, Object?>>>[];

  @override
  Future<void> appendDiagnostic(String message) async {
    diagnostics.add(message);
  }

  @override
  Future<List<Map<Object?, Object?>>> drainEvents() async {
    if (eventBatches.isEmpty) return const [];
    return eventBatches.removeAt(0);
  }

  @override
  Future<void> startSession({
    required String sessionId,
    required int cols,
    required int rows,
  }) async {
    startCalls++;
    if (startCalls <= bootingFailuresBeforeSuccess) {
      throw const TerminalNativeBridgeException(
        code: 'terminal_kernel_booting',
        message: 'OpenMinis iSH kernel is still booting.',
      );
    }
  }

  @override
  Future<void> stopSession({required String sessionId}) async {}

  @override
  Future<void> writeSession({
    required String sessionId,
    required String data,
  }) async {
    writes.add({'sessionId': sessionId, 'data': data});
  }

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int cols,
    required int rows,
  }) async {}
}

Future<void> _pumpTerminalPage(
  WidgetTester tester, {
  required TerminalNativeBridge bridge,
  TerminalAiToolProvider? terminalAiToolProvider,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              terminalAiToolProvider ??
              TerminalAiToolProvider(initialEnabled: false),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TerminalPage(bridge: bridge),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TerminalPage retries while native kernel is booting', (
    tester,
  ) async {
    final bridge = _FakeTerminalBridge(bootingFailuresBeforeSuccess: 2);

    await _pumpTerminalPage(tester, bridge: bridge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(bridge.startCalls, 3);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('terminal_kernel_booting'), findsNothing);
  });

  testWidgets('TerminalPage shortcut row writes to native session', (
    tester,
  ) async {
    final bridge = _FakeTerminalBridge();

    await _pumpTerminalPage(tester, bridge: bridge);
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tab'));
    await tester.pump();

    expect(bridge.writes, hasLength(1));
    expect(bridge.writes.single['data'], '\t');
  });

  testWidgets('TerminalPage decodes base64 output events', (tester) async {
    final bridge = _FakeTerminalBridge()
      ..eventBatches.add([
        {
          'type': 'sessionOutput',
          'sessionId': null,
          'dataBase64': 'a2VsaXZvCg==',
          'byteLength': 7,
        },
      ]);

    await _pumpTerminalPage(tester, bridge: bridge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      bridge.diagnostics,
      contains(startsWith('TerminalPage first output event bytes=7')),
    );
    expect(
      bridge.diagnostics,
      contains(startsWith('TerminalPage first terminal write chars=7')),
    );
  });

  testWidgets('TerminalPage toggles AI terminal tools', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final bridge = _FakeTerminalBridge();
    final terminalAiTools = TerminalAiToolProvider(initialEnabled: false);

    await _pumpTerminalPage(
      tester,
      bridge: bridge,
      terminalAiToolProvider: terminalAiTools,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('AI tools'), findsOneWidget);
    expect(terminalAiTools.enabled, isFalse);

    await tester.tap(find.byType(IosSwitch));
    await tester.pump();

    expect(terminalAiTools.enabled, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
