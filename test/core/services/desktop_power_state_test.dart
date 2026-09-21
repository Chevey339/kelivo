import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/desktop_power_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(DesktopPowerState.channel, null),
  );

  test('native power snapshot preserves sleep and wake timestamps', () async {
    final wake = DateTime(2026, 9, 11, 8, 1);
    messenger.setMockMethodCallHandler(DesktopPowerState.channel, (call) async {
      expect(call.method, 'state');
      return {'sleeping': true, 'lastWakeAt': wake.millisecondsSinceEpoch};
    });
    final snapshot = await DesktopPowerState.read();
    expect(snapshot.sleeping, isTrue);
    expect(snapshot.lastWakeAt, wake);
  });

  test('a failed native monitor is not treated as an awake snapshot', () async {
    messenger.setMockMethodCallHandler(DesktopPowerState.channel, (call) async {
      throw PlatformException(code: 'power_monitor_unavailable');
    });
    await expectLater(
      DesktopPowerState.read(),
      throwsA(isA<PlatformException>()),
    );
  });
}
