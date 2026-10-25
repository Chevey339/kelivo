import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/context_compression_task.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_widgets.dart';
import 'package:Kelivo/features/chat/widgets/context_dialog.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/features/chat/pages/context_summary_editor_page.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../../support/business_test_harness.dart';

void check(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  final op = ContextOperation(
    id: 'summary',
    kind: ContextOperationKind.compress,
    anchorGroupId: 'a',
    appliedAfterGroupId: 'b',
    sourceGroups: const ['u', 'a'],
    dependencies: const [],
    createdAt: DateTime(2026),
    summary: 'Actual request summary',
    originalSummary: 'Actual request summary',
    keepUserMessages: 6,
  );
  late SettingsProvider settings;
  late AssistantProvider assistants;
  Future<void> prepare(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.runAsync(() async {
      settings = SettingsProvider(createBusinessTestPreferences());
      assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      await Future.wait([settings.loaded, assistants.loaded]);
    });
    addTearDown(settings.dispose);
    addTearDown(assistants.dispose);
  }

  Widget app(
    Widget child, {
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: assistants),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: brightness == Brightness.light
          ? buildLightTheme(null)
          : buildDarkTheme(null),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );

  check(
    'desktop undo appears on hover and keyboard focus without opening details',
    (tester) async {
      await prepare(tester, TargetPlatform.macOS);
      var opens = 0, undos = 0;
      await tester.pumpWidget(
        app(
          Center(
            child: SizedBox(
              width: 560,
              child: ContextOperationDivider(
                operation: op,
                onOpen: () => opens++,
                onUndo: () => undos++,
              ),
            ),
          ),
        ),
      );
      final undo = find.byKey(const ValueKey('undo-context-summary'));
      expect(undo, findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Context compressed')));
      await tester.pump();
      expect(undo, findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(undo, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(undo, findsOneWidget);
      expect(find.byTooltip('Undo this compression'), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      expect(undos, 1);
      expect(opens, 0);
      await tester.tap(find.text('Context compressed'));
      await tester.pump();
      expect(opens, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  check('mobile divider has direct undo and editing uses a full screen page', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.android);
    var opens = 0, closed = 0, undos = 0;
    final saves = <String>[];
    await tester.pumpWidget(
      app(
        Column(
          children: [
            ContextOperationDivider(
              operation: op,
              onOpen: () => opens++,
              onUndo: () => undos++,
            ),
            Expanded(
              child: ContextOperationContent(
                operation: op,
                showHeader: false,
                onClose: () => closed++,
                onSave: (value) async {
                  saves.add(value);
                  return true;
                },
              ),
            ),
          ],
        ),
      ),
    );
    final undo = find.byKey(const ValueKey('undo-context-summary'));
    expect(undo, findsOneWidget);
    await tester.tap(undo);
    expect(undos, 1);
    expect(opens, 0);
    await tester.tap(find.text('Context compressed'));
    expect(opens, 1);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(ContextSummaryEditorPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unsaved');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saves, isEmpty);
    expect(find.byType(ContextSummaryEditorPage), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<IosTextButton>(find.widgetWithText(IosTextButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'edited decision');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves, ['edited decision']);
    expect(closed, 1);
    expect(tester.takeException(), isNull);
  });

  check('desktop edits are explicit and empty summaries disable save', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.macOS);
    final saves = <String>[];
    await tester.pumpWidget(
      app(
        ContextDialog(
          maxWidth: 560,
          child: ContextOperationContent(
            operation: op,
            onClose: () {},
            onSave: (value) async {
              saves.add(value);
              return false;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.byType(ContextSummaryEditorPage), findsNothing);
    await tester.enterText(find.byType(TextField), 'unsaved');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(saves, isEmpty);
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<ContextDialogActionButton>(
            find.widgetWithText(ContextDialogActionButton, 'Save'),
          )
          .onTap,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'edited decision');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves, ['edited decision']);
    expect(tester.takeException(), isNull);
  });

  check('task states share one divider and terminal notices leave no line', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.macOS);
    final task = ContextCompressionTask(
      id: 'job',
      conversationId: 'chat',
      options: const CompressContextOptions(
        mode: CompressContextLimitMode.unlimited,
      ),
      phase: CompressionPhase.summarizing,
    );
    Future<void> pump() => tester.pumpWidget(
      app(
        Center(
          child: SizedBox(
            width: 560,
            child: ContextOperationDivider.task(task: task, onOpen: () {}),
          ),
        ),
      ),
    );
    await pump();
    expect(find.text('Compressing context'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing);
    task.phase = CompressionPhase.failed;
    task.error = 'Network interrupted';
    await pump();
    expect(find.text('Compression failed'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    for (final state in [
      CompressionPhase.cancelled,
      CompressionPhase.review,
      CompressionPhase.completed,
    ]) {
      task.phase = state;
      await pump();
      expect(find.byType(Divider), findsNothing);
    }
    task.phase = CompressionPhase.failed;
    task.error = 'context_changed';
    await pump();
    expect(find.byType(Divider), findsNothing);
  });

  check(
    'short history disables compression and advanced inputs start collapsed',
    (tester) async {
      await prepare(tester, TargetPlatform.macOS);
      final messages = [
        for (var i = 0; i < 4; i++)
          ChatMessage(
            id: 'u$i',
            conversationId: 'chat',
            role: 'user',
            content: 'message $i',
          ),
      ];
      await tester.pumpWidget(
        app(
          CompressContextOptionsDialog(
            messages: messages,
            operations: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.widgetWithText(ContextDialogActionButton, 'Compress');
      expect(tester.widget<ContextDialogActionButton>(start).onTap, isNull);
      expect(find.byType(IosSwitch), findsNothing);
      await tester.ensureVisible(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IosSwitch>(find.byType(IosSwitch).first).value,
        isFalse,
      );
      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();
      expect(tester.widget<ContextDialogActionButton>(start).onTap, isNotNull);
      expect(find.text('Summary input'), findsOneWidget);
      expect(find.text('Est. summary'), findsOneWidget);
      expect(find.text('Next request'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 440), const Size(1000, 720)]) {
      check('details fit $size in $brightness with large text', (tester) async {
        await prepare(
          tester,
          size.width < 600 ? TargetPlatform.android : TargetPlatform.macOS,
        );
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          app(
            ContextDialog(
              maxWidth: 560,
              child: ContextOperationContent(
                operation: op,
                onClose: () {},
                onSave: (_) async => true,
                onUndo: () async => true,
                budget: (usedTokens: 3200, contextWindow: 4000),
                undoBudget: (usedTokens: 18000, contextWindow: 4000),
              ),
            ),
            brightness: brightness,
            scale: 1.4,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
