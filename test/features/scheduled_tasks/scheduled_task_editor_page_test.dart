import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import 'package:Kelivo/features/home/widgets/assistant_avatar.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_task_editor_page.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_tasks_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/desktop/widgets/desktop_scheduled_task_form.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

class _EditorChatService extends ChatService {
  _EditorChatService(this.repository, this.conversations);
  final ChatDatabaseRepository repository;
  final List<Conversation> conversations;
  @override
  Future<void> init() async {}
  @override
  ChatDatabaseRepository get chatRepositoryOrNull => repository;
  @override
  List<Conversation> getAllConversations() => conversations;
  @override
  Conversation? getConversation(String id) =>
      conversations.where((c) => c.id == id).firstOrNull;
}

void main() {
  const channel = MethodChannel('test.scheduled.editor');
  const assistant = Assistant(
    id: 'assistant',
    name: 'Daily assistant',
    avatar: '🌤️',
  );
  const other = Assistant(id: 'other', name: 'Other assistant', avatar: '🌿');
  late BusinessTestHarness storage;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late _EditorChatService chat;
  late ScheduledTasksService service;
  late ScheduledTask initial;
  ScheduledTask? saved;
  final boundaryKey = GlobalKey();
  final screenshots = Platform.environment['KELIVO_SCHEDULE_SCREENSHOTS'];

  setUpAll(() async {
    if (screenshots == null) return;
    final bytes = await File(
      Platform.environment['KELIVO_PREVIEW_FONT']!,
    ).readAsBytes();
    await (FontLoader(
      'ScheduledPreview',
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    final emojiPath = Platform.environment['KELIVO_PREVIEW_EMOJI_FONT'];
    if (emojiPath != null) {
      final emoji = await File(emojiPath).readAsBytes();
      await (FontLoader(
        'Apple Color Emoji',
      )..addFont(Future.value(emoji.buffer.asByteData()))).load();
    }
  });

  setUp(() async {
    storage = await BusinessTestHarness.create(
      initial: {
        'assistants_v1': jsonEncode([assistant.toJson(), other.toJson()]),
        'current_assistant_id_v1': assistant.id,
      },
    );
    settings = SettingsProvider(storage.preferences);
    assistants = AssistantProvider(preferences: storage.preferences);
    await Future.wait([settings.loaded, assistants.loaded]);
    await settings.setProviderConfig(
      'test-provider',
      ProviderConfig(
        id: 'test-provider',
        enabled: true,
        name: 'Test provider',
        apiKey: '',
        baseUrl: '',
        models: ['model-a', 'model-b'],
      ),
    );
    await settings.setCurrentModel('test-provider', 'model-a');
    final repo = ChatDatabaseRepository(storage.database);
    final conversation = Conversation(
      id: 'chat',
      title: 'Project review',
      assistantId: assistant.id,
    );
    await repo.putConversation(conversation);
    await repo.putMessage(
      ChatMessage(
        id: 'question',
        role: 'user',
        content: 'Review the latest changes',
        conversationId: conversation.id,
      ),
    );
    chat = _EditorChatService(repo, [
      conversation,
      Conversation(
        id: 'other-chat',
        title: 'Other assistant chat',
        assistantId: other.id,
      ),
    ]);
    initial = ScheduledTask(
      id: 'task',
      name: 'Morning briefing',
      prompt: 'Summarize the project updates',
      assistantId: assistant.id,
      hour: 8,
      minute: 30,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {
            'exactAlarms': true,
            'tasks': [
              jsonEncode({
                ...initial.toJson(),
                'nextRunAt': DateTime.now()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch,
              }),
            ],
          },
        );
    service = ScheduledTasksService(channel: channel);
    saved = null;
  });

  tearDown(() async {
    service.dispose();
    chat.dispose();
    settings.dispose();
    assistants.dispose();
    await storage.close();
  });

  ThemeData theme(bool dark) {
    final base = dark
        ? buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark)
        : buildLightThemeForScheme(ThemePalettes.defaultPalette.light);
    if (screenshots == null) return base;
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'ScheduledPreview'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
          fontFamily: 'ScheduledPreview',
        ),
      ),
    );
  }

  Widget app(Widget child, {bool dark = false, String locale = 'en'}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: theme(dark),
          builder: (_, child) =>
              RepaintBoundary(key: boundaryKey, child: child!),
          home: child,
        ),
      );

  Widget editor({ScheduledTask? task}) => ScheduledTaskEditorPage(
    task: task ?? initial,
    assistants: assistants.assistants,
    initialAssistantId: assistant.id,
    onSave: (value) async => saved = value,
  );

  Future<void> tap(
    WidgetTester tester,
    Finder target, {
    bool settle = true,
  }) async {
    await tester.runAsync(() async {
      await tester.tap(target);
      // Selections may await SQLite or a Future created outside the fake clock.
      await Future<void>.delayed(Duration.zero);
    });
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> tapRow(
    WidgetTester tester,
    String label, {
    bool settle = true,
  }) async {
    final row = find.widgetWithText(IosNavRow, label);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tap(tester, row, settle: settle);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (screenshots == null) return;
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(screenshots).create(recursive: true);
      await File(
        '$screenshots/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'add opens a route with the same navigation geometry as the list',
    (tester) async {
      await tester.pumpWidget(app(ScheduledTasksPage(service: service)));
      await tester.pumpAndSettle();
      final listHeader = tester.getRect(
        find.byKey(const ValueKey('scheduled-tasks-navigation')),
      );
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduledTaskEditorPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('scheduled-tasks-navigation')),
        ),
        listHeader,
      );
      expect(tester.getTopLeft(find.text('Add task')).dx, 72);
    },
  );

  testWidgets(
    'follow up selects a chat and a model without changing global settings',
    (tester) async {
      await tester.pumpWidget(app(editor()));
      await tester.pumpAndSettle();
      await tapRow(tester, 'Action');
      await tap(tester, find.text('Follow up'));
      await tester.pumpAndSettle();
      await tapRow(tester, 'Conversation');
      expect(find.text('Other assistant chat'), findsNothing);
      await tap(tester, find.text('Project review'));
      await tester.pumpAndSettle();
      await tapRow(tester, 'Model', settle: false);
      // The existing model picker processes its catalog in a real isolate.
      for (var i = 0; i < 50 && find.text('model-b').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      await tap(tester, find.text('model-b'));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      await tester.pumpAndSettle();
      expect(saved?.mode, ScheduledTaskMode.followUp);
      expect(saved?.conversationId, 'chat');
      expect(saved?.modelProvider, 'test-provider');
      expect(saved?.modelId, 'model-b');
      expect(settings.currentModelId, 'model-a');
      expect(chat.getConversation('chat')!.chatModelId, isNull);
    },
  );

  testWidgets(
    'run again picks a question and does not require another prompt',
    (tester) async {
      await tester.pumpWidget(
        app(
          editor(
            task: const ScheduledTask(
              id: 'task',
              name: 'Rerun',
              prompt: '',
              assistantId: 'assistant',
              hour: 8,
              minute: 0,
              mode: ScheduledTaskMode.regenerate,
              conversationId: 'chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapRow(tester, 'Question to run again');
      await tap(tester, find.text('Review the latest changes'));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      await tester.pumpAndSettle();
      expect(saved?.mode, ScheduledTaskMode.regenerate);
      expect(saved?.messageId, 'question');
      expect(saved?.prompt, isEmpty);
    },
  );

  testWidgets('changing assistant clears a target owned by the old assistant', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        editor(
          task: const ScheduledTask(
            id: 'task',
            name: 'Task',
            prompt: 'Prompt',
            assistantId: 'assistant',
            hour: 8,
            minute: 0,
            mode: ScheduledTaskMode.followUp,
            conversationId: 'chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapRow(tester, 'Assistant');
    await tap(tester, find.text('Other assistant'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AssistantAvatar>(find.byType(AssistantAvatar))
          .assistant
          ?.id,
      'other',
    );
    await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Choose a conversation'), findsWidgets);
  });

  testWidgets(
    'one-time preset saves an explicit date and hides the repeating window',
    (tester) async {
      await tester.pumpWidget(app(editor()));
      await tester.pumpAndSettle();
      await tapRow(tester, 'Repeat');
      await tap(tester, find.text('Once'));
      await tester.pumpAndSettle();
      expect(find.text('Active dates'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      await tester.pumpAndSettle();
      expect(saved?.repeat, ScheduledTaskRepeat.once);
      expect(saved?.onceDate, isNotNull);
      expect(saved?.startDate, isNull);
      expect(saved?.endDate, isNull);
    },
  );

  testWidgets('active date uses the shared calendar and may be cleared', (
    tester,
  ) async {
    final year = DateTime.now().year + 1;
    await tester.pumpWidget(
      app(
        editor(
          task: ScheduledTask(
            id: 'task',
            name: 'Task',
            prompt: 'Prompt',
            assistantId: 'assistant',
            hour: 8,
            minute: 0,
            startDate: DateTime(year, 1, 10),
            endDate: DateTime(year, 1, 20),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapRow(tester, 'End date');
    final calendar = find.byKey(const ValueKey('ios-date-picker-calendar'));
    expect(calendar, findsOneWidget);
    await tap(tester, find.descendant(of: calendar, matching: find.text('25')));
    await tester.pumpAndSettle();
    final clear = find.byWidgetPredicate(
      (w) => w is IosIconButton && w.semanticLabel == 'Clear Start date',
    );
    await tester.ensureVisible(clear);
    await tap(tester, clear);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
    await tester.pumpAndSettle();
    expect(saved?.startDate, isNull);
    expect(saved?.endDate, DateTime(year, 1, 25));
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 1280.0]) {
      testWidgets('editor fits $width in ${dark ? 'dark' : 'light'} mode', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final task = ScheduledTask(
          id: 'task',
          name: '晨间简报',
          prompt: '整理项目的最新进展，总结今天需要关注的事项。',
          assistantId: 'assistant',
          hour: 8,
          minute: 30,
          weekdays: const [1, 3, 5],
        );
        await tester.pumpWidget(
          app(
            editor(task: task),
            dark: dark,
            locale: 'zh',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AssistantAvatar), findsOneWidget);
        expect(
          tester.getRect(find.byType(ScheduledTaskEditorPage)).width,
          width,
        );
        await capture(
          tester,
          'editor-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('scheduled-weekday-1')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'schedule-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        initial = task;
        await tester.pumpWidget(
          app(
            ScheduledTasksPage(service: service),
            dark: dark,
            locale: 'zh',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'list-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
      });
    }
  }

  testWidgets(
    'narrow desktop uses a calendar dialog without a bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(editor()));
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Start date'),
        matching: find.byType(DesktopScheduledTaskRow),
      );
      final picker = find.descendant(
        of: row,
        matching: find.byType(DesktopScheduledTaskPicker),
      );
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ios-date-picker-calendar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
