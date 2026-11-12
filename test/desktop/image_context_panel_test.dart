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
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import '../support/business_test_harness.dart';

class _TemporaryChat extends ChatService {
  @override
  bool isTemporaryConversation(String? id) => true;
}

class _Usage extends ContextUsageService {
  _Usage({
    required this.chat,
    required this.images,
    required super.settings,
    required super.assistants,
    required super.instructions,
    required super.worldBooks,
  }) : super(chatService: chat);
  final ChatService chat;
  List<ChatContextImage> images;
  @override
  Future<RequestImageContext?> imageContextPreview(
    String conversationId,
  ) async => RequestImageContext(
    settings: await chat.imageContextSettings(conversationId),
    images: images,
  )..activeHandles.addAll(images.map((image) => image.handle));
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
      images: [image],
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
  Finder imageSwitch(String label) => find.byWidgetPredicate(
    (widget) => widget is IosSwitch && widget.semanticLabel == label,
  );

  Future<void> settlePanel(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(
    WidgetTester tester, {
    ValueChanged<String>? onAttach,
  }) async {
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
                onPressed: () =>
                    showImageContextPanel(context, 'chat', onAttach: onAttach),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settlePanel(tester);
  }

  testWidgets('image panel keeps recall independent of management and pins', (
    tester,
  ) async {
    String? attached;
    await openPanel(tester, onAttach: (path) => attached = path);
    expect(find.text('diagram'), findsOneWidget);
    final recall = imageSwitch('Allow the model to recall images');
    final automatic = imageSwitch('Manage history images automatically');
    expect(tester.widget<IosSwitch>(recall).value, isTrue);
    expect(tester.widget<IosSwitch>(automatic).value, isTrue);
    await tester.tap(recall);
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).allowRecall, isFalse);
    expect(tester.widget<IosSwitch>(automatic).value, isTrue);

    await tester.scrollUntilVisible(
      find.byTooltip('Pin image').hitTestable(),
      150,
      scrollable: find.descendant(
        of: find.byType(ImageContextPanel),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pin image'));
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).pinned, {image.key});
    expect((await chat.imageContextSettings('chat')).allowRecall, isFalse);
    expect(find.byTooltip('Unpin image'), findsOneWidget);
    await tester.ensureVisible(automatic);
    await tester.pumpAndSettle();
    await tester.tap(automatic);
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).automatic, isFalse);
    expect((await chat.imageContextSettings('chat')).allowRecall, isFalse);
    expect((await chat.imageContextSettings('chat')).pinned, {image.key});

    await tester.scrollUntilVisible(
      find.byTooltip('Add to composer again').hitTestable(),
      150,
      scrollable: find.descendant(
        of: find.byType(ImageContextPanel),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to composer again'));
    await settlePanel(tester);
    expect(attached, file.path);

    await tester.tap(find.text('Open'));
    await settlePanel(tester);
    await tester.ensureVisible(recall);
    await tester.pumpAndSettle();
    await tester.tap(recall);
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).allowRecall, isTrue);
    expect((await chat.imageContextSettings('chat')).automatic, isFalse);
    expect((await chat.imageContextSettings('chat')).pinned, {image.key});
  });

  testWidgets('remote reservations are not displayed as measured sizes', (
    tester,
  ) async {
    usage.images = [
      ChatContextImage(
        identity: const ContextImageIdentity('remote', 'tool:1'),
        uri: 'https://example.test/image.png',
        source: ContextImageSource.tool,
        label: 'remote',
      ),
    ];
    await openPanel(tester);
    expect(find.text('Size checked when sending'), findsOneWidget);
    expect(find.textContaining('5.00 MiB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image panel allows recall control before the first image', (
    tester,
  ) async {
    usage.images = [];
    await openPanel(tester);
    expect(find.text('No images yet'), findsOneWidget);
    final recall = imageSwitch('Allow the model to recall images');
    final automatic = imageSwitch('Manage history images automatically');
    await tester.tap(recall);
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).allowRecall, isFalse);
    expect(tester.widget<IosSwitch>(automatic).value, isTrue);
    expect(find.text('No images yet'), findsOneWidget);
    await tester.tap(automatic);
    await settlePanel(tester);
    expect((await chat.imageContextSettings('chat')).automatic, isFalse);
    expect(tester.widget<IosSwitch>(recall).value, isFalse);
  });
}
