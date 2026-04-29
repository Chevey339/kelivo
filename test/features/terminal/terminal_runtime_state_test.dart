import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/terminal/models/terminal_runtime_state.dart';

void main() {
  group('TerminalRuntimeState', () {
    test('parses native not-installed status payload', () {
      final state = TerminalRuntimeState.fromMap({
        'status': 'notInstalled',
        'integrationStatus': 'notLinked',
        'runtimeId': 'ios-alpine-arm64',
        'integrationReference': 'OpenMinis iSH ARM64',
        'version': null,
        'rootfsBytes': 0,
        'homeBytes': 0,
        'cacheBytes': 0,
        'lastError': null,
      });

      expect(state.status, TerminalRuntimeStatus.notInstalled);
      expect(
        state.integrationStatus,
        TerminalRuntimeIntegrationStatus.notLinked,
      );
      expect(state.runtimeId, 'ios-alpine-arm64');
      expect(state.integrationReference, 'OpenMinis iSH ARM64');
      expect(state.version, isNull);
      expect(state.totalBytes, 0);
      expect(state.lastError, isNull);
    });

    test('rejects unknown native status values', () {
      expect(
        () => TerminalRuntimeState.fromMap({'status': 'ready'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown native integration status values', () {
      expect(
        () => TerminalRuntimeState.fromMap({
          'status': 'notInstalled',
          'integrationStatus': 'maybe',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
