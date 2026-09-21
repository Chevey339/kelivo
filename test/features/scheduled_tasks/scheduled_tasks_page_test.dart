import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/foundation.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_task_editor_page.dart';
import 'package:Kelivo/features/scheduled_tasks/widgets/scheduled_tasks_scaffold.dart';
import 'package:Kelivo/features/home/widgets/assistant_avatar.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import 'package:Kelivo/features/scheduled_tasks/pages/scheduled_tasks_page.dart';
import 'package:Kelivo/features/scheduled_tasks/widgets/scheduled_task_tile.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';

void main() {
  const channel = MethodChannel('test.scheduled.ui');
  final calls = <MethodCall>[];
  final task = ScheduledTask(
    id: 'task',
    name: 'Morning briefing',
    prompt: 'Summarize my day',
    assistantId: 'assistant',
    hour: 8,
    minute: 0,
    nextRunAt: DateTime(2026, 9, 12, 8),
  );
  late ScheduledTasksService service;
  late SettingsProvider settings;
  var permission = true;
  var taskEnabled = true;
  setUp(() async {
    settings = SettingsProvider(
      (await createBusinessTestHarness()).preferences,
    );
    await settings.loaded;
    permission = true;
    taskEnabled = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'save') {
            taskEnabled = (call.arguments as Map)['enabled'] as bool;
          }
          return {
            'exactAlarms': permission,
            'tasks': [
              jsonEncode({
                ...task.toJson(enabled: taskEnabled),
                'nextRunAt': task.nextRunAt!.millisecondsSinceEpoch,
              }),
            ],
          };
        });
    service = ScheduledTasksService(channel: channel);
  });
  tearDown(() {
    service.dispose();
    settings.dispose();
  });

  Widget app(Widget child, {bool dark = false}) => ChangeNotifierProvider.value(
    value: settings,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(ThemePalettes.defaultPalette.light),
      darkTheme: buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );

  testWidgets('pause persists the task and details expose real actions', (
    tester,
  ) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      app(
        ScheduledTasksPage(
          service: service,
          requestNotificationsPermission: () async {
            permissionRequests++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    await tester.tap(find.byType(IosSwitch));
    await tester.pumpAndSettle();
    expect(
      (calls.lastWhere((c) => c.method == 'save').arguments as Map)['enabled'],
      false,
    );
    expect(permissionRequests, 0);
    await tester.tap(find.text('Morning briefing'));
    await tester.pumpAndSettle();
    expect(find.text('Run now'), findsOneWidget);
    await tester.tap(find.text('Run now'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'runNow'), isTrue);
    expect(permissionRequests, 1);
  });

  for (final granted in [true, false]) {
    testWidgets('enable waits for notification permission (granted=$granted)', (
      tester,
    ) async {
      taskEnabled = false;
      var permissionRequests = 0;
      final response = Completer<bool>();
      await tester.pumpWidget(
        app(
          ScheduledTasksPage(
            service: service,
            requestNotificationsPermission: () {
              permissionRequests++;
              return response.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IosSwitch));
      await tester.pumpAndSettle();
      expect(permissionRequests, 1);
      expect(calls.where((call) => call.method == 'save'), isEmpty);
      response.complete(granted);
      await tester.pumpAndSettle();
      final saved = calls.singleWhere((call) => call.method == 'save');
      expect((saved.arguments as Map)['enabled'], isTrue);
      expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isTrue);
      // Pausing must not ask for notifications again.
      await tester.tap(find.byType(IosSwitch));
      await tester.pumpAndSettle();
      expect(permissionRequests, 1);
      expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isFalse);
    });
  }

  testWidgets('missing exact alarm access is visible and opens system access', (
    tester,
  ) async {
    permission = false;
    await tester.pumpWidget(app(ScheduledTasksPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for permission'), findsOneWidget);
    await tester.tap(find.text('Alarms & reminders'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'permission'), isTrue);
  });

  testWidgets('editor uses time wheels and repeat presets on a full page', (
    tester,
  ) async {
    ScheduledTask? saved;
    await tester.pumpWidget(
      app(
        ScheduledTaskEditorPage(
          assistants: const [
            Assistant(id: 'assistant', name: 'Daily assistant', avatar: '🌤️'),
          ],
          initialAssistantId: 'assistant',
          onSave: (task) async {
            saved = task;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .widget<AssistantAvatar>(find.byType(AssistantAvatar))
          .assistant
          ?.avatar,
      '🌤️',
    );
    Finder field(String label) => find.descendant(
      of: find.widgetWithText(IosFormTextField, label),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('Name'), 'Morning briefing');
    await tester.ensureVisible(field('Prompt'));
    await tester.enterText(field('Prompt'), 'Summarize my day');
    final timeRow = find.widgetWithText(IosNavRow, 'Time');
    await tester.ensureVisible(timeRow);
    await tester.tap(timeRow);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    final pickers = tester
        .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
        .toList();
    pickers[0].scrollController!.jumpToItem(7);
    pickers[1].scrollController!.jumpToItem(35);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final repeatRow = find.widgetWithText(IosNavRow, 'Repeat');
    await tester.ensureVisible(repeatRow);
    await tester.tap(repeatRow);
    await tester.pumpAndSettle();
    for (final preset in ['Once', 'Every day', 'Weekdays', 'Custom']) {
      expect(find.text(preset), findsWidgets);
    }
    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scheduled-tasks-action')));
    await tester.pumpAndSettle();
    expect(saved?.assistantId, 'assistant');
    expect(saved?.repeat, ScheduledTaskRepeat.weekdays);
    expect(saved?.weekdays, [1, 2, 3, 4, 5]);
    expect(saved?.hour, 7);
    expect(saved?.minute, 35);
  });

  for (final dark in [false, true]) {
    testWidgets('task navigation bar stays transparent (dark=$dark)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      Widget page(Widget child) => app(
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child,
        ),
        dark: dark,
      );
      Map<dynamic, dynamic> style() =>
          platformCalls
                  .lastWhere(
                    (c) => c.method == 'SystemChrome.setSystemUIOverlayStyle',
                  )
                  .arguments
              as Map;
      try {
        // Reset SystemChrome's cached style so this test observes a fresh call.
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(systemNavigationBarColor: Colors.red),
        );
        await tester.pump();
        platformCalls.clear();
        await tester.pumpWidget(
          page(
            Scaffold(
              appBar: AppBar(title: const Text('Settings')),
              body: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          style()['systemNavigationBarColor'],
          Colors.transparent.toARGB32(),
        );
        await tester.pumpWidget(
          page(
            const ScheduledTasksScaffold(
              title: 'Scheduled tasks',
              child: SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          style()['systemNavigationBarColor'],
          Colors.transparent.toARGB32(),
        );
        expect(
          style()['systemNavigationBarDividerColor'],
          Colors.transparent.toARGB32(),
        );
        expect(style()['systemNavigationBarContrastEnforced'], isFalse);
        expect(
          style()['systemNavigationBarIconBrightness'],
          (dark ? Brightness.light : Brightness.dark).toString(),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'task layout stays inside a narrow screen in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(ScheduledTasksPage(service: service), dark: dark),
        );
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byType(ScheduledTaskTile));
        final textContext = tester.element(find.text('08:00'));
        expect(
          DefaultTextStyle.of(textContext).style.fontFamily,
          isNot('monospace'),
        );
        expect(
          DefaultTextStyle.of(textContext).style.decoration,
          isNot(TextDecoration.underline),
        );
        expect(card.left, 16);
        expect(card.right, 304);
        final footer = tester.getRect(
          find.byKey(const ValueKey('scheduled-tasks-description')),
        );
        final background = tester.getRect(
          find.byKey(const ValueKey('scheduled-tasks-background-settings')),
        );
        expect(background.top - footer.bottom, 24);
        final header = tester.getRect(
          find.byKey(const ValueKey('scheduled-tasks-navigation')),
        );
        expect(header.height, kToolbarHeight);
        expect(tester.getTopLeft(find.text('Scheduled tasks')).dx, 72);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
