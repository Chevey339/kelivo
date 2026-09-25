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
import 'package:Kelivo/core/services/scheduled_task_preparation.dart';
import 'package:Kelivo/features/home/widgets/assistant_avatar.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_task_editor_page.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_tasks_page.dart';
import 'package:Kelivo/features/settings/widgets/memory_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/desktop/widgets/desktop_scheduled_task_form.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

class _IosEditorScheduledTasksService extends ScheduledTasksService {
  _IosEditorScheduledTasksService({required super.channel});

  @override
  bool get isIOS => true;
  int preparationChecks = 0;
  ScheduledTaskPreparationStatus status =
      ScheduledTaskPreparationStatus.prepared;
  @override
  ScheduledTaskPreparationStatus? preparationStatus(ScheduledTask task) =>
      status;
  @override
  Future<void> preparePendingTasks() async {
    preparationChecks++;
  }

  final preparedIds = <String>[];
  var manualStatus = ScheduledTaskPreparationStatus.preparing;
  @override
  Future<ScheduledTaskPreparationStatus> prepareNow(String taskId) async {
    preparedIds.add(taskId);
    updateStatus(manualStatus);
    return manualStatus;
  }

  void updateStatus(ScheduledTaskPreparationStatus value) {
    status = value;
    notifyListeners();
  }
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => null,
        );
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('haptic_feedback'), null);
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

  Widget app(
    Widget child, {
    bool dark = false,
    String locale = 'en',
    double scale = 1,
  }) => MultiProvider(
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: boundaryKey, child: child!),
      ),
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

  for (final (width, locale, dark) in [
    (320.0, 'en', false),
    (390.0, 'zh', false),
    (390.0, 'zh', true),
  ]) {
    testWidgets(
      'iOS list shows a quiet status in the task summary ($width, $locale, dark=$dark)',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        service.dispose();
        final ios = _IosEditorScheduledTasksService(channel: channel);
        service = ios;
        initial = ScheduledTask.fromJson({
          ...initial.toStoredJson(),
          'allowPreparation': true,
          'runs': [
            ScheduledTaskRun(
              id: 'next',
              status: 'prepared',
              scheduledFor: DateTime(2026, 9, 22, 8, 30),
              notificationState: 'registered',
              lastPrepareAt: DateTime(2026, 9, 21, 20),
              prepareAttempts: 2,
            ).toJson(),
          ],
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => {
                'exactAlarms': true,
                'tasks': [
                  jsonEncode({
                    ...initial.toStoredJson(),
                    'nextRunAt': DateTime(
                      2026,
                      9,
                      22,
                      8,
                      30,
                    ).millisecondsSinceEpoch,
                  }),
                ],
              },
            );
        await tester.pumpWidget(
          app(
            ScheduledTasksPage(service: service),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(locale));
        expect(ios.preparationChecks, 1);
        final badge = find.byKey(
          const ValueKey('scheduled-task-preparation-status'),
        );
        expect(
          find.descendant(
            of: badge,
            matching: find.text(l.scheduledTasksPrepared),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: badge, matching: find.byType(IosNavRow)),
          findsNothing,
        );
        final nextRow = find.byWidgetPredicate(
          (w) => w is IosNavRow && w.label.contains('08:30'),
        );
        expect(tester.widget<IosNavRow>(nextRow).label, contains('08:30'));
        expect(
          tester.getBottomLeft(badge).dy,
          lessThan(tester.getTopLeft(nextRow).dy),
        );
        expect(tester.widget<IosNavRow>(nextRow).labelTrailing, isNull);
        expect(badge.hitTestable(), findsOneWidget);
        await capture(
          tester,
          'ios-list-ready-${width.toInt()}-$locale-${dark ? 'dark' : 'light'}',
        );
        final states = {
          ScheduledTaskPreparationStatus.queued: (
            l.scheduledTasksPreparationQueued,
            l.scheduledTasksPreparationQueuedDetail,
          ),
          ScheduledTaskPreparationStatus.cooldown: (
            l.scheduledTasksPreparationCooldownWaiting,
            l.scheduledTasksPreparationRetryAt(
              DateFormat.Md(
                l.localeName,
              ).add_Hm().format(DateTime(2026, 9, 21, 20, 10)),
            ),
          ),
          ScheduledTaskPreparationStatus.attemptsExhausted: (
            l.scheduledTasksPreparationLimitReached,
            l.scheduledTasksPreparationAttemptsUsed(2, 2),
          ),
          ScheduledTaskPreparationStatus.unavailable: (
            l.scheduledTasksPreparationUnavailable,
            l.scheduledTasksPreparationReadFailed,
          ),
        };
        for (final entry in states.entries) {
          ios.updateStatus(entry.key);
          await tester.pumpAndSettle();
          expect(find.text(entry.value.$1), findsOneWidget);
          expect(find.text(entry.value.$2), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await capture(
          tester,
          'ios-list-blocked-${width.toInt()}-$locale-${dark ? 'dark' : 'light'}',
        );
        await tester.pumpWidget(
          app(
            ScheduledTasksPage(service: service),
            locale: locale,
            dark: dark,
            scale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );

    testWidgets(
      'iOS task menu prepares the selected task ($width, $locale, dark=$dark)',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        service.dispose();
        final ios = _IosEditorScheduledTasksService(channel: channel);
        service = ios;
        await tester.pumpWidget(
          app(
            ScheduledTasksPage(service: service),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(locale));
        await tester.tap(find.text(initial.name));
        await tester.pumpAndSettle();
        for (final label in [
          l.scheduledTasksRunNow,
          l.scheduledTasksPrepareNow,
          l.scheduledTasksHistory,
          l.scheduledTasksEdit,
          l.scheduledTasksDelete,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text(l.scheduledTasksPrepareNowDetail), findsOneWidget);
        await capture(
          tester,
          'ios-prepare-menu-${width.toInt()}-$locale-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.text(l.scheduledTasksPrepareNow));
        await tester.pumpAndSettle();
        expect(ios.preparedIds, ['task']);
        expect(find.text(l.scheduledTasksPreparing), findsOneWidget);
        expect(
          AppSnackBarManager().activeToasts.any(
            (t) => t.notification.message == l.scheduledTasksPrepareNowStarted,
          ),
          isTrue,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );

    testWidgets(
      'iOS preparation prompt can be edited, reset and saved ($width, $locale, dark=$dark)',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            editor(
              task: ScheduledTask.fromJson({
                ...initial.toJson(),
                'allowPreparation': true,
                'preparationPrompt': 'Custom preparation',
              }),
            ),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(
          const ValueKey('scheduled-tasks-preparation-prompt'),
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: card,
          matching: find.byType(TextField),
        );
        expect(
          tester.widget<TextField>(field).controller!.text,
          'Custom preparation',
        );
        await tap(
          tester,
          find.byKey(
            const ValueKey('scheduled-tasks-reset-preparation-prompt'),
          ),
        );
        expect(
          tester.widget<TextField>(field).controller!.text,
          ScheduledTask.defaultPreparationPrompt,
        );
        await Scrollable.ensureVisible(tester.element(card), alignment: .5);
        await tester.pumpAndSettle();
        await capture(
          tester,
          'ios-preparation-prompt-${width.toInt()}-$locale-${dark ? 'dark' : 'light'}',
        );
        const custom = '只输出助手消息。\n时间 {{scheduled_time}} / {{utc_offset}}';
        await tester.enterText(field, custom);
        await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
        expect(saved!.preparationPrompt, custom);
        expect(saved!.prompt, initial.prompt);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );

    testWidgets(
      'iOS preparation help leaves settings unchanged ($width, $locale, dark=$dark)',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            editor(
              task: ScheduledTask.fromJson({
                ...initial.toJson(),
                'allowPreparation': true,
              }),
            ),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(locale));
        final card = find.byKey(
          const ValueKey('scheduled-tasks-preparation-settings'),
        );
        await Scrollable.ensureVisible(tester.element(card));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card, matching: find.byType(MemoryTipIcon)),
          findsNWidgets(8),
        );
        // Rows without leading icons must align both ends of their dividers.
        final dividers = tester.widgetList<Divider>(
          find.descendant(of: card, matching: find.byType(Divider)),
        );
        expect(dividers, isNotEmpty);
        for (final divider in dividers) {
          expect(divider.indent, divider.endIndent);
        }
        final suffix = '${width.toInt()}-$locale-${dark ? 'dark' : 'light'}';
        await capture(tester, 'ios-preparation-$suffix');

        // A nested info icon must own both gestures, without toggling the
        // parent switch or opening the option sheet.
        for (final message in [
          l.scheduledTasksAllowPreparationTip,
          l.scheduledTasksContextPolicyTip,
        ]) {
          final tip = find.byWidgetPredicate(
            (widget) => widget is MemoryTipIcon && widget.message == message,
          );
          await Scrollable.ensureVisible(tester.element(tip), alignment: .4);
          await tester.pumpAndSettle();
          await tester.tap(tip);
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          Tooltip.dismissAllToolTips();
          await tester.pumpAndSettle();
          await tester.longPress(tip);
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          if (message == l.scheduledTasksContextPolicyTip) {
            await capture(tester, 'ios-preparation-tip-$suffix');
          }
          Tooltip.dismissAllToolTips();
          await tester.pumpAndSettle();
        }

        await tester.ensureVisible(find.text(l.scheduledTasksPreparationCost));
        await tester.pumpAndSettle();
        expect(
          find.text(l.scheduledTasksPreparationCost).hitTestable(),
          findsOneWidget,
        );
        expect(find.textContaining('Android'), findsNothing);
        await capture(tester, 'ios-preparation-cost-$suffix');
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<IosSwitchRow>(
                find.widgetWithText(
                  IosSwitchRow,
                  l.scheduledTasksAllowPreparation,
                ),
              )
              .value,
          isTrue,
        );
        expect(find.text(l.scheduledTasksContextLatest), findsOneWidget);

        service.dispose();
        service = _IosEditorScheduledTasksService(channel: channel);
        await tester.pumpWidget(
          app(
            ScheduledTasksPage(service: service),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final permission = find.byKey(
          const ValueKey('scheduled-tasks-notification-permission'),
        );
        await tester.ensureVisible(permission);
        await tester.pumpAndSettle();
        expect(find.text(l.scheduledTasksIOSDetail), findsOneWidget);
        final footerBottom = tester
            .getBottomLeft(
              find.byKey(const ValueKey('scheduled-tasks-description')),
            )
            .dy;
        expect(
          tester.getTopLeft(permission).dy - footerBottom,
          greaterThanOrEqualTo(24),
        );
        expect(find.textContaining('Android'), findsNothing);
        await capture(tester, 'ios-list-$suffix');
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'manual preparation reports busy work without claiming it has started',
    (tester) async {
      service.dispose();
      final ios = _IosEditorScheduledTasksService(channel: channel)
        ..manualStatus = ScheduledTaskPreparationStatus.queued;
      service = ios;
      await tester.pumpWidget(app(ScheduledTasksPage(service: service)));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(initial.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.scheduledTasksPrepareNow));
      await tester.pumpAndSettle();
      expect(ios.preparedIds, ['task']);
      expect(
        AppSnackBarManager().activeToasts.any(
          (t) => t.notification.message == l.scheduledTasksPrepareNowBusy,
        ),
        isTrue,
      );
      expect(
        AppSnackBarManager().activeToasts.any(
          (t) => t.notification.message == l.scheduledTasksPrepareNowStarted,
        ),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'new iOS tasks default to skip and permit an empty preparation prompt',
    (tester) async {
      await tester.pumpWidget(
        app(
          ScheduledTaskEditorPage(
            assistants: assistants.assistants,
            initialAssistantId: assistant.id,
            onSave: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));
      Finder fieldWithLabel(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is IosFormTextField && w.label == label,
        ),
        matching: find.byType(TextField),
      );
      await tester.enterText(fieldWithLabel(l.scheduledTasksName), 'Task');
      await tester.enterText(
        fieldWithLabel(l.scheduledTasksPrompt),
        'Say hello',
      );
      final card = find.byKey(
        const ValueKey('scheduled-tasks-preparation-prompt'),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        '',
      );
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      expect(saved!.unavailablePolicy, ScheduledTaskUnavailablePolicy.skip);
      expect(saved!.preparationPrompt, isEmpty);
      expect(saved!.allowPreparation, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'iOS editor saves preparation limits and preview preferences in the same task',
    (tester) async {
      const haptics = MethodChannel('haptic_feedback');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(haptics, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(haptics, null),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          editor(
            task: ScheduledTask.fromJson({
              ...initial.toJson(),
              'preparationWindowMinutes': 120,
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> toggle(String label) async {
        final row = find.widgetWithText(IosSwitchRow, label);
        await Scrollable.ensureVisible(tester.element(row), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      await toggle('Allow advance preparation');
      expect(find.text('2 hours'), findsOneWidget);
      await tapRow(tester, 'Prepare up to');
      for (final option in [
        '30 minutes',
        '1 hour',
        '6 hours',
        '8 hours',
        '18 hours',
        '24 hours',
      ]) {
        expect(find.text(option), findsOneWidget);
      }
      await tester.ensureVisible(find.text('24 hours'));
      await tap(tester, find.text('24 hours'));
      await tapRow(tester, 'Automatic attempt limit');
      await tap(tester, find.text('3').last);
      await toggle('Show result text in notifications');
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      expect(saved!.allowPreparation, isTrue);
      expect(saved!.maxPrepareAttempts, 3);
      expect(saved!.preparationWindowMinutes, 1440);
      expect(saved!.showPreview, isFalse);
      expect(saved!.contextPolicy, ScheduledTaskContextPolicy.latest);
      expect(saved!.hour, initial.hour);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

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
    await Scrollable.ensureVisible(tester.element(clear), alignment: 0.5);
    await tester.pumpAndSettle();
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
