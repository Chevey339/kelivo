import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'ui_snapshot_export.dart';
import '../widgets/genui_expansion.dart';
import 'ui_search_navigation.dart';
import '../catalog/ui_budgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../text/ui_text_projection.dart';
import '../widgets/genui_localizations.dart';
import 'ui_draft_request.dart';
import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';
import '../runtime/ui_surface_state.dart';
import '../widgets/genui_surface.dart';
import 'ui_host_scope.dart';
import 'ui_runtime_registry.dart';
import 'ui_source_map.dart' show UiSourceFence;

/// Source reduction runs in lifecycle hooks, never in a widget build method.
class UiBlockAdapter extends StatefulWidget {
  const UiBlockAdapter({
    super.key,
    required this.host,
    required this.registry,
    required this.fence,
    required this.theme,
    required this.selectionNode,
    this.linkHandler,
  });
  final UiHostScope host;
  final UiRuntimeRegistry registry;
  final UiSourceFence fence;
  final MarkstreamTheme theme;
  final CodeBlockNode selectionNode;
  final LinkHandler? linkHandler;
  @override
  State<UiBlockAdapter> createState() => _UiBlockAdapterState();
}

class _UiBlockAdapterState extends State<UiBlockAdapter> {
  late UiRuntimeEntry _entry;
  void _update() {
    final binding = widget.host.binding;
    _entry = widget.registry.obtain(
      binding.conversationId,
      UiSurfaceOwner(
        revisionId: binding.revisionId,
        surfaceKey: widget.fence.surfaceKey,
      ),
    );
    _entry.controller.updateSource(
      widget.fence.body,
      closed: widget.fence.node.closed,
      generation: binding.generation,
    );
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(UiBlockAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  Widget build(BuildContext context) {
    final showHeader = context.select<SettingsProvider?, bool>(
      (settings) => settings?.showGenUiHeader ?? true,
    );
    final controller = _entry.controller;
    if (!controller.parsed.headerAccepted && !controller.parsed.invalid) {
      return const SizedBox.shrink();
    }
    final actions = UiActionsScope.of(context);
    final stage = actions?.onDraft;
    final conversation = widget.host.binding.conversationId;
    final l10n = AppLocalizations.of(context)!;
    final projection = UiTextProjection(genUiProjectionLabels(l10n));
    GenUiSurface buildSurface(
      Future<void> Function()? expand,
      FocusNode? focus,
      bool expanded,
    ) => GenUiSurface(
      controller: controller,
      interactions: _entry.interactions,
      markdownTheme: widget.theme,
      linkHandler: widget.linkHandler,
      exporting: widget.host.exporting,
      expanded: expanded,
      showHeader: showHeader,
      onExpand: expand,
      expandFocusNode: focus,
      onExport: widget.host.exporting
          ? null
          : () => exportUiSnapshot(
              context,
              controller,
              originalFence: widget.fence.source,
              markdownTheme: widget.theme,
            ),
      onAsk: stage == null
          ? actions?.onAsk
          : (intent) => stage(
              UiDraftRequest.attach(
                conversationId: conversation,
                snapshot: intent.snapshot,
                context: projection.context(
                  intent.read,
                  selected: intent.context,
                ),
                text: intent.text,
              ),
            ),
      onAttach: stage == null
          ? null
          : (intent) => stage(
              UiDraftRequest.attach(
                conversationId: conversation,
                snapshot: intent.snapshot,
                context: projection.context(intent.read),
              ),
            ),
      onRepair: stage == null
          ? null
          : () => stage(
              UiDraftRequest.repair(
                conversationId: conversation,
                controller: controller,
                introduction: l10n.genuiRepairDraft,
                omitted: l10n.genuiContextOmitted,
              ),
            ),
      onRetrySave: controller.flushQuietly,
    );
    return UiSearchReveal(
      conversationId: conversation,
      owner: controller.owner,
      enabled: !widget.host.exporting,
      child: MarkstreamSelectionProjection(
        node: widget.selectionNode,
        clipboardByteLimit: UiBudgets.copyBytes,
        project: (selected, complete) =>
            complete ? projection.text(controller.captureRead()) : selected,
        child: widget.host.exporting
            ? buildSurface(null, null, false)
            : GenUiExpansion(surfaceBuilder: buildSurface),
      ),
    );
  }
}
