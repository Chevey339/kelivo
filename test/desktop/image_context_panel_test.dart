import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/features/chat/widgets/image_context_panel.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../support/business_test_harness.dart';

class _TemporaryChat extends ChatService {
  @override
  bool isTemporaryConversation(String? id) => true;
}

class _Usage extends ContextUsageService {
  _Usage({
    required this.chat,
    required this.image,
    required super.settings,
    required super.assistants,
    required super.instructions,
    required super.worldBooks,
  }) : super(chatService: chat);
  final ChatService chat;
  final ChatContextImage image;
  @override
  Future<RequestImageContext?> imageContextPreview(
    String conversationId,
  ) async => RequestImageContext(
    settings: await chat.imageContextSettings(conversationId),
    images: [image],
  )..activeHandles.add(image.handle);
  @override
  Future<void> refresh(
    String conversationId, {
    String? draftText,
    bool force = false,
  }) async {}
}

void main() {
  late Directory dir;
  late File file;
  late _TemporaryChat chat;
  late ChatContextImage image;
  late _Usage usage;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('image_panel_');
    addTearDown(() => dir.delete(recursive: true));
    file = await File('${dir.path}/image.png').writeAsString('pixels');
    chat = _TemporaryChat();
    final settings = SettingsProvider(createBusinessTestPreferences());
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final instructions = InstructionInjectionProvider(
      preferences: createBusinessTestPreferences(),
    );
    final worlds = WorldBookProvider(
      preferences: createBusinessTestPreferences(),
    );
    await settings.loaded;
    await assistants.loaded;
    image = ChatContextImage(
      identity: const ContextImageIdentity('user', 'part:1'),
      uri: file.path,
      source: ContextImageSource.user,
      label: 'diagram',
    );
    usage = _Usage(
      chat: chat,
      image: image,
      settings: settings,
      assistants: assistants,
      instructions: instructions,
      worldBooks: worlds,
    );
    addTearDown(() {
      usage.dispose();
      chat.dispose();
      settings.dispose();
      assistants.dispose();
      instructions.dispose();
      worlds.dispose();
    });
  });
  testWidgets('image panel pins, changes mode and queues a new attachment', (
    tester,
  ) async {
    String? attached;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<ContextUsageService>.value(value: usage),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showImageContextPanel(
                  context,
                  'chat',
                  onAttach: (path) => attached = path,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
    expect(find.text('diagram'), findsOneWidget);
    await tester.tap(find.byTooltip('Pin image'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
    expect((await chat.imageContextSettings('chat')).pinned, {image.key});
    expect(find.byTooltip('Unpin image'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('Manage history images automatically').first,
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
    expect((await chat.imageContextSettings('chat')).automatic, isFalse);
    await tester.tap(find.byTooltip('Add to composer again'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
    expect(attached, file.path);
  });
}
