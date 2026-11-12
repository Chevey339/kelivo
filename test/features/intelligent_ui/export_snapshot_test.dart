import 'package:provider/provider.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import '../../support/business_test_harness.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/export_image_capture.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_export_capture.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_message_projection.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_message_text.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../support/genui_projection_fixture.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$n: number = 2
root = Column(children=[field,total,button])
field = NumberField(label="Amount",bind=$n,unit="kg")
total = Metric(label="Total",value=$n*3)
button = Button(label="Ask",action=Ask(text="Explain",context={"n":$n}))
''';
const _fence = '```kelivo-ui\n$_body```';
ChatMessage message({List<MessagePart>? parts, String content = _fence}) =>
    ChatMessage(
      id: 'r',
      conversationId: 'c',
      role: 'assistant',
      content: content,
      parts: parts,
    )..hydrateGenerationState(GenerationRunState.completed);
Future<UiMessageText> project(
  ChatMessage msg, {
  List<UiSurfaceSnapshot> snapshots = const [],
}) => projectUiMessageText(
  msg,
  projection: testUiProjection,
  snapshots: snapshots,
  blockLimit: 'Block limit',
);

void main() {
  test(
    'TXT replaces split fences once without moving intervening attachments',
    () async {
      const prefix = '**Before**\n\n';
      final cut = _fence.indexOf('root');
      final msg = message(
        parts: [
          TextPart(prefix + _fence.substring(0, cut)),
          TextPart(_fence.substring(cut)),
          const ImagePart(uri: '/tmp/image.png'),
          const FilePart(
            uri: '/tmp/file.txt',
            name: 'file.txt',
            mime: 'text/plain',
          ),
          const TextPart('\n\n**After**'),
        ],
      );
      final frozen = await project(msg);
      final text = await exportMessageBlocksForTesting(
        msg,
        showThinkingAndToolCards: false,
        uiText: frozen,
      );
      expect(text, contains('Amount: 2 kg'));
      expect(text, contains('Total: 6'));
      expect('Amount:'.allMatches(text).length, 1);
      expect(text, isNot(contains('root =')));
      expect(text, isNot(contains('**Before**')));
      expect(text.indexOf('Before'), lessThan(text.indexOf('Amount:')));
      expect(text.indexOf('Total:'), lessThan(text.indexOf('/tmp/image.png')));
      expect(
        text.indexOf('/tmp/image.png'),
        lessThan(text.indexOf('file.txt')),
      );
      expect(text.indexOf('file.txt'), lessThan(text.indexOf('After')));
      expect(msg.parts.length, 5);
    },
  );
  test(
    'Markdown includes frozen semantic text and exactly the original DSL',
    () async {
      final live =
          UiSurfaceController(
            owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
          )..updateSource(
            _body,
            closed: true,
            generation: UiGenerationStatus.complete,
          );
      addTearDown(live.dispose);
      live.setInputs({'n': 7}, token: live.token);
      final msg = message();
      final frozen = await project(msg, snapshots: [live.captureSnapshot()]);
      live.setInputs({'n': 9}, token: live.token);
      final md = await exportMessageBlocksForTesting(
        msg,
        showThinkingAndToolCards: false,
        uiText: frozen,
        markdown: true,
      );
      expect(md, contains('Amount: 7 kg'));
      expect(md, contains('Total: 21'));
      expect(md, isNot(contains('Total: 27')));
      expect('```kelivo-ui'.allMatches(md).length, 1);
      expect(md, contains(_fence));
      final readonly = frozen.surfaces.single.createController();
      expect(readonly.readOnly, isTrue);
      expect(readonly.captureRead().inputs['n'], 7);
      readonly.dispose();
      expect(live.captureRead().inputs['n'], 9);
    },
  );
  test(
    'literal think tags survive export while original reasoning stays hidden',
    () async {
      const literal =
          '<think>Visible UI</think> ``` [x](https://example.invalid)';
      final source =
          'ui 1 catalog "kelivo.native/1"\nroot = Text(text=${jsonEncode(literal)})\n';
      final msg = message(
        content: '<think>PRIVATE</think>\n\n```kelivo-ui\n$source```',
      );
      final captured = await project(msg);
      final txt = await exportMessageBlocksForTesting(
        msg,
        showThinkingAndToolCards: false,
        uiText: captured,
      );
      expect(txt, contains(literal));
      expect(txt, isNot(contains('PRIVATE')));
      final md = await exportMessageBlocksForTesting(
        msg,
        showThinkingAndToolCards: false,
        uiText: captured,
        markdown: true,
      );
      expect(md, contains('````text\n$literal\n````'));
      expect(md, isNot(contains('PRIVATE')));
    },
  );
  test('image preparation preserves original source part ordinals', () {
    final msg = message(
      parts: [const ReasoningPart('private'), const TextPart(_fence)],
    );
    final imageMessage = messageForThinkingExport(
      msg,
      showThinkingAndToolCards: false,
    );
    expect(imageMessage, same(msg));
    expect(imageMessage.parts[1], isA<TextPart>());
  });
  test('16 MP is inclusive and uses rounded requested output dimensions', () {
    expect(
      () => checkExportPixelBudget(
        const Size(4000, 4000),
        1,
        UiBudgets.exportPixels,
      ),
      returnsNormally,
    );
    expect(
      () => checkExportPixelBudget(
        const Size(4000.01, 4000),
        1,
        UiBudgets.exportPixels,
      ),
      throwsA(isA<ExportImageTooLarge>()),
    );
    expect(
      () => checkExportPixelBudget(
        const Size(2000, 2000),
        3,
        UiBudgets.exportPixels,
      ),
      throwsA(isA<ExportImageTooLarge>()),
    );
  });
  testWidgets(
    'over-budget capture rejects before any capture or processing stage',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final stages = <ExportImageProgress>[];
      Object? failure;
      var done = false;
      unawaited(
        captureExportWidget(
              context,
              const SizedBox(height: 2000),
              theme: ThemeData(),
              width: 2000,
              maxPixels: UiBudgets.exportPixels,
              onProgress: stages.add,
            )
            .then<void>(
              (_) => fail('must reject before raster allocation'),
              onError: (Object error) {
                failure = error;
              },
            )
            .whenComplete(() => done = true),
      );
      for (var i = 0; i < 100 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done, isTrue);
      expect(failure, isA<ExportImageTooLarge>());
      expect(stages.map((s) => s.stage), [ExportImageStage.preparing]);
      await tester.pump();
      expect(find.byType(OverflowBox), findsNothing);
    },
  );
  testWidgets(
    'capture freezes parts and generation before storage publishes live metadata',
    (tester) async {
      final registry = UiRuntimeRegistry();
      addTearDown(registry.dispose);
      final msg = message();
      final live = registry
          .obtain('c', const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'))
          .controller;
      live.updateSource(
        _body,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      live.setInputs({'n': 7}, token: live.token);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UiRuntimeScope(
            registry: registry,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final pending = captureUiExportMessages(context, [msg]);
      msg.prepareStorageParts([
        const ReasoningPart('new reasoning'),
        ...msg.parts,
      ])();
      msg.hydrateGenerationState(GenerationRunState.interrupted);
      live.setInputs({'n': 9}, token: live.token);
      final capture = await pending;
      expect(capture.messages.single, isNot(same(msg)));
      expect(capture.messages.single.parts, hasLength(1));
      expect(
        capture.messages.single.generationState,
        GenerationRunState.completed,
      );
      expect(msg.parts, hasLength(2));
      expect(msg.generationState, GenerationRunState.interrupted);
      final projection = capture.projections['r']!;
      expect(projection.surfaces.single.owner.surfaceKey, '0:0');
      final text = await exportMessageBlocksForTesting(
        capture.messages.single,
        showThinkingAndToolCards: false,
        uiText: projection,
      );
      expect(text, contains('Total: 21'));
      expect(text, isNot(contains('Total: 27')));
      expect(text, isNot(contains('new reasoning')));
      final readonly = projection.surfaces.single.createController();
      expect(readonly.captureRead().inputs['n'], 7);
      readonly.dispose();
    },
  );
  testWidgets('frozen image fields have no input clients or action buttons', (
    tester,
  ) async {
    final live =
        UiSurfaceController(
          owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
        )..updateSource(
          _body,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
    addTearDown(live.dispose);
    live.setInputs({'n': 7}, token: live.token);
    final msg = message();
    final frozen = await project(msg, snapshots: [live.captureSnapshot()]);
    live.setInputs({'n': 9}, token: live.token);
    late UiSurfaceController exported;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UiExportSnapshotScope(
            captures: UiExportCapture(
              messages: [msg],
              projections: {'r': frozen},
            ),
            child: Builder(
              builder: (context) {
                exported = UiRuntimeScope.maybeOf(
                  context,
                )!.obtain('c', live.owner).controller;
                return GenUiSurface(controller: exported, exporting: true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(exported, isNot(same(live)));
    expect(exported.readOnly, isTrue);
    expect(exported.captureRead().inputs['n'], 7);
    expect(live.captureRead().inputs['n'], 9);
    expect(find.text('7 kg'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(IosIconButton), findsNothing);
    expect(find.text('Ask'), findsNothing);
    expect(find.text('Read-only snapshot'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(live.canSnapshot, isTrue);
    expect(live.captureRead().inputs['n'], 9);
  });
  for (final provider in [false, true]) {
    for (final showThinking in [false, true]) {
      testWidgets(
        'Web-only PNG preserves split original metadata provider=$provider thinking=$showThinking',
        (tester) async {
          const source =
              '{"version":1,"title":"<think>Literal title</think>","summary":"Literal summary"}\n<p><think>Literal HTML</think></p>\n';
          const web = '```kelivo-web\n$source```';
          final parts = <MessagePart>[
            if (provider) const ReasoningPart('provider reasoning'),
            const TextPart('<think>PRIVATE</think>\n\n```kelivo-'),
            TextPart(web.substring('```kelivo-'.length)),
          ];
          final msg = message(parts: parts);
          final projection = await project(msg);
          expect(projection.surfaces, isEmpty);
          final captures = UiExportCapture(
            messages: [msg],
            projections: {'r': projection},
          );
          final prefs = createBusinessTestPreferences();
          final settings = SettingsProvider(prefs);
          await settings.loaded;
          addTearDown(settings.dispose);
          final before = UiWebController.createdNativeViews;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider(
                  create: (_) => AssistantProvider(preferences: prefs),
                ),
                ChangeNotifierProvider(
                  create: (_) => UserProvider(preferences: prefs),
                ),
                ChangeNotifierProvider(
                  create: (_) => TtsProvider(preferences: prefs),
                ),
                ChangeNotifierProvider(create: (_) => ToolApprovalService()),
                ChangeNotifierProvider(
                  create: (_) => AskUserInteractionService(),
                ),
              ],
              child: MaterialApp(
                theme: buildLightTheme(null),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: ExportCaptureScope(
                      enabled: true,
                      child: UiExportSnapshotScope(
                        captures: captures,
                        child: buildExportedMessageCardForTesting(
                          captures.messages.single,
                          showThinkingAndToolCards: showThinking,
                          expandThinkingContent: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final card = tester.widget<GenUiWebCard>(find.byType(GenUiWebCard));
          expect(card.exporting, isTrue);
          expect(card.document.canOpen, isTrue);
          expect(card.document.source, source);
          expect(card.document.title, '<think>Literal title</think>');
          expect(find.byType(GenUiWebOpenButton), findsNothing);
          expect(UiWebController.createdNativeViews, before);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  for (final sourceKind in [
    'inline',
    'legacy',
    'empty-part',
    'empty-segments',
    'invalid-segments',
    'historical-single',
    'historical-multiple',
    'historical-tool',
  ]) {
    for (final showThinking in [false, true]) {
      for (final expandedThinking in [false, true]) {
        testWidgets(
          'real PNG source=$sourceKind thinking=$showThinking expanded=$expandedThinking',
          (tester) async {
            var msg = message(
              content: '<think>\n\nPRIVATE\n\n$_fence\n\n</think>\n\n$_fence',
            );
            msg = switch (sourceKind) {
              'legacy' => msg.copyWith(reasoningText: 'provider reasoning'),
              'empty-part' => msg.copyWith(
                parts: [const ReasoningPart(''), ...msg.parts],
              ),
              'empty-segments' => msg.copyWith(reasoningSegmentsJson: '[{}]'),
              'invalid-segments' => msg.copyWith(
                reasoningSegmentsJson: '[{"text":42}]',
              ),
              _ => msg,
            };
            final historical = sourceKind.startsWith('historical-');
            final historicalTool = sourceKind == 'historical-tool';
            if (historical) {
              final raw = List.filled(4, _fence).join('\n\n');
              msg =
                  message(
                    parts: [
                      if (historicalTool)
                        for (final completed in [false, true])
                          ToolCallPart(
                            jsonEncode({
                              'id': 'historical-tool',
                              'name': 'search',
                              'arguments': <String, Object?>{},
                              if (completed) 'content': 'synthetic result',
                            }),
                          )
                      else
                        const ReasoningPart('first\nsecond'),
                      TextPart(raw),
                    ],
                  ).copyWith(
                    reasoningText: sourceKind == 'historical-single'
                        ? 'plan'
                        : null,
                    reasoningSegmentsJson: jsonEncode({
                      'segments': [
                        if (sourceKind == 'historical-multiple') ...[
                          {'text': 'first', 'toolStartIndex': 0},
                          {'text': 'second', 'toolStartIndex': 0},
                        ],
                      ],
                      'contentSplits': {
                        'offsets': [raw.indexOf('root =')],
                        'reasoningCounts': [
                          historicalTool
                              ? 0
                              : (sourceKind == 'historical-multiple' ? 2 : 1),
                        ],
                        'toolCounts': [historicalTool ? 1 : 0],
                      },
                    }),
                  );
            }
            final provider = !const {
              'inline',
              'invalid-segments',
            }.contains(sourceKind);
            final ordinal = sourceKind == 'empty-part' ? 1 : 0;
            final keys = historical
                ? ['${historicalTool ? 2 : 1}:2', '${historicalTool ? 2 : 1}:3']
                : [if (provider) '$ordinal:0', '$ordinal:1'];
            final snapshots = <UiSurfaceSnapshot>[];
            for (final key in keys) {
              final live =
                  UiSurfaceController(
                    owner: UiSurfaceOwner(revisionId: 'r', surfaceKey: key),
                  )..updateSource(
                    _body,
                    closed: true,
                    generation: UiGenerationStatus.complete,
                  );
              live.setInputs({'n': 7}, token: live.token);
              snapshots.add(live.captureSnapshot());
              live.dispose();
            }
            final projection = await project(msg, snapshots: snapshots);
            expect(projection.surfaces.map((s) => s.owner.surfaceKey), keys);
            final captures = UiExportCapture(
              messages: [msg],
              projections: {'r': projection},
            );
            final prefs = createBusinessTestPreferences();
            final settings = SettingsProvider(prefs);
            await settings.loaded;
            addTearDown(settings.dispose);
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: settings),
                  ChangeNotifierProvider(
                    create: (_) => AssistantProvider(preferences: prefs),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => UserProvider(preferences: prefs),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => TtsProvider(preferences: prefs),
                  ),
                  ChangeNotifierProvider(create: (_) => ToolApprovalService()),
                  ChangeNotifierProvider(
                    create: (_) => AskUserInteractionService(),
                  ),
                ],
                child: MaterialApp(
                  theme: buildLightTheme(null),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: ExportCaptureScope(
                        enabled: true,
                        child: UiExportSnapshotScope(
                          captures: captures,
                          child: buildExportedMessageCardForTesting(
                            captures.messages.single,
                            showThinkingAndToolCards: showThinking,
                            expandThinkingContent: expandedThinking,
                            conversationBubble: historical && expandedThinking,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final surfaces = tester
                .widgetList<GenUiSurface>(find.byType(GenUiSurface))
                .toList();
            expect(surfaces.map((s) => s.controller.owner.surfaceKey), keys);
            for (final surface in surfaces) {
              expect(surface.exporting, isTrue);
              expect(surface.controller.captureRead().inputs['n'], 7);
            }
            expect(find.text('21'), findsNWidgets(keys.length));
            expect(find.byType(EditableText), findsNothing);
            if (!provider && (!showThinking || !expandedThinking)) {
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      w is MarkdownWithCodeHighlight &&
                      w.text.contains('PRIVATE'),
                ),
                findsNothing,
              );
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
