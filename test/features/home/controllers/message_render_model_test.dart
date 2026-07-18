import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/features/home/controllers/message_render_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage message(
    String id,
    String role, {
    String? groupId,
    int version = 0,
    bool streaming = false,
    String? providerId,
    String? modelId,
  }) => ChatMessage(
    id: id,
    role: role,
    content: id,
    conversationId: 'conversation',
    groupId: groupId,
    version: version,
    isStreaming: streaming,
    providerId: providerId,
    modelId: modelId,
  );

  test('projects versions, divider and latest assistant in one snapshot', () {
    final user = message('user', 'user');
    final first = message('a0', 'assistant', groupId: 'answer', version: 0);
    final selected = message('a1', 'assistant', groupId: 'answer', version: 1);
    final streaming = message('tail', 'assistant', streaming: true);

    final models = MessageRenderModelProjector.project(
      messages: [user, selected, streaming],
      byGroup: {
        'user': [user],
        'answer': [selected, first],
        'tail': [streaming],
      },
      versionSelections: const {'answer': 1},
      versionCounts: const {'answer': 2},
      contextDividerIndex: 1,
    );

    expect(models.map((model) => model.slotId), ['user', 'answer', 'tail']);
    expect(models[1].versions.map((item) => item.version), [0, 1]);
    expect(models[1].selectedVersionIndex, 1);
    expect(models[1].showContextDivider, isTrue);
    expect(models[1].isLatestCompleteAssistant, isTrue);
    expect(models[2].isLatestCompleteAssistant, isFalse);
  });

  test('clamps stale selections without scanning from a row builder', () {
    final only = message('only', 'assistant');
    final models = MessageRenderModelProjector.project(
      messages: [only],
      byGroup: {
        'only': [only],
      },
      versionSelections: const {'only': 99},
      versionCounts: const {'only': 1},
      contextDividerIndex: -1,
    );

    expect(models.single.selectedVersionIndex, 0);
    expect(models.single.versionCount, 1);
  });

  test('uses authoritative slot count when sibling revisions are evicted', () {
    final selected = message('a1', 'assistant', groupId: 'answer', version: 1);

    final models = MessageRenderModelProjector.project(
      messages: [selected],
      byGroup: {
        'answer': [selected],
      },
      versionSelections: const {'answer': 1},
      versionCounts: const {'answer': 2},
      contextDividerIndex: -1,
    );

    expect(models.single.versions, [selected]);
    expect(models.single.versionCount, 2);
    expect(models.single.selectedVersionIndex, 1);
  });

  test('maps sparse sibling versions to real navigation targets', () {
    final first = message(
      'a2',
      'assistant',
      groupId: 'answer',
      version: 2,
      providerId: 'openai',
      modelId: 'shared-name',
    );
    final selected = message(
      'a7',
      'assistant',
      groupId: 'answer',
      version: 7,
      providerId: 'google',
      modelId: 'shared-name',
    );
    final last = message(
      'a11',
      'assistant',
      groupId: 'answer',
      version: 11,
      providerId: 'openai',
      modelId: 'other',
    );

    final models = MessageRenderModelProjector.project(
      messages: [selected],
      byGroup: {
        'answer': [last, selected, first],
      },
      versionSelections: const {'answer': 7},
      versionCounts: const {'answer': 3},
      generationStates: const {
        'a2': GenerationRunState.completed,
        'a7': GenerationRunState.cancelled,
        'a11': GenerationRunState.failed,
      },
      contextDividerIndex: -1,
    );

    final model = models.single;
    expect(model.versions.map((item) => item.version), [2, 7, 11]);
    expect(model.selectedVersionIndex, 1);
    expect(model.selectedVersion, 7);
    expect(model.previousVersion, 2);
    expect(model.nextVersion, 11);
    expect(model.hasMultipleModelTargets, isTrue);
    expect(model.targetGenerationStates, {
      'a2': GenerationRunState.completed,
      'a7': GenerationRunState.cancelled,
      'a11': GenerationRunState.failed,
    });
  });
}
