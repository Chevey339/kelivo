import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../text/ui_message_text.dart';
import '../text/ui_text_projection.dart';
import '../runtime/ui_surface_state.dart';
import '../widgets/genui_localizations.dart';
import 'ui_message_projection.dart';
import 'ui_runtime_registry.dart';

/// All visible/off-screen accepted states freeze synchronously at the user's
/// export action, before diagram rendering, database reads or file pickers.
Future<UiExportCapture> captureUiExportMessages(
  BuildContext context,
  List<ChatMessage> messages,
) {
  messages = List.unmodifiable(messages.map((message) => message.copyWith()));
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ChatService?>();
  final registry = UiRuntimeScope.maybeOf(context);
  final snapshots =
      registry?.captureCopySnapshots(messages) ??
      service?.captureGenUiSnapshots(messages) ??
      const <UiSurfaceSnapshot>[];
  final projection = UiTextProjection(genUiProjectionLabels(l10n));
  final pending = [
    for (final message in messages)
      projectUiMessageText(
        message,
        projection: projection,
        snapshots: snapshots,
        store: service?.isTemporaryConversation(message.conversationId) == true
            ? null
            : service?.chatRepositoryOrNull?.genUiStates,
        blockLimit: l10n.genuiBlockLimit,
        mode: UiTextMode.export,
      ),
  ];
  return Future.wait(pending).then(
    (values) => UiExportCapture(
      messages: messages,
      projections: {
        for (var i = 0; i < messages.length; i++) messages[i].id: values[i],
      },
    ),
  );
}

/// Source parts and generation metadata must freeze with state, since storage
/// publishes parts and terminal generation proof onto live message instances.
final class UiExportCapture {
  UiExportCapture({
    required Iterable<ChatMessage> messages,
    required Map<String, UiMessageText> projections,
  }) : messages = List.unmodifiable(
         messages.map((message) => message.copyWith()),
       ),
       projections = Map.unmodifiable(projections);
  final List<ChatMessage> messages;
  final Map<String, UiMessageText> projections;
  bool get hasUi => projections.values.any((value) => value.hasUi);
}

/// Export owns an isolated read-only registry. No live subscriptions, write
/// bindings, drafts or focus objects are borrowed from the message list.
class UiExportSnapshotScope extends StatefulWidget {
  const UiExportSnapshotScope({
    super.key,
    required this.captures,
    required this.child,
  });
  final UiExportCapture captures;
  final Widget child;
  @override
  State<UiExportSnapshotScope> createState() => _UiExportSnapshotScopeState();
}

class _UiExportSnapshotScopeState extends State<UiExportSnapshotScope> {
  late UiRuntimeRegistry _registry;
  void _create() {
    _registry = UiRuntimeRegistry(readOnly: true);
    for (final message in widget.captures.messages) {
      for (final surface
          in widget.captures.projections[message.id]?.surfaces ??
              const <UiCapturedSurface>[]) {
        final controller = _registry
            .obtain(message.conversationId, surface.owner)
            .controller;
        controller.updateSource(
          surface.source,
          closed: surface.closed,
          generation: surface.generation,
        );
        if (surface.snapshot case final snapshot?) {
          if (!controller.restore(snapshot, token: controller.restoreToken)) {
            throw StateError('genui_export_snapshot_invalid');
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(UiExportSnapshotScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.captures, widget.captures)) {
      _registry.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiRuntimeScope(
    registry: _registry,
    child: Focus(
      descendantsAreFocusable: false,
      descendantsAreTraversable: false,
      child: IgnorePointer(child: widget.child),
    ),
  );
}
