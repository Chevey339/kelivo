import 'dart:async';
import '../../../support/compression_options_pump.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart'
    show exportContextNodeText;
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
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
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
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
  test(
    'a summary depending on a pin does not mark the pin superseded in export',
    () {
      final pin = ContextOperation(
        id: 'pin',
        kind: ContextOperationKind.start,
        anchorGroupId: 'u',
        appliedAfterGroupId: 'u',
        sourceGroups: ['u'],
        dependencies: [],
        createdAt: DateTime(2026),
      );
      final exported = exportContextNodeText(
        pin,
        AppLocalizationsEn(),
        markdown: true,
        operations: [
          pin,
          op.copyWith(dependencies: [pin.id]),
        ],
      );
      expect(exported, contains(AppLocalizationsEn().contextOperationActive));
      expect(
        exported,
        isNot(contains(AppLocalizationsEn().contextOperationSuperseded)),
      );
    },
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

  check('compression settings paint while metadata is pending', (tester) async {
    await prepare(tester, TargetPlatform.macOS);
    final history = Completer<CompressionHistory>();
    await tester.pumpWidget(
      app(CompressContextOptionsDialog(loadHistory: () => history.future)),
    );
    await tester.pump();
    expect(find.text(AppLocalizationsEn().contextLogLoading), findsOneWidget);
    expect(
      tester.widget<FormSheetActions>(find.byType(FormSheetActions)).onConfirm,
      isNull,
    );
    history.complete(
      CompressionHistory.fromMessages([
        for (var i = 0; i < 10; i++)
          ChatMessage(
            id: 'u$i',
            role: 'user',
            content: 'Turn $i',
            conversationId: 'chat',
          ),
      ], const []),
    );
    await settleCompressionOptions(tester);
    expect(
      tester.widget<FormSheetActions>(find.byType(FormSheetActions)).onConfirm,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  check(
    'compression preview coalesces edits and waits for the running request',
    (tester) async {
      await prepare(tester, TargetPlatform.macOS);
      final requests = <CompressContextOptions>[];
      final pending = <Completer<CompressionRequestPreview>>[];
      await tester.pumpWidget(
        app(
          CompressContextOptionsDialog(
            loadHistory: () async => CompressionHistory.fromMessages([
              for (var i = 0; i < 20; i++)
                ChatMessage(
                  id: 'u$i',
                  role: 'user',
                  content: 'Turn $i',
                  conversationId: 'chat',
                ),
            ], const []),
            previewRequest: (options, _) {
              requests.add(options);
              final completer = Completer<CompressionRequestPreview>();
              pending.add(completer);
              return completer.future;
            },
          ),
        ),
      );
      await settleCompressionOptions(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, hasLength(1));
      final field = find.descendant(
        of: find.widgetWithText(IosFormTextField, 'Keep recent'),
        matching: find.byType(TextField),
      );
      for (final value in ['2', '3']) {
        await tester.enterText(field, value);
        await settleCompressionOptions(tester);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(requests, hasLength(1));
      pending.first.complete((
        prompt: 'old',
        estimatedRequests: 99,
        maxRequestAttempts: 1,
      ));
      await tester.pump();
      expect(requests, hasLength(2));
      expect(requests.last.keepUserMessages, 3);
      pending.last.complete((
        prompt: 'latest',
        estimatedRequests: 1,
        maxRequestAttempts: 1,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  check('explicit preview explains invalid numeric settings', (tester) async {
    await prepare(tester, TargetPlatform.macOS);
    final l10n = AppLocalizationsEn();
    await tester.pumpWidget(
      app(
        CompressContextOptionsDialog(
          loadHistory: () async => CompressionHistory.fromMessages([
            for (var i = 0; i < 10; i++)
              ChatMessage(
                id: 'u$i',
                role: 'user',
                content: 'Turn $i',
                conversationId: 'chat',
              ),
          ], const []),
          previewRequest: (_, _) async =>
              (prompt: 'Preview', estimatedRequests: 1, maxRequestAttempts: 1),
        ),
      ),
    );
    await settleCompressionOptions(tester);
    await tester.ensureVisible(find.text('More settings'));
    await tester.tap(find.text('More settings'));
    await settleCompressionOptions(tester);
    final field = find.descendant(
      of: find.widgetWithText(IosFormTextField, l10n.compressionLength),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, '');
    final preview = find.text(l10n.compressionPreviewAction);
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pump();
    expect(find.text(l10n.compressionInvalidSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  check('automatic and explicit previews retain unknown error details', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.macOS);
    final l10n = AppLocalizationsEn();
    final failure = StateError('preview_read_failed: disk I/O error');
    await tester.pumpWidget(
      app(
        CompressContextOptionsDialog(
          loadHistory: () async => CompressionHistory.fromMessages([
            for (var i = 0; i < 10; i++)
              ChatMessage(
                id: 'u$i',
                role: 'user',
                content: 'Turn $i',
                conversationId: 'chat',
              ),
          ], const []),
          previewRequest: (_, _) async => throw failure,
        ),
      ),
    );
    await settleCompressionOptions(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    Future<void> viewDetails() async {
      final show = find.text(l10n.startupRecoveryShowDetails);
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      final raw = find.text(failure.toString());
      await tester.ensureVisible(raw);
      expect(raw.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await viewDetails();
    await tester.ensureVisible(find.text(l10n.compressionMore));
    await tester.tap(find.text(l10n.compressionMore));
    await settleCompressionOptions(tester);
    await tester.ensureVisible(find.text(l10n.compressionPreviewAction));
    await tester.tap(find.text(l10n.compressionPreviewAction));
    await tester.pumpAndSettle();
    await viewDetails();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    check(
      'imported native details have source navigation but no undo on $platform',
      (tester) async {
        await prepare(tester, platform);
        final l10n = AppLocalizationsEn();
        var opened = false;
        final imported = op
            .copyWith(
              summary: '',
              originalSummary: '',
              compressionDetails: {
                'nativeCompaction': NativeCompactionPayload(
                  protocol: NativeCompactionProtocol.compact,
                  scope: 'fixture',
                  modelId: 'private',
                  output: [
                    {'type': 'compaction', 'encrypted_content': 'opaque'},
                  ],
                ).toJson(),
              },
            )
            .copiedTo(
              ChatMessage(
                id: 'seed',
                conversationId: 'target',
                role: 'user',
                content: '',
              ),
              keepUserMessages: 1,
              sourceConversationId: 'source',
            );
        await tester.pumpWidget(
          app(
            ContextOperationContent(
              operation: imported,
              onClose: () {},
              onUndo: () async => true,
              onViewOriginal: () => opened = true,
            ),
          ),
        );
        expect(
          find.text(l10n.compressionNativeImportedDescription),
          findsOneWidget,
        );
        expect(find.text(l10n.contextUndoCompressTooltip), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('context-summary-details-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.contextDetailAfterUndo), findsNothing);
        expect(find.text(l10n.contextDetailReplaced), findsNothing);
        await tester.tap(
          platform == TargetPlatform.macOS
              ? find.byIcon(LucideIcons.ellipsis)
              : find.text(l10n.contextMore),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.compressionNativeOpenSource));
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        await tester.pumpWidget(
          app(
            ContextOperationContent(
              operation: imported,
              onClose: () {},
              sourceConversationAvailable: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.compressionNativeSourceUnavailable),
          findsOneWidget,
        );
        expect(
          find.text(l10n.compressionNativeImportedDescription),
          findsNothing,
        );
        expect(find.text(l10n.compressionNativeOpenSource), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    check(
      'native details expose undo and metadata but no text editor on $platform',
      (tester) async {
        await prepare(tester, platform);
        var undone = false;
        final native = op.copyWith(
          summary: '',
          compressionDetails: {
            'nativeCompaction': NativeCompactionPayload(
              protocol: NativeCompactionProtocol.compact,
              scope: 'fixture',
              modelId: 'private',
              output: [
                {
                  'type': 'compaction',
                  'encrypted_content': 'never display this',
                },
              ],
            ).toJson(),
          },
        );
        await tester.pumpWidget(
          app(
            ContextOperationContent(
              operation: native,
              initiallyEditing: true,
              rangeLabel: '1–10',
              onClose: () {},
              onUndo: () async {
                undone = true;
                return true;
              },
            ),
          ),
        );
        final l10n = AppLocalizationsEn();
        expect(find.text(l10n.compressionNativeDescription), findsOneWidget);
        expect(find.text(l10n.assistantSettingsCopyButton), findsNothing);
        expect(find.text(l10n.assistantSettingsEditButton), findsNothing);
        expect(find.text('never display this'), findsNothing);
        expect(
          find.byKey(const ValueKey('context-summary-content')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('context-summary-details-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1–10'), findsOneWidget);
        await tester.tap(find.text(l10n.contextUndoCompressTooltip));
        await tester.pumpAndSettle();
        expect(undone, isTrue);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    check(
      'fixed start divider identifies the pin and opens details on $platform',
      (tester) async {
        await prepare(tester, platform);
        var opened = 0;
        await tester.pumpWidget(
          app(
            ContextOperationDivider(
              operation: ContextOperation(
                id: 'pin',
                kind: ContextOperationKind.start,
                anchorGroupId: 'u',
                appliedAfterGroupId: 'u',
                sourceGroups: ['u'],
                dependencies: [],
                createdAt: DateTime(2026),
              ),
              onOpen: () => opened++,
            ),
          ),
        );
        expect(find.text('Fixed context start'), findsOneWidget);
        expect(find.text('Context cleared'), findsNothing);
        await tester.tap(find.text('Fixed context start'));
        await tester.pump();
        expect(opened, 1);
      },
    );
  }

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

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    for (final failure in [
      'context_budget_exceeded',
      'SQLITE_FULL: database or disk is full',
    ]) {
      check('summary save failure $failure preserves edits on $platform', (
        tester,
      ) async {
        await prepare(tester, platform);
        var closed = 0;
        final saved = <String>[];
        await tester.pumpWidget(
          app(
            ContextDialog(
              maxWidth: 560,
              child: ContextOperationContent(
                operation: op,
                onClose: () => closed++,
                onSave: (summary) async {
                  saved.add(summary);
                  if (saved.length == 1) {
                    throw StateError(failure);
                  }
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'over budget draft');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            failure == 'context_budget_exceeded'
                ? AppLocalizationsEn().compressOverSnack
                : AppLocalizationsEn().compressContextFailed,
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'over budget draft',
        );
        expect(closed, 0);
        final details = find.text(
          AppLocalizationsEn().startupRecoveryShowDetails,
        );
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        final raw = find.text(StateError(failure).toString());
        await tester.ensureVisible(raw);
        expect(raw.hitTestable(), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'shorter draft');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(saved, ['over budget draft', 'shorter draft']);
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

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

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    check(
      'summary details fold and long text uses one reading scroll on $platform',
      (tester) async {
        await prepare(tester, platform);
        var undos = 0;
        final summary = [
          for (var i = 0; i < 30; i++)
            'Summary paragraph $i. Keep the decisions, constraints and next steps.',
          'Final summary paragraph.',
        ].join('\n\n');
        await tester.pumpWidget(
          app(
            ContextDialog(
              maxWidth: 560,
              child: ContextOperationContent(
                operation: op.copyWith(summary: summary),
                onClose: () {},
                onSave: (_) async => true,
                onUndo: () async {
                  undos++;
                  return false;
                },
                rangeLabel: 'Messages 1–10',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(
          const ValueKey('context-summary-details-toggle'),
        );
        expect(find.byType(ContextDetailRow), findsNothing);
        expect(find.text('Copy').hitTestable(), findsOneWidget);
        expect(find.text('Edit').hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Messages 1–10'), findsOneWidget);
        expect(find.byType(ContextDetailRow), findsWidgets);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byType(ContextDetailRow), findsNothing);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          greaterThan(0),
        );
        final endNote = find.text(
          AppLocalizationsEn().compressIncludeAttachmentsDesc,
        );
        await tester.scrollUntilVisible(
          endNote,
          260,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(endNote.hitTestable(), findsOneWidget);
        await tester.tap(
          find.text(AppLocalizationsEn().contextUndoCompressTooltip),
        );
        await tester.pumpAndSettle();
        expect(undos, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    expect(find.text('Compression didn’t finish'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    for (final state in [
      CompressionPhase.cancelled,
      CompressionPhase.completed,
    ]) {
      task.phase = state;
      await pump();
      expect(find.byType(Divider), findsNothing);
    }
    task.phase = CompressionPhase.failed;
    task.error = 'context_changed';
    await pump();
    expect(find.text('Compression didn’t finish'), findsOneWidget);
    task.phase = CompressionPhase.review;
    await pump();
    expect(
      find.text('Please review the summary before using it.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(LucideIcons.pause), findsOneWidget);
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
            loadHistory: () async =>
                CompressionHistory.fromMessages(messages, const []),
          ),
        ),
      );
      await settleCompressionOptions(tester);
      final start = find.byType(FormSheetActions);
      expect(tester.widget<FormSheetActions>(start).onConfirm, isNull);
      expect(find.byType(IosSwitch), findsNWidgets(2));
      expect(
        tester.widget<IosSwitch>(find.byType(IosSwitch).first).value,
        isFalse,
      );
      final field = find.descendant(
        of: find.widgetWithText(IosFormTextField, 'Keep recent'),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, '1');
      await tester.ensureVisible(find.text('More settings'));
      await tester.tap(find.text('More settings'));
      await settleCompressionOptions(tester);
      expect(tester.widget<SegmentedTabs>(find.byType(SegmentedTabs)).index, 0);
      expect(field, findsNothing);
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await settleCompressionOptions(tester);
      expect(tester.widget<FormSheetActions>(start).onConfirm, isNotNull);
      expect(
        find.text('Summarize 3 messages · keep 1 user turns verbatim'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    check('manual scope exposes only applicable inputs on $platform', (
      tester,
    ) async {
      await prepare(tester, platform);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('haptic_feedback'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          null,
        ),
      );
      CompressContextOptions? selected;
      final messages = [
        for (var i = 0; i < 12; i++)
          ChatMessage(
            id: 'm$i',
            conversationId: 'chat',
            role: i.isEven ? 'user' : 'assistant',
            content: 'body $i',
          ),
      ];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showCompressContextOptions(
                  context: context,
                  builder: (sheet) => CompressContextOptionsDialog(
                    loadHistory: () async =>
                        CompressionHistory.fromMessages(messages, const []),

                    sheet: sheet,
                  ),
                );
              },
              child: const Text('open range options'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open range options'));
      await settleCompressionOptions(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CompressContextOptionsDialog)),
      )!;
      Finder field(String label) => find.descendant(
        of: find.widgetWithText(IosFormTextField, label),
        matching: find.byType(TextField),
      );
      final keep = field(l10n.compressionKeepTurns);
      final maxChars = field(l10n.compressContextMaxCharsLabel);
      final scope = find.byType(
        DesktopSelectDropdown<CompressContextLimitMode>,
      );
      Future<void> choose(String label) async {
        await tester.ensureVisible(scope);
        await settleCompressionOptions(tester);
        await tester.tap(scope);
        await settleCompressionOptions(tester);
        await tester.ensureVisible(find.text(label).last);
        await settleCompressionOptions(tester);
        await tester.tap(find.text(label).last);
        await settleCompressionOptions(tester);
      }

      expect(scope, findsOneWidget);
      await tester.ensureVisible(keep);
      await tester.enterText(keep, '2');
      await settleCompressionOptions(tester);
      expect(find.text(l10n.compressionRange(8, 2)), findsOneWidget);
      await choose(l10n.compressContextUnlimited);
      expect(keep, findsNothing);
      expect(maxChars, findsNothing);
      expect(find.text(l10n.compressionScopeAllHint), findsOneWidget);
      expect(find.text(l10n.compressionRange(12, 0)), findsOneWidget);
      await choose(l10n.compressContextKeepStart);
      expect(keep, findsNothing);
      await tester.ensureVisible(maxChars);
      await tester.enterText(maxChars, '10');
      await choose(l10n.compressContextKeepRecent);
      expect(keep, findsNothing);
      expect(tester.widget<TextField>(maxChars).controller!.text, '10');
      await choose(l10n.compressContextKeepRecentMessages);
      expect(tester.widget<TextField>(keep).controller!.text, '2');
      expect(maxChars, findsNothing);
      await choose(l10n.compressContextUnlimited);
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      expect(scope, findsNothing);
      expect(keep, findsNothing);
      await tester.ensureVisible(find.text(l10n.compressionAutoOn));
      await tester.tap(find.text(l10n.compressionAutoOn));
      await settleCompressionOptions(tester);
      expect(tester.widget<TextField>(keep).controller!.text, '2');
      expect(find.text(l10n.compressionAutoKeepHint), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.compressionAutoOff));
      await tester.tap(find.text(l10n.compressionAutoOff));
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await settleCompressionOptions(tester);
      expect(
        tester
            .widget<DesktopSelectDropdown<CompressContextLimitMode>>(scope)
            .value,
        CompressContextLimitMode.unlimited,
      );
      expect(keep, findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(FormSheetActions),
          matching: find.text(l10n.compressContextStartButton),
        ),
      );
      for (var i = 0; i < 100 && selected == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await settleCompressionOptions(tester);
      expect(selected!.mode, CompressContextLimitMode.unlimited);
      expect(selected!.keepUserMessages, isNull);
      expect(selected!.maxChars, isNull);
      expect(settings.compressionDefaults.keepRecentUserTurns, 2);
      expect(settings.compressLimitMode, CompressContextLimitMode.unlimited);
      await tester.tap(find.text('open range options'));
      await settleCompressionOptions(tester);
      expect(
        tester
            .widget<DesktopSelectDropdown<CompressContextLimitMode>>(scope)
            .value,
        CompressContextLimitMode.unlimited,
      );
      expect(keep, findsNothing);

      // Cancel discards a draft range instead of changing the next default.
      await choose(l10n.compressContextKeepRecentMessages);
      await tester.tap(find.text(l10n.homePageCancel));
      await settleCompressionOptions(tester);
      expect(settings.compressLimitMode, CompressContextLimitMode.unlimited);
      await tester.tap(find.text('open range options'));
      await settleCompressionOptions(tester);

      // Save settings without running compression, including its character budget.
      await choose(l10n.compressContextKeepRecent);
      await tester.enterText(maxChars, '12000');
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      await tester.tap(find.text(l10n.multiKeyPageSave));
      for (var i = 0; i < 100 && scope.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await settleCompressionOptions(tester);
      expect(scope, findsOneWidget);
      expect(settings.compressLimitMode, CompressContextLimitMode.recent);
      expect(settings.compressMaxChars, 12000);
      await tester.tap(find.text(l10n.homePageCancel));
      await settleCompressionOptions(tester);
      await tester.tap(find.text('open range options'));
      await settleCompressionOptions(tester);
      expect(
        tester
            .widget<DesktopSelectDropdown<CompressContextLimitMode>>(scope)
            .value,
        CompressContextLimitMode.recent,
      );
      expect(tester.widget<TextField>(maxChars).controller!.text, '12000');

      // Explicit global defaults and restoring them include the manual range.
      await choose(l10n.compressContextKeepStart);
      await tester.enterText(maxChars, '18000');
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      await tester.ensureVisible(find.text(l10n.compressionAdvancedOptions));
      await tester.tap(find.text(l10n.compressionAdvancedOptions));
      await settleCompressionOptions(tester);
      await tester.ensureVisible(find.text(l10n.compressionSetGlobal));
      await tester.tap(find.text(l10n.compressionSetGlobal));
      for (var i = 0; i < 100 && settings.compressMaxChars != 18000; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(settings.compressLimitMode, CompressContextLimitMode.start);
      expect(settings.compressMaxChars, 18000);
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await settleCompressionOptions(tester);
      await choose(l10n.compressContextUnlimited);
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      await tester.ensureVisible(find.text(l10n.compressionFollowGlobal));
      await tester.tap(find.text(l10n.compressionFollowGlobal));
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await settleCompressionOptions(tester);
      expect(
        tester
            .widget<DesktopSelectDropdown<CompressContextLimitMode>>(scope)
            .value,
        CompressContextLimitMode.start,
      );
      expect(tester.widget<TextField>(maxChars).controller!.text, '18000');
      expect(tester.takeException(), isNull);
    });
  }

  check('new-chat compression option is returned and remembered', (
    tester,
  ) async {
    await prepare(tester, TargetPlatform.android);
    CompressContextOptions? selected;
    final messages = [
      for (var i = 0; i < 8; i++)
        ChatMessage(
          id: 'u$i',
          conversationId: 'chat',
          role: 'user',
          content: 'history $i',
        ),
    ];
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showDialog<CompressContextOptions>(
                context: context,
                builder: (_) => CompressContextOptionsDialog(
                  loadHistory: () async =>
                      CompressionHistory.fromMessages(messages, const []),
                ),
              );
            },
            child: const Text('open options'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open options'));
    await settleCompressionOptions(tester);
    final newChat = find.byWidgetPredicate(
      (w) => w is IosSwitch && w.semanticLabel == 'Compress into a new chat',
    );
    await tester.ensureVisible(newChat);
    await tester.tap(newChat);
    await settleCompressionOptions(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FormSheetActions),
        matching: find.text('Compress into a new chat'),
      ),
    );
    for (var i = 0; i < 200 && selected == null; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await settleCompressionOptions(tester);
    expect(selected!.newConversation, isTrue);
    expect(settings.compressNewConversation, isTrue);
    await tester.tap(find.text('open options'));
    await settleCompressionOptions(tester);
    expect(tester.widget<IosSwitch>(newChat).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final kind in ContextOperationKind.values) {
    check('boundary navigation uses the operation kind: $kind', (tester) async {
      await prepare(tester, TargetPlatform.android);
      var jumps = 0;
      final l10n = AppLocalizationsEn();
      await tester.pumpWidget(
        app(
          ContextOperationContent(
            operation: ContextOperation(
              id: op.id,
              kind: kind,
              anchorGroupId: op.anchorGroupId,
              appliedAfterGroupId: op.appliedAfterGroupId,
              sourceGroups: op.sourceGroups,
              dependencies: op.dependencies,
              createdAt: op.createdAt,
              summary: op.summary,
            ),
            onClose: () {},
            onViewBoundary: () => jumps++,
          ),
        ),
      );
      await tester.tap(find.text(l10n.contextMore));
      await tester.pumpAndSettle();
      final label = kind == ContextOperationKind.clear
          ? l10n.contextViewBoundary
          : l10n.quoteJumpToSource;
      expect(
        find.text(
          kind == ContextOperationKind.clear
              ? l10n.quoteJumpToSource
              : l10n.contextViewBoundary,
        ),
        findsNothing,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(jumps, 1);
    });
  }

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
        await tester.tap(
          find.byKey(const ValueKey('context-summary-details-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ContextDetailRow), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
