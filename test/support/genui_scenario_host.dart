import 'dart:io';
import 'message_test_services.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_overlay_layout.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_context_submission.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_draft_staging.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_host_scope.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/scenario_sources.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

/// Isolated storage with production repository, list, native UI and composer.
/// The send sink persists locally; this harness never invokes a model/provider.
class GenUiScenarioSession {
  GenUiScenarioSession._(this.database, this.repository)
    : service = _ScenarioChatService(repository);
  final AppDatabase database;
  final ChatDatabaseRepository repository;
  final ChatService service;
  final messages = <String, ChatMessage>{};
  final sent = <ChatMessage>[];
  static const conversation = 'genui-acceptance';

  static Future<GenUiScenarioSession> open(File file) async {
    final db = AppDatabase(NativeDatabase(file));
    final repo = ChatDatabaseRepository(db);
    await repo.ensureReady();
    final session = GenUiScenarioSession._(db, repo);
    await repo.putConversation(
      Conversation(id: conversation, title: 'Example data'),
    );
    for (final entry in genUiScenarioSources.entries) {
      final id = 'genui-${entry.key}';
      var message = await repo.getMessage(id);
      if (message == null) {
        message = ChatMessage(
          id: id,
          conversationId: conversation,
          role: 'assistant',
          content:
              'Example data. Changes are computed locally.\n\n```kelivo-ui\n${entry.value}```',
        );
        await repo.putMessage(message);
        var run = await repo.createGenerationRun(
          id: 'run-$id',
          conversationId: conversation,
          targetRevisionId: id,
          createdAt: DateTime.now().toUtc(),
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
            updatedAt: DateTime.now().toUtc(),
          );
        }
        message = (await repo.getMessage(id))!;
      }
      session.messages[entry.key] = message;
    }
    return session;
  }

  Future<ChatInputSubmissionResult> send(ChatInputData input) async {
    final saved = await repository.appendLinearMessageToConversation(
      conversation: Conversation(id: conversation, title: 'Example data'),
      message: ChatMessage(
        role: 'user',
        conversationId: conversation,
        content: input.text,
      ),
      uiContext: input.uiContext == null
          ? null
          : UiContextSubmission(
              input.uiContext!,
              omittedText: 'Source unavailable; UI state omitted.',
            ),
    );
    sent.add(saved.message);
    return ChatInputSubmissionResult.sent;
  }

  Future<void> close() async {
    service.dispose();
    await repository.close();
  }
}

/// Avoids ChatService startup asset maintenance on the user's app directories.
/// Source validity still delegates to the real isolated database transaction.
class _ScenarioChatService extends ChatService {
  _ScenarioChatService(this.repository) : super(existingRepository: repository);
  final ChatDatabaseRepository repository;
  @override
  Future<bool> isUiContextCurrent(UiContextSource source) =>
      repository.isUiContextCurrent(source);
}

class GenUiScenarioHost extends StatefulWidget {
  const GenUiScenarioHost({
    super.key,
    required this.session,
    required this.scene,
    required this.services,
    this.dark = false,
    this.scale = 1,
    this.rtl = false,
  });
  final GenUiScenarioSession session;
  final String scene;
  final MessageTestServices services;
  final bool dark, rtl;
  final double scale;
  @override
  State<GenUiScenarioHost> createState() => GenUiScenarioHostState();
}

class GenUiScenarioHostState extends State<GenUiScenarioHost> {
  final scroll = ScrollController();
  final list = ListController();
  final processing = ValueNotifier<String?>(null);
  final text = TextEditingController();
  final focus = FocusNode();
  final media = ChatInputBarController();
  int requests = 0;
  @override
  void dispose() {
    scroll.dispose();
    list.dispose();
    processing.dispose();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.services.wrap(
    ChangeNotifierProvider<ChatService>.value(
      value: widget.session.service,
      child: MaterialApp(
        theme: widget.dark ? buildDarkTheme(null) : buildLightTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(widget.scale)),
          child: Directionality(
            textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: ChatInputOverlayLayout(
                topInset: 0,
                content: UiActionsScope(
                  onDraft: (request) async {
                    requests++;
                    await stageUiComposerDraft(
                      context,
                      request: request,
                      target: media.capture(),
                      isCurrent: () => mounted,
                    );
                  },
                  child: MessageListView(
                    scrollController: scroll,
                    listController: list,
                    messages: [
                      widget.session.messages[widget.scene]!,
                      if (widget.scene == 'S6') ...widget.session.sent,
                    ],
                    byGroup: const {},
                    versionSelections: const {},
                    reasoning: const {},
                    reasoningSegments: const {},
                    contentSplits: const {},
                    toolParts: const {},
                    translations: const {},
                    selecting: false,
                    selectedItems: const {},
                    dividerPadding: EdgeInsets.zero,
                    processingFilesMessageId: processing,
                  ),
                ),
                bottomOverlay: ChatInputBar(
                  controller: text,
                  focusNode: focus,
                  mediaController: media,
                  conversationId: GenUiScenarioSession.conversation,
                  onSend: (input) async {
                    final result = await widget.session.send(input);
                    if (mounted) setState(() {});
                    return result;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
