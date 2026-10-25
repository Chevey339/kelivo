// Inspect the retained native paragraph used by the real timeline renderer.
// ignore: implementation_imports
import 'package:markstream/src/flutter/render/native_paragraph_run.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_search_navigation.dart';
import 'package:Kelivo/features/intelligent_ui/host/gallery/web_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_draft_request.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_user_context_parts.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/intelligent_ui/host/gallery/message_gallery.dart'
    show genUiMessageFixture;
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import "../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_host_scope.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_map.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/kelivo_markdown_extensions.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:flutter/services.dart';

const body = r'''ui 1 catalog "kelivo.native/1"
$name: string = "initial"
root = Column(children=[field,result,reset])
field = TextField(label="Name", bind=$name)
result = Text(text=$name)
reset = Button(label="Reset local", action=Reset())
''';
const fence = '```kelivo-ui\n$body```';
ChatMessage message(
  String content, {
  String role = 'assistant',
  bool streaming = false,
  GenerationRunState? state = GenerationRunState.completed,
  List<MessagePart>? parts,
}) {
  final m = ChatMessage(
    id: 'native-revision',
    conversationId: 'native-conversation',
    role: role,
    content: content,
    isStreaming: streaming,
    parts: parts,
  );
  m.hydrateGenerationState(state);
  return m;
}

void desktopTest(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'long native card in the real timeline yields drags to later text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source =
          'ui 1 catalog "kelivo.native/1"\nroot = Column(children=[chart,${List.generate(14, (i) => 'm$i').join(',')}])\nchart = Chart(kind="pie",data=[{"x":"A","y":1},{"x":"B","y":2}],x="x",y=["y"])\n${List.generate(14, (i) => 'm$i = Metric(label="Result $i",value=$i)').join('\n')}';
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [
            message('```kelivo-ui\n$source\n```\n\nAfter card marker'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<_MessageListHarnessState>(
        find.byType(_MessageListHarness),
      );
      state.scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('genui-chart-canvas-chart')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(state.scrollController.offset, greaterThan(100));
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(const Offset(190, 480), const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is NativeParagraphRun &&
                  w.paragraphs.any(
                    (p) => p.text.toPlainText().contains('After card marker'),
                  ),
            )
            .hitTestable(),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  desktopTest(
    'Web cards require original assistant authority and never load inline',
    (tester) async {
      const web = '```kelivo-web\n$genUiWebGallerySource```';
      final before = UiWebController.createdNativeViews;
      for (final role in ['assistant', 'user', 'tool']) {
        await tester.pumpWidget(
          _MessageListHarness(
            key: ValueKey(role),
            messages: [message(web, role: role)],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(GenUiWebCard),
          role == 'assistant' ? findsOneWidget : findsNothing,
        );
        if (role == 'assistant') {
          expect(
            tester
                .widget<GenUiWebCard>(find.byType(GenUiWebCard))
                .document
                .phase,
            UiWebPhase.ready,
          );
        }
        expect(UiWebController.createdNativeViews, before);
        await tester.pumpWidget(const SizedBox());
      }
      for (final content in [
        web.split('\n').map((line) => '> $line').join('\n'),
        '- nested\n\n${web.split('\n').map((line) => '  $line').join('\n')}',
        '<think>\n\n$web\n\n</think>visible',
      ]) {
        await tester.pumpWidget(
          _MessageListHarness(messages: [message(content)]),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GenUiWebCard), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
      expect(UiWebController.createdNativeViews, before);
    },
  );
  desktopTest(
    'three Web and three native blocks remain visible with independent limits',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const web = '```kelivo-web\n$genUiWebGallerySource```';
      const native =
          '```kelivo-ui\nui 1 catalog "kelivo.native/1"\nroot = Text(text="Native")\n```';
      final text = List.filled(4, '$web\n\n$native').join('\n\n');
      await tester.pumpWidget(_MessageListHarness(messages: [message(text)]));
      await tester.pumpAndSettle();
      expect(find.byType(GenUiWebCard), findsNWidgets(3));
      expect(find.byType(GenUiSurface), findsNWidgets(3));
      expect(
        find.text(
          'Up to 3 web previews per message; the rest are shown as source',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Up to 3 UI blocks per message; the rest are shown as source',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'a cached closed Web fence waits for actual generation completion',
    (tester) async {
      const web = '```kelivo-web\n$genUiWebGallerySource```';
      for (final state in [
        GenerationRunState.streaming,
        GenerationRunState.completed,
        GenerationRunState.interrupted,
      ]) {
        await tester.pumpWidget(
          _MessageListHarness(messages: [message(web, state: state)]),
        );
        await tester.pumpAndSettle();
        final card = tester.widget<GenUiWebCard>(find.byType(GenUiWebCard));
        expect(card.document.canOpen, state == GenerationRunState.completed);
        expect(card.document.phase, switch (state) {
          GenerationRunState.streaming => UiWebPhase.streaming,
          GenerationRunState.completed => UiWebPhase.ready,
          _ => UiWebPhase.interrupted,
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'repository replacement rebinds a cached native block with the same child',
    (tester) async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      Future<(ChatDatabaseRepository, ChatService, ChatMessage)> seed(
        String name,
      ) async {
        final repo = ChatDatabaseRepository(
          AppDatabase(NativeDatabase.memory()),
        );
        await repo.putConversation(
          Conversation(id: 'native-conversation', title: 'Test'),
        );
        await repo.putMessage(message(fence));
        var run = await repo.createGenerationRun(
          id: 'run',
          conversationId: 'native-conversation',
          targetRevisionId: 'native-revision',
          createdAt: DateTime.now().toUtc(),
        );
        for (final next in [
          GenerationRunState.requesting,
          GenerationRunState.streaming,
          GenerationRunState.completed,
        ]) {
          run = await repo.transitionGenerationRun(
            id: run.id,
            expectedState: run.state,
            expectedStateRevision: run.stateRevision,
            nextState: next,
            updatedAt: DateTime.now().toUtc(),
          );
        }
        final controller =
            UiSurfaceController(
              owner: const UiSurfaceOwner(
                revisionId: 'native-revision',
                surfaceKey: '0:0',
              ),
            )..updateSource(
              body,
              closed: true,
              generation: UiGenerationStatus.complete,
            );
        controller.setInputs({'name': name}, token: controller.token);
        final lease = repo.genUiStates.attach(
          'native-conversation',
          controller.owner,
          controller.sourceHash!,
        )!;
        repo.genUiStates.accept(lease, controller.captureSnapshot());
        await repo.genUiStates.flush();
        controller.dispose();
        return (
          repo,
          ChatService(existingRepository: repo),
          (await repo.getMessage('native-revision'))!,
        );
      }

      final first = (await tester.runAsync(() => seed('first database')))!;
      final second = (await tester.runAsync(() => seed('second database')))!;
      addTearDown(() async {
        first.$2.dispose();
        second.$2.dispose();
        await first.$1.close();
        await second.$1.close();
      });
      final sameChild = _MessageListHarness(messages: [first.$3]);
      Widget app(ChatService service) =>
          ChangeNotifierProvider.value(value: service, child: sameChild);
      await tester.pumpWidget(app(first.$2));
      await tester.pumpAndSettle();
      await tester.runAsync(first.$1.genUiStates.flush);
      await tester.pumpAndSettle();
      final old = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      final registry = tester
          .widget<UiRuntimeScope>(find.byType(UiRuntimeScope))
          .registry;
      expect(old.state.inputs['name'], 'first database');
      await tester.pumpWidget(app(second.$2));
      await tester.pumpAndSettle();
      await tester.runAsync(second.$1.genUiStates.flush);
      await tester.pumpAndSettle();
      final current = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(identical(current, old), isFalse);
      expect(
        tester.widget<UiRuntimeScope>(find.byType(UiRuntimeScope)).registry,
        same(registry),
      );
      expect(current.state.inputs['name'], 'second database');
      await tester.enterText(find.byType(EditableText).first, 'new value');
      await tester.pump();
      await tester.runAsync(current.flush);
      final oldLease = first.$1.genUiStates.attach(
        'native-conversation',
        current.owner,
        current.sourceHash!,
      )!;
      final oldSaved = await tester.runAsync(
        () => first.$1.genUiStates.load(oldLease),
      );
      expect(oldSaved!.snapshot!.state.inputs['name'], 'first database');
      final newLease = second.$1.genUiStates.attach(
        'native-conversation',
        current.owner,
        current.sourceHash!,
      )!;
      final newSaved = await tester.runAsync(
        () => second.$1.genUiStates.load(newLease),
      );
      expect(newSaved!.snapshot!.state.inputs['name'], 'new value');
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'trusted assistant works inside actual list; field pointer retains keyboard focus',
    (tester) async {
      await tester.pumpWidget(_MessageListHarness(messages: [message(fence)]));
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSurface), findsOneWidget);
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(surface.phase, SurfacePhase.complete);
      final field = find.byWidgetPredicate(
        (w) => w is EditableText && !w.readOnly,
      );
      await tester.tap(field);
      await tester.pump();
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      await tester.enterText(field, 'changed');
      await tester.pump();
      expect(surface.captureRead().inputs['name'], 'changed');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      // Card prose still enters the list's selection/keyboard path.
      final text = find.text('Name');
      await tester.tap(text);
      await tester.pump();
      final listFocus = tester.widget<Focus>(
        find.byKey(const ValueKey('timeline-keyboard-scroll-region')),
      );
      expect(listFocus.focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'earlier closed block waits for actual host success; cancelled remains read only',
    (tester) async {
      final text = '$fence\n\nLater reply';
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [
            message(text, streaming: true, state: GenerationRunState.streaming),
          ],
        ),
      );
      await tester.pump();
      var surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(surface.readOnly, isTrue);
      expect(surface.phase, SurfacePhase.streaming);
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [message(text, state: GenerationRunState.cancelled)],
        ),
      );
      await tester.pumpAndSettle();
      expect(surface.phase, SurfacePhase.interrupted);
      await tester.pumpWidget(_MessageListHarness(messages: [message(text)]));
      await tester.pumpAndSettle();
      expect(
        identical(
          surface,
          tester.widget<GenUiSurface>(find.byType(GenUiSurface)).controller,
        ),
        isTrue,
      );
      expect(surface.readOnly, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final role in ['user', 'tool', 'system', 'unknown']) {
    desktopTest('$role source cannot acquire assistant authority', (
      tester,
    ) async {
      await tester.pumpWidget(
        _MessageListHarness(messages: [message(fence, role: role)]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSurface), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
  desktopTest(
    'blockquote and open thinking never activate; literal tags stay in native source',
    (tester) async {
      for (final text in [
        fence.split('\n').map((s) => '> $s').join('\n'),
        '<think>\n$fence',
      ]) {
        await tester.pumpWidget(_MessageListHarness(messages: [message(text)]));
        await tester.pumpAndSettle();
        expect(find.byType(GenUiSurface), findsNothing);
      }
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [
            message(fence.replaceAll('initial', '<think>literal</think>')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSurface), findsOneWidget);
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(surface.captureRead().inputs['name'], '<think>literal</think>');
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'fourth native block falls back and identical fences have independent owners',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [message(List.filled(4, fence).join('\n\n'))],
        ),
      );
      await tester.pumpAndSettle();
      final controllers = tester
          .widgetList<GenUiSurface>(find.byType(GenUiSurface))
          .map((s) => s.controller)
          .toList();
      expect(controllers, hasLength(3));
      expect(controllers.map((c) => c.owner.surfaceKey), ['0:0', '0:1', '0:2']);
      expect(
        find.text(
          'Up to 3 UI blocks per message; the rest are shown as source',
        ),
        findsOneWidget,
      );
      controllers.first.setInputs({
        'name': 'one',
      }, token: controllers.first.token);
      expect(controllers[1].captureRead().inputs['name'], 'initial');
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'paragraph regrouping and offscreen disposal preserve input owner',
    (tester) async {
      final native = message('Intro\n\n$fence\n\nTail');
      final messages = [
        native,
        for (var i = 0; i < 30; i++)
          ChatMessage(
            id: 'other-$i',
            role: 'assistant',
            conversationId: 'native-conversation',
            content: List.filled(12, 'Ordinary history $i').join('\n\n'),
          ),
      ];
      await tester.pumpWidget(_MessageListHarness(messages: messages));
      await tester.pumpAndSettle();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      surface.setInputs({'name': 'retained'}, token: surface.token);
      final settings = tester
          .element(find.byType(MessageListView))
          .read<SettingsProvider>();
      await settings.setAssistantBubbleSplitParagraphs(true);
      await tester.pumpAndSettle();
      expect(
        identical(
          surface,
          tester.widget<GenUiSurface>(find.byType(GenUiSurface)).controller,
        ),
        isTrue,
      );
      expect(surface.captureRead().inputs['name'], 'retained');
      final state = tester.state<_MessageListHarnessState>(
        find.byType(_MessageListHarness),
      );
      state.scrollController.jumpTo(
        state.scrollController.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSurface), findsNothing);
      state.scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        identical(
          surface,
          tester.widget<GenUiSurface>(find.byType(GenUiSurface)).controller,
        ),
        isTrue,
      );
      expect(surface.captureRead().inputs['name'], 'retained');
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'prefix append keeps native state; source replacement invalidates old authority',
    (tester) async {
      await tester.pumpWidget(
        _MessageListHarness(messages: [message('$fence\n\nTail')]),
      );
      await tester.pumpAndSettle();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      final token = surface.token;
      final records = surface.parsed.committedRecords;
      surface.setInputs({'name': 'retained'}, token: token);
      await tester.pumpWidget(
        _MessageListHarness(messages: [message('$fence\n\nTail grows')]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSurface), findsOneWidget);
      expect(surface.captureRead().inputs['name'], 'retained');
      expect(surface.parsed.committedRecords, records);
      expect(surface.parsed.program.diagnostics, isEmpty);
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [message(fence.replaceFirst('initial', 'new default'))],
        ),
      );
      await tester.pumpAndSettle();
      expect(surface.captureRead().inputs['name'], 'new default');
      expect(
        surface.setInputs({'name': 'stale'}, token: token),
        UiMutationResult.stale,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'a file boundary cannot close a native fence in the previous text run',
    (tester) async {
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [
            message(
              '',
              parts: const [
                TextPart('```kelivo-ui\n$body'),
                FilePart(uri: '/missing', name: 'file'),
                TextPart('```'),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(surface.parsed.closed, isFalse);
      expect(surface.phase, SurfacePhase.interrupted);
      expect(surface.readOnly, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest('no scope and identical nested renderer remain plain code', (
    tester,
  ) async {
    final registry = UiRuntimeRegistry();
    addTearDown(registry.dispose);
    final parts = [const TextPart(fence)];
    final source = UiMessageSource.of(
      parts,
    ).sliceForPart(0, 0, fence.length)!.withFirstMessageOrdinal(0);
    final owner = ms.MarkstreamView(
      source: fence,
      extensions: kelivoMarkdownExtensions,
    );
    Widget app(Widget child) => ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UiRuntimeScope(registry: registry, child: child),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(const MarkdownWithCodeHighlight(text: fence)));
    await tester.pumpAndSettle();
    expect(find.byType(GenUiSurface), findsNothing);
    final binding = UiHostBinding(
      conversationId: 'c',
      revisionId: 'r',
      source: source,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpWidget(
      app(
        UiHostScope(
          binding: binding,
          renderOwner: owner,
          exporting: false,
          child: ms.MarkstreamView(
            source: fence,
            extensions: kelivoMarkdownExtensions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GenUiSurface), findsNothing);
    await tester.pumpWidget(
      app(
        UiHostScope(
          binding: binding,
          renderOwner: owner,
          exporting: false,
          child: owner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GenUiSurface), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  desktopTest(
    'streaming header and forward references replace in place and stop their clock',
    (tester) async {
      Future<void> show(
        String text, {
        GenerationRunState state = GenerationRunState.streaming,
      }) async {
        await tester.pumpWidget(
          _MessageListHarness(
            messages: [
              message(
                text,
                streaming: state == GenerationRunState.streaming,
                state: state,
              ),
            ],
          ),
        );
        await tester.pump();
      }

      await show('```kelivo-ui\nui 1 catalog "kelivo.native/1"');
      expect(find.byType(GenUiSurface), findsNothing);
      const prefix = '```kelivo-ui\nui 1 catalog "kelivo.native/1"\n';
      await show(prefix);
      var surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(surface.parsed.headerAccepted, isTrue);
      expect(surface.parsed.program.declarations, isEmpty);
      await show('${prefix}root = Column(children=[future])\n');
      expect(find.text('Waiting for future'), findsOneWidget);
      const complete =
          '${prefix}root = Column(children=[future])\nfuture = Text(text="Ready")\n```';
      await show(complete);
      expect(surface.parsed.closed, isTrue);
      expect(surface.readOnly, isTrue);
      await show(complete, state: GenerationRunState.completed);
      await tester.pumpAndSettle();
      expect(surface.readOnly, isFalse);
      expect(find.text('Waiting for future'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      await show(
        '${prefix}root = Column(children=[missing])\n',
        state: GenerationRunState.cancelled,
      );
      await tester.pumpAndSettle();
      expect(surface.phase, SurfacePhase.interrupted);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'native development fixture is complete and its real button observes frozen Ask',
    (tester) async {
      final intents = <UiAskIntent>[];
      await tester.pumpWidget(
        UiActionsScope(
          onAsk: (intent) async {
            intents.add(intent);
          },
          child: _MessageListHarness(
            messages: [message('```kelivo-ui\n$genUiMessageFixture```')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      expect(
        surface.phase,
        SurfacePhase.complete,
        reason: surface.parsed.program.diagnostics.toString(),
      );
      await tester.ensureVisible(find.text('Observe frozen Ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Observe frozen Ask'));
      await tester.pumpAndSettle();
      expect(intents, hasLength(1));
      expect(intents.single.context, {'name': 'Kelivo', 'quantity': 3});
      surface.setInputs({'amount': 8}, token: surface.token);
      expect(intents.single.context['quantity'], 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'explicit More attachment freezes state; ordinary edits and Reset do not stage',
    (tester) async {
      final drafts = <UiDraftRequest>[];
      await tester.pumpWidget(
        UiActionsScope(
          onDraft: (request) async => drafts.add(request),
          child: _MessageListHarness(messages: [message(fence)]),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      surface.setInputs({'name': 'Frozen'}, token: surface.token);
      await tester.pump();
      expect(drafts, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(GenUiSurface),
          matching: find.byTooltip('More'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach current state'));
      await tester.pumpAndSettle();
      expect(drafts, hasLength(1));
      final chip = drafts.single.attachment!;
      expect(chip.source!.revisionId, 'native-revision');
      expect(chip.source!.conversationId, 'native-conversation');
      expect(chip.text.body, contains('Frozen'));
      surface.setInputs({'name': 'Later'}, token: surface.token);
      await tester.pump();
      await tester.tap(find.text('Reset local'));
      await tester.pumpAndSettle();
      expect(surface.nodes['field']!.properties['bind'], 'initial');
      expect(drafts, hasLength(1));
      expect(chip.text.body, isNot(contains('Later')));
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'host repair stages diagnostics without an attachment or automatic send',
    (tester) async {
      final drafts = <UiDraftRequest>[];
      await tester.pumpWidget(
        UiActionsScope(
          onDraft: (request) async => drafts.add(request),
          child: _MessageListHarness(
            messages: [
              message(
                '```kelivo-ui\nui 1 catalog "kelivo.native/1"\n'
                'root = Text(text="Broken", extra=true)\n```',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repair UI'));
      await tester.pumpAndSettle();
      expect(drafts, hasLength(1));
      expect(drafts.single.attachment, isNull);
      expect(drafts.single.text, contains('unknownProperty'));
      expect(drafts.single.text, contains('extra=true'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'sent user chip is a readonly summary and marker-like text stays ordinary',
    (tester) async {
      final frozen = UiContextText(title: 'Parameters', body: 'Slope: 3.1');
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [
            message(
              '',
              role: 'user',
              parts: UiUserContextParts.attach(const [
                TextPart('Question'),
              ], frozen),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiContextChip), findsOneWidget);
      expect(find.byKey(const ValueKey('genui-context-remove')), findsNothing);
      expect(find.byType(GenUiSurface), findsNothing);
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [message('${frozen.exactText}\n\nQuestion', role: 'user')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiContextChip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final missing in [
    fence.replaceFirst('kelivo-ui', 'text'),
    'The UI was removed',
    '<think>\n\n$fence\n\n</think>',
  ]) {
    desktopTest(
      'removing original UI authority revokes its owner before restoring it: ${missing.substring(0, 12)}',
      (tester) async {
        await tester.pumpWidget(
          _MessageListHarness(messages: [message(fence)]),
        );
        await tester.pumpAndSettle();
        final old = tester
            .widget<GenUiSurface>(find.byType(GenUiSurface))
            .controller;
        final token = old.token;
        old.setInputs({'name': 'changed'}, token: token);
        await tester.pumpWidget(
          _MessageListHarness(messages: [message(missing)]),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GenUiSurface), findsNothing);
        expect(old.accepts(token), isFalse);
        await tester.pumpWidget(
          _MessageListHarness(messages: [message(fence)]),
        );
        await tester.pumpAndSettle();
        final restored = tester
            .widget<GenUiSurface>(find.byType(GenUiSurface))
            .controller;
        expect(identical(old, restored), isFalse);
        expect(restored.captureRead().inputs['name'], 'initial');
        expect(
          restored.setInputs({'name': 'stale'}, token: token),
          UiMutationResult.stale,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  desktopTest(
    'streaming notifier owns current source while the parent row is an older checkpoint',
    (tester) async {
      final notifier = StreamingContentNotifier();
      addTearDown(notifier.dispose);
      notifier.getNotifier('native-revision');
      notifier.updateContent(
        'native-revision',
        fence,
        20,
        parts: const [TextPart(fence)],
      );
      ChatMessage row(String content) => message(
        content,
        streaming: true,
        state: GenerationRunState.streaming,
      );
      await tester.pumpWidget(
        _MessageListHarness(messages: [row('')], notifier: notifier),
      );
      await tester.pump();
      final surface = tester
          .widget<GenUiSurface>(find.byType(GenUiSurface))
          .controller;
      final token = surface.token;
      await tester.pumpWidget(
        _MessageListHarness(
          messages: [row('older checkpoint')],
          notifier: notifier,
        ),
      );
      await tester.pump();
      expect(
        identical(
          surface,
          tester.widget<GenUiSurface>(find.byType(GenUiSurface)).controller,
        ),
        isTrue,
      );
      expect(surface.accepts(token), isTrue);
      notifier.updateContent(
        'native-revision',
        'source removed',
        21,
        parts: const [TextPart('source removed')],
      );
      await tester.pump();
      expect(find.byType(GenUiSurface), findsNothing);
      expect(surface.accepts(token), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  desktopTest(
    'search target reveals its original surface in the real message host',
    (tester) async {
      final navigation = UiSearchNavigation();
      addTearDown(navigation.dispose);
      await tester.pumpWidget(
        UiSearchNavigationScope(
          navigation: navigation,
          child: _MessageListHarness(
            messages: [
              message(
                '$fence\n\n${List.filled(50, "Ordinary paragraph between interfaces.").join("\n\n")}\n\n```kelivo-ui\nui 1 catalog "kelivo.native/1"\nroot = Metric(label="Target result",value=42)\n```',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<_MessageListHarnessState>(
        find.byType(_MessageListHarness),
      );
      state.scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      final target = find.byWidgetPredicate(
        (w) => w is GenUiSurface && w.controller.owner.surfaceKey == '0:1',
      );
      expect(target, findsOneWidget);
      expect(tester.getTopLeft(target).dy, greaterThan(600));
      navigation.reveal('native-conversation', 'native-revision', '0:1');
      await tester.pumpAndSettle();
      expect(navigation.value, isNull);
      expect(state.scrollController.offset, greaterThan(0));
      expect(tester.getTopLeft(target).dy, inInclusiveRange(0, 500));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _MessageListHarness extends StatefulWidget {
  const _MessageListHarness({super.key, required this.messages, this.notifier});

  final List<ChatMessage> messages;
  final StreamingContentNotifier? notifier;

  @override
  State<_MessageListHarness> createState() => _MessageListHarnessState();
}

class _MessageListHarnessState extends State<_MessageListHarness> {
  late final ScrollController scrollController;
  late final ListController listController;
  late final ValueNotifier<String?> processingFilesMessageId;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    listController = ListController();
    processingFilesMessageId = ValueNotifier<String?>(null);
  }

  @override
  void dispose() {
    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: widget.messages,
            streamingContentNotifier: widget.notifier,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const <String, stream_ctrl.ReasoningData>{},
            reasoningSegments:
                const <String, List<stream_ctrl.ReasoningSegmentData>>{},
            contentSplits: const <String, stream_ctrl.ContentSplitData>{},
            toolParts: const {},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            processingFilesMessageId: processingFilesMessageId,
          ),
        ),
      ),
    );
  }
}
