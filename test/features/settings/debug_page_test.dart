import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/setting/about_pane.dart';
import 'package:Kelivo/features/settings/pages/about_page.dart';
import 'package:Kelivo/features/settings/pages/debug_page.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _FakeChatService extends ChatService {
  Conversation? restoredConversation;
  List<ChatMessage>? restoredMessages;

  @override
  Future<void> restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    restoredConversation = conversation;
    restoredMessages = List<ChatMessage>.of(messages);
    notifyListeners();
  }
}

class _FakeAssistantProvider extends AssistantProvider {
  static const assistant = Assistant(
    id: 'assistant-debug',
    name: 'Debug Assistant',
  );

  @override
  Assistant? get currentAssistant => assistant;

  @override
  String? get currentAssistantId => assistant.id;
}

Widget _harness({
  required AssistantProvider assistantProvider,
  required ChatService chatService,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<AssistantProvider>.value(value: assistantProvider),
      ChangeNotifierProvider<ChatService>.value(value: chatService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets(
    'DebugPage creates a 1024-message conversation and stays visible',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final assistantProvider = _FakeAssistantProvider();
      final chatService = _FakeChatService();

      await tester.pumpWidget(
        _harness(
          assistantProvider: assistantProvider,
          chatService: chatService,
          home: const DebugPage(),
        ),
      );
      await tester.pump();

      final button = tester.widget<IosTileButton>(
        find.byKey(debugCreateManyMessagesConversationButtonKey),
      );
      button.onTap();
      await tester.pump();

      expect(find.text('Debug'), findsOneWidget);
      expect(chatService.restoredConversation?.assistantId, 'assistant-debug');
      expect(chatService.restoredMessages, hasLength(1024));
      expect(chatService.restoredMessages!.first.role, 'user');
      expect(chatService.restoredMessages![1].role, 'assistant');

      AppSnackBarManager().dismissAll();
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('DebugPage creates a long reasoning conversation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final assistantProvider = _FakeAssistantProvider();
    final chatService = _FakeChatService();

    await tester.pumpWidget(
      _harness(
        assistantProvider: assistantProvider,
        chatService: chatService,
        home: const DebugPage(),
      ),
    );
    await tester.pump();

    final button = tester.widget<IosTileButton>(
      find.byKey(debugCreateLongReasoningConversationButtonKey),
    );
    button.onTap();
    await tester.pump();

    expect(chatService.restoredConversation?.assistantId, 'assistant-debug');
    expect(chatService.restoredMessages, hasLength(128));
    final assistantMessages = chatService.restoredMessages!.where(
      (message) => message.role == 'assistant',
    );
    expect(
      assistantMessages.every(
        (message) =>
            (message.reasoningText ?? '').isNotEmpty &&
            (message.reasoningSegmentsJson ?? '').isNotEmpty,
      ),
      isTrue,
    );

    AppSnackBarManager().dismissAll();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('mobile AboutPage app icon long press opens DebugPage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final assistantProvider = _FakeAssistantProvider();
    final chatService = _FakeChatService();

    await tester.pumpWidget(
      _harness(
        assistantProvider: assistantProvider,
        chatService: chatService,
        home: const AboutPage(),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Create 1024-message conversation'), findsOneWidget);
  });

  testWidgets('desktop about pane app icon long press opens DebugPage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final assistantProvider = _FakeAssistantProvider();
    final chatService = _FakeChatService();

    await tester.pumpWidget(
      _harness(
        assistantProvider: assistantProvider,
        chatService: chatService,
        home: const Scaffold(body: DesktopAboutPane()),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Create oversized conversation (30 MB)'), findsOneWidget);
  });
}
