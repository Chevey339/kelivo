import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'side_panel_test_support.dart';

class _Chat extends ChatService {
  @override
  Conversation? getConversation(String id) => id == 'known-topic'
      ? Conversation(id: id, title: 'Planning the release')
      : null;
}

void main() {
  testWidgets('background tab descriptions use names and never expose IDs', (
    tester,
  ) async {
    final browser = BrowserService(
      store: SidePanelMemoryStore(),
      supported: false,
    );
    final panel = DesktopSidePanelController(browser: browser)
      ..setContext(conversationId: 'a', topicsOnRight: false);
    addTearDown(() {
      panel.dispose();
      browser.dispose();
    });
    tester.view.physicalSize = const Size(1126, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const missing = 'c45cf7ee-53d7-4be1-ad49-27b0512e5554';
    for (final id in ['known-topic', missing, null]) {
      await browser.createTab(ownerSessionId: id, title: 'Page $id');
    }
    panel.open();
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatService>(
        create: (_) => _Chat(),
        child: sidePanelHarness(panel),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidePanelAllTabs')));
    await tester.pumpAndSettle();
    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message ?? '')
        .toList();
    expect(
      tooltips.any((text) => text.contains('Planning the release')),
      isTrue,
    );
    expect(tooltips.any((text) => text.contains(missing)), isFalse);
    expect(tooltips.any((text) => text.contains('Other chat')), isTrue);
    expect(tooltips, contains('Personal tabs'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await browser.flush();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
