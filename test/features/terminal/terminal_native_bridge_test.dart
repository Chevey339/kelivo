import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/terminal/services/terminal_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalNativeBridge', () {
    const channel = MethodChannel('test.terminal');
    final calls = <MethodCall>[];

    late TerminalNativeBridge bridge;

    setUp(() {
      calls.clear();
      bridge = TerminalNativeBridge(methodChannel: channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends lifecycle and PTY commands to native channel', () async {
      await bridge.startSession(sessionId: 's1', cols: 80, rows: 24);
      await bridge.writeSession(sessionId: 's1', data: 'pwd\n');
      await bridge.resizeSession(sessionId: 's1', cols: 100, rows: 32);
      await bridge.stopSession(sessionId: 's1');

      expect(calls.map((call) => call.method), [
        'startSession',
        'writeSession',
        'resizeSession',
        'stopSession',
      ]);
      expect(calls[0].arguments, containsPair('sessionId', 's1'));
      expect(calls[0].arguments, containsPair('cols', 80));
      expect(calls[0].arguments, containsPair('rows', 24));
      expect(calls[1].arguments, {'sessionId': 's1', 'data': 'pwd\n'});
      expect(calls[2].arguments, {'sessionId': 's1', 'cols': 100, 'rows': 32});
      expect(calls[3].arguments, {'sessionId': 's1'});
    });

    test('loads diagnostic log text from native channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getDiagnosticLog') {
              return {'text': 'actuate_kernel begin'};
            }
            return null;
          });

      final log = await bridge.getDiagnosticLog();

      expect(log, 'actuate_kernel begin');
      expect(calls.single.method, 'getDiagnosticLog');
    });

    test('sends diagnostic breadcrumb to native channel', () async {
      await bridge.appendDiagnostic('TerminalPage initState');

      expect(calls.single.method, 'appendDiagnostic');
      expect(calls.single.arguments, {'message': 'TerminalPage initState'});
    });

    test('drains terminal events from native channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'drainEvents') {
              return [
                {'type': 'sessionStarted', 'sessionId': 's1'},
              ];
            }
            return null;
          });

      final events = await bridge.drainEvents();

      expect(events, [
        {'type': 'sessionStarted', 'sessionId': 's1'},
      ]);
      expect(calls.single.method, 'drainEvents');
    });
  });
}
