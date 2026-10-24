import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_message_projection.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../../support/genui_projection_fixture.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$a: number = 2
root = Metric(label="Result",value=$a*2)
''';
void main() {
  late ChatDatabaseRepository repo;
  late ChatMessage message;
  late UiSurfaceController controller;
  setUp(() async {
    repo = ChatDatabaseRepository(AppDatabase(NativeDatabase.memory()));
    await repo.ensureReady();
    await repo.putConversation(Conversation(id: 'c', title: 'Projection'));
    message = ChatMessage(
      id: 'r',
      conversationId: 'c',
      role: 'assistant',
      content: '```kelivo-ui\n$_body```',
    );
    await repo.putMessage(message);
    var run = await repo.createGenerationRun(
      id: 'run',
      conversationId: 'c',
      targetRevisionId: 'r',
      createdAt: DateTime.now(),
    );
    for (final state in [
      GenerationRunState.requesting,
      GenerationRunState.streaming,
      GenerationRunState.completed,
    ]) {
      run = await repo.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: state,
        updatedAt: DateTime.now(),
      );
    }
    message = (await repo.getMessage('r'))!;
    controller =
        UiSurfaceController(
          owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
        )..updateSource(
          _body,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
  });
  tearDown(() async {
    controller.dispose();
    await repo.close();
  });
  Future<String> project() async => (await projectUiMessageText(
    message,
    projection: testUiProjection,
    store: repo.genUiStates,
    blockLimit: 'Limit',
  )).copyText;
  test(
    'unseen message restores durable values, then pending accepted values',
    () async {
      controller.setInputs({'a': 4}, token: controller.token);
      final lease = repo.genUiStates.attach(
        'c',
        controller.owner,
        controller.sourceHash!,
      )!;
      repo.genUiStates.accept(lease, controller.captureSnapshot());
      await repo.genUiStates.flush();
      expect(await project(), 'Result: 8');
      controller.setInputs({'a': 5}, token: controller.token);
      repo.genUiStates.accept(lease, controller.captureSnapshot());
      expect(await project(), 'Result: 10');
    },
  );
  test('never displayed message projects its declared defaults', () async {
    expect(await project(), 'Result: 4');
  });
  test(
    'deleted source is reported instead of silently substituting defaults',
    () async {
      await repo.deleteMessages(
        conversationId: 'c',
        messageIds: {'r'},
        versionSelectionChanges: const {},
      );
      await expectLater(project(), throwsStateError);
    },
  );
}
