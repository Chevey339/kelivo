import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/models/conversation_prompt_settings.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/chat/chat_service.dart';

enum PromptSelectionKind { instruction, worldBook }

/// A non-null [conversationId] selects conversation scope. Callers only supply
/// it when the assistant enables per-conversation prompt injections.
List<String> promptSelectionIds(
  BuildContext context, {
  required PromptSelectionKind kind,
  String? assistantId,
  String? conversationId,
  bool listen = true,
}) {
  if (conversationId != null) {
    List<String> select(ChatService chat) {
      final settings = ConversationPromptSettings.fromExtras(
        chat.getConversation(conversationId)?.extras ?? const {},
      );
      return kind == PromptSelectionKind.worldBook
          ? settings.worldBookIds
          : settings.instructionIds;
    }

    return listen
        ? context.select<ChatService, List<String>>(select)
        : select(context.read<ChatService>());
  }
  if (kind == PromptSelectionKind.worldBook) {
    final provider = listen
        ? context.watch<WorldBookProvider>()
        : context.read<WorldBookProvider>();
    return provider.activeBookIdsFor(assistantId);
  }
  final provider = listen
      ? context.watch<InstructionInjectionProvider>()
      : context.read<InstructionInjectionProvider>();
  return provider.activeIdsFor(assistantId);
}

Future<void> setPromptSelection(
  BuildContext context,
  List<String> ids, {
  required PromptSelectionKind kind,
  String? assistantId,
  String? conversationId,
}) {
  if (conversationId != null) {
    final key = kind == PromptSelectionKind.worldBook
        ? ConversationPromptSettings.worldBookIdsKey
        : ConversationPromptSettings.instructionIdsKey;
    return context.read<ChatService>().updateConversationExtras(
      conversationId,
      (extras) => {...extras, key: ids.toSet().toList()},
    );
  }
  return kind == PromptSelectionKind.worldBook
      ? context.read<WorldBookProvider>().setActiveBookIds(
          ids,
          assistantId: assistantId,
        )
      : context.read<InstructionInjectionProvider>().setActiveIds(
          ids,
          assistantId: assistantId,
        );
}

Future<void> togglePromptSelection(
  BuildContext context,
  String id, {
  required PromptSelectionKind kind,
  String? assistantId,
  String? conversationId,
}) {
  if (conversationId == null) {
    return kind == PromptSelectionKind.worldBook
        ? context.read<WorldBookProvider>().toggleActiveBookId(
            id,
            assistantId: assistantId,
          )
        : context.read<InstructionInjectionProvider>().toggleActiveId(
            id,
            assistantId: assistantId,
          );
  }
  final key = kind == PromptSelectionKind.worldBook
      ? ConversationPromptSettings.worldBookIdsKey
      : ConversationPromptSettings.instructionIdsKey;
  return context.read<ChatService>().updateConversationExtras(conversationId, (
    extras,
  ) {
    final settings = ConversationPromptSettings.fromExtras(extras);
    final ids =
        (kind == PromptSelectionKind.worldBook
                ? settings.worldBookIds
                : settings.instructionIds)
            .toSet();
    if (!ids.remove(id)) ids.add(id);
    return {...extras, key: ids.toList()};
  });
}
