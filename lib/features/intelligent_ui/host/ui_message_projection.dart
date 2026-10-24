import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../runtime/ui_surface_controller.dart';
import '../catalog/ui_budgets.dart';
import '../runtime/ui_surface_state.dart';
import '../storage/ui_state_repository.dart';
import '../text/ui_message_text.dart';
import '../text/ui_text_projection.dart';
import '../widgets/genui_localizations.dart';
import 'ui_generation_state.dart';
import 'ui_runtime_registry.dart';
import 'ui_presented_fences.dart';

Future<UiMessageText> captureUiMessageText(
  BuildContext context,
  ChatMessage message,
) {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ChatService?>();
  final registry = UiRuntimeScope.maybeOf(context);
  // Freeze accepted values before the first await, including off-screen cards
  // and temporary chats. Never let a later drag mutate this copy or narration.
  final snapshots =
      registry?.captureCopySnapshots([message]) ??
      service?.captureGenUiSnapshots([message]) ??
      const <UiSurfaceSnapshot>[];
  return projectUiMessageText(
    message,
    projection: UiTextProjection(genUiProjectionLabels(l10n)),
    snapshots: snapshots,
    store: service?.isTemporaryConversation(message.conversationId) == true
        ? null
        : service?.chatRepositoryOrNull?.genUiStates,
    blockLimit: l10n.genuiBlockLimit,
  );
}

/// Original source is the only authority: user/tool/quoted/transformed fences
/// remain ordinary text. Reconstruction is read-only and owns no widgets.
Future<UiMessageText> projectUiMessageText(
  ChatMessage message, {
  required UiTextProjection projection,
  Iterable<UiSurfaceSnapshot> snapshots = const [],
  UiStateRepository? store,
  required String blockLimit,
  UiTextMode mode = UiTextMode.copy,
}) async {
  final fences = uiPresentedNativeFences(message);
  final generation = uiGenerationStatus(message);
  final frozen = List<UiSurfaceSnapshot>.unmodifiable(snapshots);
  final parts = <TtsTextPart>[];
  final replacements = <UiMessageReplacement>[];
  final surfaces = <UiCapturedSurface>[];
  final source = message.content;
  var cursor = 0;
  for (final (:ordinal, :fence) in fences) {
    final start = fence.run.joinedStart + fence.node.span.start;
    final end = fence.run.joinedStart + fence.node.span.end;
    if (start > cursor) {
      parts.add(TtsTextPart(source.substring(cursor, start)));
    }
    String text;
    if (ordinal >= UiBudgets.blocksPerMessage) {
      text = blockLimit;
    } else {
      final owner = UiSurfaceOwner(
        revisionId: message.id,
        surfaceKey: fence.surfaceKey,
      );
      final controller = UiSurfaceController(owner: owner, readOnly: true);
      try {
        controller.updateSource(
          fence.body,
          closed: fence.node.closed,
          generation: generation,
        );
        if (controller.canSnapshot) {
          var saved = frozen
              .where(
                (s) =>
                    s.owner == owner && s.sourceHash == controller.sourceHash,
              )
              .firstOrNull;
          if (saved == null && store != null) {
            final lease = store.attach(
              message.conversationId,
              owner,
              controller.sourceHash!,
            );
            if (lease == null) throw StateError('genui_not_ready');
            final loaded = await store.load(lease);
            if (!loaded.valid) throw StateError('genui_source_changed');
            saved = loaded.snapshot;
          }
          if (saved != null) {
            controller.restore(saved, token: controller.restoreToken);
          }
        }
        text = projection.text(controller.captureRead(), mode: mode);
        surfaces.add(
          UiCapturedSurface(
            owner: owner,
            source: fence.body,
            closed: fence.node.closed,
            generation: generation,
            snapshot: controller.canSnapshot
                ? controller.captureSnapshot()
                : null,
          ),
        );
      } finally {
        controller.dispose();
      }
    }
    replacements.add(UiMessageReplacement(start, end, text, fence.source));
    parts.add(TtsTextPart(text, literal: true));
    cursor = end;
  }
  if (cursor < source.length) parts.add(TtsTextPart(source.substring(cursor)));
  return UiMessageText(
    source: source,
    parts: parts,
    omitted: projection.labels.omitted,
    hasUi: fences.isNotEmpty,
    replacements: replacements,
    surfaces: surfaces,
  );
}
