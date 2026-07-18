import 'package:Kelivo/core/models/chat_model_target.dart';
import 'package:Kelivo/core/providers/chat_model_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const fallback = ChatModelTarget(providerKey: 'fallback', modelId: 'one');
  const a = ChatModelTarget(providerKey: 'p1', modelId: 'a');
  const b = ChatModelTarget(providerKey: 'p2', modelId: 'b');
  const c = ChatModelTarget(providerKey: 'p3', modelId: 'c');

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('defaults to conversation scope and persists ordered targets', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = ChatModelSelectionProvider(preferences: prefs);
    await provider.ready;

    expect(provider.scope, MultiModelSelectionScope.conversation);
    expect(
      provider.effectiveTargets(
        fallback: fallback,
        assistantId: 'assistant',
        conversationId: 'conversation',
      ),
      [fallback],
    );

    await provider.setTargets(
      targets: const [b, a, b, c],
      conversationId: 'conversation',
    );
    expect(provider.targetsForScope(conversationId: 'conversation'), [b, a, c]);

    final restored = ChatModelSelectionProvider(preferences: prefs);
    await restored.ready;
    expect(restored.targetsForScope(conversationId: 'conversation'), [b, a, c]);
  });

  test(
    'keeps scope histories and consumes next-message only explicitly',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ChatModelSelectionProvider(preferences: prefs);
      await provider.ready;

      await provider.setTargets(
        targets: const [a, b],
        conversationId: 'conversation',
      );
      await provider.setScope(MultiModelSelectionScope.assistant);
      await provider.setTargets(
        targets: const [b, c],
        assistantId: 'assistant',
      );
      await provider.setScope(MultiModelSelectionScope.nextMessage);
      await provider.setTargets(
        targets: const [c, a],
        conversationId: 'conversation',
      );

      expect(
        provider.targetsForScope(
          scope: MultiModelSelectionScope.conversation,
          conversationId: 'conversation',
        ),
        [a, b],
      );
      expect(
        provider.targetsForScope(
          scope: MultiModelSelectionScope.assistant,
          assistantId: 'assistant',
        ),
        [b, c],
      );
      expect(await provider.consumeNextMessage('conversation'), [c, a]);
      expect(provider.targetsForScope(conversationId: 'conversation'), isEmpty);
    },
  );

  test(
    'remaps conversations and falls back when pruning leaves one target',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ChatModelSelectionProvider(preferences: prefs);
      await provider.ready;
      await provider.setTargets(
        targets: const [a, b, c],
        conversationId: 'old',
      );

      await provider.remapConversationIds(const {'old': 'new'});
      expect(provider.targetsForScope(conversationId: 'old'), isEmpty);
      expect(provider.targetsForScope(conversationId: 'new'), [a, b, c]);

      await provider.pruneTargets((target) => target == a);
      expect(provider.targetsForScope(conversationId: 'new'), isEmpty);
      expect(
        provider.effectiveTargets(fallback: fallback, conversationId: 'new'),
        [fallback],
      );
    },
  );

  test('rejects combinations with fewer than two unique targets', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = ChatModelSelectionProvider(preferences: prefs);
    await provider.ready;

    await expectLater(
      provider.setTargets(targets: const [a, a], conversationId: 'c'),
      throwsArgumentError,
    );
    await expectLater(
      provider.setTargets(
        conversationId: 'conversation-a',
        targets: [
          for (var index = 0; index < 6; index++)
            ChatModelTarget(
              providerKey: 'provider-$index',
              modelId: 'model-$index',
            ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
