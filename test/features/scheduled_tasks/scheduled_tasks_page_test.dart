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
  setUp(() async {
    settings = SettingsProvider(
      (await createBusinessTestHarness()).preferences,
    );
    await settings.loaded;
    permission = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {
            'exactAlarms': permission,
            'tasks': [
              jsonEncode({
                ...task.toJson(),
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
    await tester.pumpWidget(app(ScheduledTasksPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    await tester.tap(find.byType(IosSwitch));
    await tester.pumpAndSettle();
    expect(
      (calls.lastWhere((c) => c.method == 'save').arguments as Map)['enabled'],
      false,
    );
    await tester.tap(find.text('Morning briefing'));
    await tester.pumpAndSettle();
    expect(find.text('Run now'), findsOneWidget);
    await tester.tap(find.text('Run now'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'runNow'), isTrue);
  });

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

  testWidgets(
    'editor validates time and saves the selected assistant and days',
    (tester) async {
      ScheduledTask? saved;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: ScheduledTaskEditor(
                assistants: const [
                  Assistant(id: 'assistant', name: 'Daily assistant'),
                ],
                initialAssistantId: 'assistant',
                onSave: (task) async {
                  saved = task;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
        of: find.widgetWithText(IosFormTextField, label),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('Name'), 'Morning briefing');
      await tester.enterText(field('Prompt'), 'Summarize my day');
      await tester.enterText(field('Time'), '25:10');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('valid time'), findsOneWidget);
      await tester.enterText(field('Time'), '07:35');
      await tester.tap(find.text('Sat'));
      await tester.tap(find.text('Sun'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.assistantId, 'assistant');
      expect(saved?.weekdays, [1, 2, 3, 4, 5]);
      expect(saved?.hour, 7);
      expect(saved?.minute, 35);
    },
  );

  for (final dark in [false, true]) {
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
        expect(tester.takeException(), isNull);
      },
    );
  }
}
