import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/providers/assistant_provider.dart';
import '../../core/providers/instruction_injection_provider.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/providers/memory_provider_v2.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/world_book_provider.dart';
import '../../core/services/chat/chat_service.dart';
import '../../core/services/scheduled_task_text_executor.dart';
import '../../core/services/scheduled_tasks_service.dart';
import '../../l10n/app_localizations.dart';
import '../home/controllers/chat_controller.dart';
import '../home/services/message_builder_service.dart';

/// Binds existing app providers once; the coordinator/executor need no page.
class ScheduledTaskPreparationBinding {
  ScheduledTaskPreparationBinding(this.service);
  final ScheduledTasksService service;
  final List<Listenable> _sources = [];
  SettingsProvider? _settings;
  bool _checking = false, _again = false, _disposed = false;

  Future<void> attach(
    BuildContext context,
    MessageBuilderService builder,
    ChatController controller,
  ) async {
    final chat = context.read<ChatService>();
    final settings = _settings = context.read<SettingsProvider>();
    final assistants = context.read<AssistantProvider>();
    final instructions = context.read<InstructionInjectionProvider>();
    final books = context.read<WorldBookProvider>();
    final legacyMemories = context.read<MemoryProvider>();
    final memories = context.read<MemoryProviderV2>();
    final user = context.read<UserProvider>();
    service.localizations = AppLocalizations.of(context)!;
    await Future.wait([
      settings.loaded,
      assistants.loaded,
      instructions.initialize(),
      books.initialize(),
      chat.init(),
    ]);
    if (_disposed) return;
    await service.updateNotificationPrivacy(
      settings.mobileBackground.privacyMode,
    );
    await service.configurePreparation(
      ScheduledTaskTextExecutor(
        chat: chat,
        assistants: assistants,
        settings: settings,
        busy: (id) =>
            controller.loadingConversationIds.isNotEmpty ||
            controller.conversationStreams.isNotEmpty ||
            id != null && controller.isConversationLoading(id),
        onPublished: (conversationId) async {
          if (_disposed ||
              controller.currentConversation?.id != conversationId) {
            return;
          }
          controller.updateCurrentConversation(
            chat.getConversation(conversationId),
          );
          await controller.refreshTimelineAfterMutation();
        },
        promptConfiguration: (assistantId) async {
          final assistant = assistants.getById(assistantId);
          if (assistant == null) throw StateError('assistant_missing');
          // Read the same snapshot as generation, rather than the memory UI's
          // cached assistant scope. This also captures language/item limits.
          final memory = await builder.detachedMemoryPrefix(
            assistant: assistant,
            settings: settings,
          );
          return {
            'instructions': instructions.items.map((e) => e.toJson()).toList(),
            'activeInstructions': instructions.activeIdsFor(assistantId),
            'books': books.books.map((e) => e.toJson()).toList(),
            'activeBooks': books.activeBookIdsFor(assistantId),
            'memory': memory,
            'user': user.name,
          };
        },
        buildContext: (task, assistant, conversation, modelId) =>
            builder.buildDetachedTextContext(
              assistant: assistant,
              conversation: conversation,
              modelId: modelId,
              settings: settings,
            ),
      ),
    );
    _sources.addAll([
      chat,
      settings,
      assistants,
      instructions,
      books,
      legacyMemories,
      memories,
      user,
    ]);
    for (final source in _sources) {
      source.addListener(_changed);
    }
  }

  void _changed() {
    if (_disposed) return;
    _again = true;
    if (_checking) return;
    _checking = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_again && !_disposed) {
        _again = false;
        await service.updateNotificationPrivacy(
          _settings!.mobileBackground.privacyMode,
        );
        await service.activityChanged();
      }
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _disposed = true;
    for (final source in _sources) {
      source.removeListener(_changed);
    }
    _sources.clear();
  }
}
