import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_persistence_host.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$name: string = "initial"
$n: number = 1
root = Column(children=[nameInput,numberInput,result])
nameInput = TextField(label="Name", bind=$name)
numberInput = NumberField(label="Number", bind=$n)
result = Text(text=$name)
''';
const _owner = UiSurfaceOwner(revisionId: 'revision', surfaceKey: '0:0');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ChatDatabaseRepository repo;
  late ChatService service;
  late UiRuntimeRegistry registry;
  late UiSurfaceController controller;
  late List<GenUiSurfaceStateRow> initialCache;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatDatabaseRepository(db);
    await repo.putConversation(Conversation(id: 'conversation', title: 'Test'));
    await repo.putMessage(
      ChatMessage(
        id: 'revision',
        conversationId: 'conversation',
        role: 'assistant',
        content: '```kelivo-ui\n$_body```',
      ),
    );
    var run = await repo.createGenerationRun(
      id: 'run',
      conversationId: 'conversation',
      targetRevisionId: 'revision',
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
    initialCache = await db.select(db.genUiSurfaceStateRows).get();
    expect(initialCache.single.stateJson, '{"inputs":{},"view":{}}');
    service = ChatService(existingRepository: repo);
    registry = UiRuntimeRegistry();
    controller = registry.obtain('conversation', _owner).controller
      ..updateSource(
        _body,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
  });
  tearDown(() async {
    registry.dispose();
    service.dispose();
    await db.customStatement('DROP TRIGGER IF EXISTS fail_genui;');
    await repo.close();
  });

  Widget app({
    bool dark = false,
    double scale = 1,
    String? conversationId = 'conversation',
  }) => ChangeNotifierProvider.value(
    value: service,
    child: MaterialApp(
      locale: const Locale('en'),
      theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: UiPersistenceHost(
          registry: registry,
          conversationId: conversationId,
          child: conversationId == null
              ? const SizedBox()
              : SingleChildScrollView(
                  child: GenUiSurface(
                    controller: controller,
                    interactions: registry
                        .obtain('conversation', _owner)
                        .interactions,
                    onRetrySave: controller.flushQuietly,
                  ),
                ),
        ),
      ),
    ),
  );

  Future<void> ready(WidgetTester tester) async {
    expect(controller.phase, SurfacePhase.complete);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.runAsync(repo.genUiStates.flush);
    await tester.pumpAndSettle();
    expect(controller.readOnly, isFalse);
  }

  testWidgets('storage error shows only the retry badge and clicking it saves', (
    tester,
  ) async {
    await ready(tester);
    await tester.runAsync(
      () => db.customStatement(
        "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk failure'); END;",
      ),
    );
    await tester.enterText(find.byType(EditableText).first, 'changed');
    await tester.pump();
    await tester.runAsync(
      () => expectLater(controller.flush(), throwsA(anything)),
    );
    await tester.pump();
    expect(find.text('Not saved'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final semantics = tester.ensureSemantics();
    final retry = find.byWidgetPredicate(
      (w) => w is IosIconButton && w.tooltip == 'Tap to retry saving',
    );
    expect(
      tester.getSemantics(retry).getSemanticsData().label,
      contains('Not saved'),
    );
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_genui;'));
    await tester.tap(retry);
    await tester.pump();
    await tester.runAsync(repo.genUiStates.flush);
    await tester.pumpAndSettle();
    expect(find.text('Not saved'), findsNothing);
    expect(
      (await tester.runAsync(
        () => db.select(db.genUiSurfaceStateRows).get(),
      ))!.single.stateJson,
      contains('changed'),
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'theme and scale preserve IME; blur saves only the committed text',
    (tester) async {
      await ready(tester);
      final field = find.byType(EditableText).first;
      await tester.tap(field);
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(app(dark: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(field).controller.value.composing,
        const TextRange(start: 0, end: 2),
      );
      expect(controller.state.isDefault, isTrue);
      await tester.runAsync(controller.flush);
      expect(
        await tester.runAsync(() => db.select(db.genUiSurfaceStateRows).get()),
        initialCache,
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你好',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.runAsync(controller.flush);
      expect(
        (await tester.runAsync(
          () => db.select(db.genUiSurfaceStateRows).get(),
        ))!.single.stateJson,
        contains('你好'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('incomplete numeric draft never replaces the committed value', (
    tester,
  ) async {
    await ready(tester);
    await tester.enterText(find.byType(EditableText).at(1), '-');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.runAsync(controller.flush);
    expect(controller.captureRead().inputs['n'], 1);
    expect(
      await tester.runAsync(() => db.select(db.genUiSurfaceStateRows).get()),
      initialCache,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background and owner departure flush accepted state without a mounted card',
    (tester) async {
      await ready(tester);
      await tester.enterText(find.byType(EditableText).first, 'background');
      await tester.pump();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.runAsync(repo.genUiStates.flush);
      await tester.pump();
      expect(
        (await tester.runAsync(
          () => db.select(db.genUiSurfaceStateRows).get(),
        ))!.single.stateJson,
        contains('background'),
      );
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, 'leave');
      await tester.pump();
      await tester.pumpWidget(app(conversationId: null));
      await tester.pump();
      await tester.runAsync(repo.genUiStates.flush);
      expect(
        (await tester.runAsync(
          () => db.select(db.genUiSurfaceStateRows).get(),
        ))!.single.stateJson,
        contains('leave'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
