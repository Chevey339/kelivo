import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

// Run on an unlocked Android test device with Kelivo's accessibility service
// enabled. Uses a local fixture and Android Settings; no model or account needed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;

  setUpAll(() async {
    // Acquire the platform-owned semantics handle before testWidgets records
    // its baseline, so enabling the real service is not mistaken for a leak.
    debugPrint('PHONE_CONTROL_WAITING_FOR_SERVICE');
    var ready = false;
    for (var i = 0; i < 90; i++) {
      ready = (await DeviceLocalTools.phoneControlStatus())?.connected == true;
      if (ready) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(
      ready,
      isTrue,
      reason:
          'Enable Kelivo phone control in Android Accessibility settings on this test device.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  testWidgets('phone control reads and operates real Android windows', (
    tester,
  ) async {
    const assistant = Assistant(
      id: 'smoke',
      name: 'Smoke',
      localToolIds: [LocalToolNames.phoneControl],
    );
    final text = TextEditingController();
    final password = TextEditingController(text: 'private-password');
    addTearDown(text.dispose);
    addTearDown(password.dispose);
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(title: const Text('Phone control smoke test')),
            body: Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => taps++),
                  onLongPress: () => setState(() => longPresses++),
                  child: Text('Tap target: $taps / $longPresses'),
                ),
                TextField(
                  controller: text,
                  decoration: const InputDecoration(labelText: 'Input target'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password target',
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 40,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 80, child: Text('List item $i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<Map<String, dynamic>> call(Map<String, dynamic> args) async {
      final result =
          jsonDecode(
                (await LocalToolsService.tryHandleToolCall(
                  LocalToolNames.phoneControl,
                  args,
                  assistant,
                ))!,
              )
              as Map<String, dynamic>;
      expect(result['error'], isNull, reason: '$args -> $result');
      return result;
    }

    Future<Map<String, dynamic>> screen() async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return call({'action': 'read_screen'});
    }

    Future<Map<String, dynamic>> waitForPackage(
      bool Function(String?) matches,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline)) {
        // App transitions are asynchronous and may temporarily have no window.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final value =
            jsonDecode(
                  (await LocalToolsService.tryHandleToolCall(
                    LocalToolNames.phoneControl,
                    {'action': 'read_screen'},
                    assistant,
                  ))!,
                )
                as Map<String, dynamic>;
        if (value['error'] == null &&
            matches(value['package_name'] as String?)) {
          return value;
        }
      }
      fail('Foreground app did not change within the transition timeout.');
    }

    Map<String, dynamic> findNode(
      Map<String, dynamic> snapshot,
      bool Function(Map<String, dynamic>) predicate,
    ) => (snapshot['nodes'] as List).cast<Map<String, dynamic>>().firstWhere(
      predicate,
    );

    var snapshot = await screen();
    expect(snapshot['package_name'], 'com.psyche.kelivo');
    expect(jsonEncode(snapshot), isNot(contains('private-password')));
    var button = findNode(
      snapshot,
      (n) =>
          n['text']?.toString().contains('Tap target') == true ||
          n['description']?.toString().contains('Tap target') == true,
    );
    await call({
      'action': 'tap',
      'snapshot_id': snapshot['snapshot_id'],
      'node_id': button['node_id'],
    });
    await tester.pumpAndSettle();
    expect(taps, 1);

    snapshot = await screen();
    button = findNode(
      snapshot,
      (n) =>
          n['text']?.toString().contains('Tap target') == true ||
          n['description']?.toString().contains('Tap target') == true,
    );
    final bounds = (button['bounds'] as List).cast<num>();
    await call({
      'action': 'long_press',
      'snapshot_id': snapshot['snapshot_id'],
      'x': (bounds[0] + bounds[2]) / 2,
      'y': (bounds[1] + bounds[3]) / 2,
    });
    await tester.pumpAndSettle();
    expect(longPresses, 1);

    snapshot = await screen();
    var input = findNode(
      snapshot,
      (n) => n['editable'] == true && n['password'] != true,
    );
    await call({
      'action': 'tap',
      'snapshot_id': snapshot['snapshot_id'],
      'node_id': input['node_id'],
    });
    snapshot = await screen();
    input = findNode(
      snapshot,
      (n) => n['editable'] == true && n['password'] != true,
    );
    expect(input['supports_set_text'], isTrue);
    await call({
      'action': 'set_text',
      'snapshot_id': snapshot['snapshot_id'],
      'node_id': input['node_id'],
      'text': 'Hello Android',
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(text.text, 'Hello Android');
    await call({'action': 'back'});

    snapshot = await screen();
    final scroll = findNode(snapshot, (n) => n['scrollable'] == true);
    await call({
      'action': 'scroll',
      'snapshot_id': snapshot['snapshot_id'],
      'node_id': scroll['node_id'],
      'direction': 'forward',
    });
    final afterScroll = await screen();
    expect(
      jsonEncode(afterScroll['nodes']),
      isNot(equals(jsonEncode(snapshot['nodes']))),
    );

    final apps = await call({'action': 'list_apps'});
    expect(
      (apps['apps'] as List).any(
        (a) => a['package_name'] == 'com.android.settings',
      ),
      isTrue,
    );
    await call({'action': 'open_app', 'package_name': 'com.android.settings'});
    snapshot = await waitForPackage((name) => name == 'com.android.settings');
    expect(snapshot['package_name'], 'com.android.settings');
    await call({'action': 'home'});
    snapshot = await waitForPackage(
      (name) => name != null && name != 'com.android.settings',
    );
    expect(snapshot['package_name'], isNot('com.android.settings'));
    await call({'action': 'open_app', 'package_name': 'com.psyche.kelivo'});
    snapshot = await waitForPackage((name) => name == 'com.psyche.kelivo');
    expect(snapshot['package_name'], 'com.psyche.kelivo');
  });
}
