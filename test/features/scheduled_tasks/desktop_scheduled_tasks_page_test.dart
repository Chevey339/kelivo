import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/desktop_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/setting/scheduled_tasks_pane.dart';
import 'package:Kelivo/features/home/widgets/assistant_avatar.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_task_editor_page.dart';
import 'package:Kelivo/desktop/widgets/desktop_scheduled_task_tile.dart';
import 'package:Kelivo/desktop/widgets/desktop_scheduled_task_form.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_text_field.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../support/business_test_harness.dart';

class _DesktopChat extends ChatService {
  @override
  Future<void> init() async {}
  @override
  List<Conversation> getAllConversations() => const [];
}

void main() {
  const assistant = Assistant(
    id: 'assistant',
    name: 'Daily assistant',
    avatar: 'K',
  );
  late BusinessTestHarness storage;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late ScheduledTasksService service;
  final boundary = GlobalKey();
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
  });

  setUp(() async {
    storage = await BusinessTestHarness.create(
      initial: {
        'assistants_v1': jsonEncode([assistant.toJson()]),
        'current_assistant_id_v1': assistant.id,
      },
    );
    settings = SettingsProvider(storage.preferences);
    assistants = AssistantProvider(preferences: storage.preferences);
    await Future.wait([settings.loaded, assistants.loaded]);
    final task = ScheduledTask(
      id: 'task',
      name: 'Morning briefing',
      prompt: 'Summarize my project updates',
      assistantId: assistant.id,
      hour: 8,
      minute: 30,
      runs: [
        ScheduledTaskRun(
          id: 'run',
          startedAt: DateTime(2026, 9, 10, 8, 30),
          status: 'completed',
          conversationId: 'chat',
          preview: 'Yesterday’s project summary',
        ),
      ],
    );
    await storage.preferences.setString(
      ScheduledTaskStore.preferenceKey,
      jsonEncode([task.toStoredJson()]),
    );
    service = ScheduledTasksService(
      desktop: DesktopScheduledTasks(
        store: ScheduledTaskStore(storage.preferences),
        now: () => DateTime(2026, 9, 11, 7),
      ),
    );
    await service.refresh();
  });

  tearDown(() async {
    service.dispose();
    settings.dispose();
    assistants.dispose();
    await storage.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool dark = false,
    bool menu = false,
    EdgeInsets inset = EdgeInsets.zero,
    Size size = const Size(1400, 900),
  }) async {
    if (menu) {
      await tester.runAsync(() async {
        ScheduledTasksService.configureDesktop(storage.preferences);
        await ScheduledTasksService.instance.refresh();
      });
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = dark
        ? buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark)
        : buildLightThemeForScheme(ThemePalettes.defaultPalette.light);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider<ChatService>(create: (_) => _DesktopChat()),
        ],
        child: MaterialApp(
          theme: screenshots == null
              ? theme
              : theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    fontFamily: 'ScheduledPreview',
                  ),
                ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: boundary,
            child: Padding(
              padding: inset,
              child: menu
                  ? const DesktopSettingsPage()
                  : DesktopScheduledTasksPane(service: service),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (screenshots == null) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(target);
      // Provider readiness futures are created during setup outside the fake clock.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets(
      '$platform desktop tasks use dialogs and expose only desktop guidance',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await pumpApp(tester);
          expect(
            find.textContaining('Tasks run only while Kelivo is running'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('scheduled-tasks-background-settings')),
            findsNothing,
          );
          expect(find.text('Exact alarm permission'), findsNothing);
          expect(find.byType(DesktopScheduledTaskTile), findsOneWidget);
          await tap(
            tester,
            find.byWidgetPredicate(
              (widget) =>
                  widget is IosIconButton &&
                  widget.semanticLabel == 'More Actions',
            ),
          );
          expect(find.text('Run now'), findsOneWidget);
          expect(find.byType(AppDialogHeader), findsNothing);
          await tap(tester, find.text('Run history'));
          await tester.pumpAndSettle();
          expect(find.text('Yesterday’s project summary'), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          final opens = <String>[];
          final sub = NotificationService.conversationTaps.listen(opens.add);
          await tap(tester, find.text('View conversation'));
          await tester.pumpAndSettle();
          expect(opens, ['chat']);
          addTearDown(sub.cancel);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'desktop editor stays in the pane and reuses pickers, dark=$dark',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await pumpApp(tester, dark: dark);
          await screenshot(tester, 'desktop-tasks-${dark ? 'dark' : 'light'}');
          final navigators = tester.widgetList(find.byType(Navigator)).length;
          await tap(
            tester,
            find.byKey(const ValueKey('scheduled-tasks-action')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ScheduledTaskEditorPage), findsOneWidget);
          expect(
            find.textContaining('Open them from the task’s run history'),
            findsOneWidget,
          );
          expect(
            find.textContaining('A completion notification'),
            findsNothing,
          );
          expect(tester.widgetList(find.byType(Navigator)).length, navigators);
          expect(find.byType(AssistantAvatar), findsWidgets);
          expect(find.byType(DesktopWorkspaceTextField), findsNWidgets(2));
          final field = find.descendant(
            of: find.byKey(const ValueKey('scheduled-task-name')),
            matching: find.byType(TextField),
          );
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final fill = tester.widget<TextField>(field).decoration!.fillColor;
          for (final picker in tester.widgetList<DesktopScheduledTaskPicker>(
            find.byType(DesktopScheduledTaskPicker),
          )) {
            final press = find.descendant(
              of: find.byWidget(picker),
              matching: find.byType(IosCardPress),
            );
            expect(tester.widget<IosCardPress>(press).baseColor, fill);
            expect(tester.getSize(find.byWidget(picker)), const Size(240, 36));
          }
          expect(
            tester
                .widget<DesktopSelectDropdown<ScheduledTaskMode>>(
                  find.byKey(const ValueKey('scheduled-task-mode')),
                )
                .triggerFillColor,
            fill,
          );
          expect(
            tester
                .widget<DesktopSelectDropdown<ScheduledTaskRepeat>>(
                  find.byKey(const ValueKey('scheduled-task-repeat')),
                )
                .triggerFillColor,
            fill,
          );
          final before = tester.getRect(editable);
          expect(
            (before.center.dy - tester.getRect(field).center.dy).abs(),
            lessThan(1),
          );
          await tester.enterText(field, 'Morning briefing');
          await tester.pump();
          expect(tester.getRect(editable), before);
          expect(
            find.byType(DesktopSelectDropdown<ScheduledTaskMode>),
            findsOneWidget,
          );
          expect(
            find.byType(DesktopSelectDropdown<ScheduledTaskRepeat>),
            findsOneWidget,
          );

          await screenshot(tester, 'desktop-editor-${dark ? 'dark' : 'light'}');
          await tester.ensureVisible(
            find.byKey(const ValueKey('scheduled-task-time')),
          );
          await tap(tester, find.byKey(const ValueKey('scheduled-task-time')));
          expect(
            find.byKey(const ValueKey('ios-time-picker-desktop-sheet')),
            findsOneWidget,
          );
          expect(find.byType(BottomSheet), findsNothing);
          await tap(tester, find.text('Cancel').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('scheduled-task-repeat')),
          );
          await tap(
            tester,
            find.byKey(const ValueKey('scheduled-task-repeat')),
          );
          expect(find.byType(AppDialogHeader), findsNothing);
          expect(find.text('Weekdays'), findsOneWidget);
          await screenshot(tester, 'desktop-repeat-${dark ? 'dark' : 'light'}');
          expect(find.byType(BottomSheet), findsNothing);
          await tap(tester, find.text('Weekdays'));
          await tester.pumpAndSettle();
          final back = find.byWidgetPredicate(
            (widget) =>
                widget is IosIconButton && widget.semanticLabel == 'Back',
          );
          await tap(tester, back);
          await tester.pumpAndSettle();
          expect(find.byType(ScheduledTaskEditorPage), findsNothing);
          expect(find.byType(DesktopScheduledTaskTile), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('desktop empty state has one compact add control', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.runAsync(() => service.delete('task'));
      await pumpApp(tester, size: const Size(1000, 700));
      expect(find.byType(DesktopScheduledTaskTile), findsNothing);
      expect(
        find.byKey(const ValueKey('scheduled-tasks-action')),
        findsOneWidget,
      );
      expect(find.text('Add task'), findsNothing);
      final empty = find.byKey(const ValueKey('desktop-scheduled-tasks-empty'));
      expect(tester.getSize(empty).height, lessThan(180));
      await screenshot(tester, 'desktop-empty');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'desktop form stays compact at narrow widths and preserves dropdown selections',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpApp(tester, size: const Size(420, 700));
        await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
        final mode = find.byKey(const ValueKey('scheduled-task-mode'));
        await tap(tester, mode);
        await tap(tester, find.text('Follow up'));
        expect(find.text('Choose a conversation'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await tap(tester, mode);
        await tap(tester, find.text('Run again'));
        expect(
          find.byKey(const ValueKey('scheduled-task-prompt')),
          findsNothing,
        );
        final repeat = find.byKey(const ValueKey('scheduled-task-repeat'));
        await tester.ensureVisible(repeat);
        await tap(tester, repeat);
        await tap(tester, find.text('Custom'));
        expect(
          find.byKey(const ValueKey('scheduled-weekday-1')),
          findsOneWidget,
        );
        await tap(tester, repeat);
        await tap(tester, find.text('Once'));
        expect(find.byKey(const ValueKey('scheduled-weekday-1')), findsNothing);
        expect(find.text('End date'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('desktop dropdown values and multiline content are saved', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpApp(tester);
      await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
      Finder input(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      );
      await tester.enterText(input('scheduled-task-name'), 'Desktop task');
      await tester.enterText(
        input('scheduled-task-prompt'),
        'First line\nSecond line',
      );
      final repeat = find.byKey(const ValueKey('scheduled-task-repeat'));
      await tester.ensureVisible(repeat);
      await tap(tester, repeat);
      await tap(tester, find.text('Weekdays'));
      // SQLite completion is awaited outside the widget test's fake clock.
      final saved = (await tester.runAsync(() async => Completer<void>()))!;
      void onSaved() {
        if (!saved.isCompleted &&
            service.tasks.any((task) => task.name == 'Desktop task')) {
          saved.complete();
        }
      }

      service.addListener(onSaved);
      try {
        await tap(tester, find.byKey(const ValueKey('scheduled-tasks-action')));
        await tester.runAsync(
          () => saved.future.timeout(const Duration(seconds: 5)),
        );
      } finally {
        service.removeListener(onSaved);
      }
      await tester.pumpAndSettle();
      final task = service.tasks.singleWhere(
        (task) => task.name == 'Desktop task',
      );
      expect(task.weekdays, [1, 2, 3, 4, 5]);
      expect(task.prompt, 'First line\nSecond line');
      expect(task.assistantId, assistant.id);
      expect(find.byType(ScheduledTaskEditorPage), findsNothing);
      expect(find.byType(DesktopScheduledTaskTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final width in [1000.0, 1600.0]) {
    testWidgets(
      'task menu stays beside its button in full settings, width=$width',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await pumpApp(
            tester,
            menu: true,
            size: Size(width, 1000),
            inset: const EdgeInsets.only(left: 60, top: 80),
          );
          final entry = find.text('Scheduled tasks');
          await tester.ensureVisible(entry);
          await tap(tester, entry);
          final more = find.byWidgetPredicate(
            (widget) =>
                widget is IosIconButton &&
                widget.semanticLabel == 'More Actions',
          );
          final anchor = tester.getRect(more);
          await tap(tester, more);
          final popup = tester.getRect(
            find
                .ancestor(
                  of: find.text('Run now'),
                  matching: find.byType(IntrinsicWidth),
                )
                .first,
          );
          final expectedLeft = (anchor.left + 8).clamp(
            8.0,
            width - popup.width - 8,
          );
          expect(popup.left, closeTo(expectedLeft, 1));
          expect(popup.top, closeTo(anchor.bottom + 8, 1));
          expect(popup.right, lessThanOrEqualTo(width - 8));
          await tap(tester, find.text('Edit task'));
          expect(find.byType(ScheduledTaskEditorPage), findsOneWidget);
          expect(find.byType(DesktopSettingsPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('desktop settings has a scheduled tasks menu entry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpApp(tester, menu: true);
      final entry = find.text('Scheduled tasks');
      await tester.ensureVisible(entry);
      await tap(tester, entry);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopScheduledTasksPane), findsOneWidget);
      await screenshot(tester, 'desktop-settings-scheduled');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
