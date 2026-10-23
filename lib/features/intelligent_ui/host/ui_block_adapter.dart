import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';
import '../runtime/ui_surface_state.dart';
import '../widgets/genui_surface.dart';
import 'ui_host_scope.dart';
import 'ui_runtime_registry.dart';
import 'ui_source_map.dart';

/// Source reduction runs in lifecycle hooks, never in a widget build method.
class UiBlockAdapter extends StatefulWidget {
  const UiBlockAdapter({
    super.key,
    required this.host,
    required this.registry,
    required this.fence,
    required this.theme,
    this.linkHandler,
  });
  final UiHostScope host;
  final UiRuntimeRegistry registry;
  final UiSourceFence fence;
  final MarkstreamTheme theme;
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
  Widget build(BuildContext context) =>
      !_entry.controller.parsed.headerAccepted &&
          !_entry.controller.parsed.invalid
      ? const SizedBox.shrink()
      : GenUiSurface(
          controller: _entry.controller,
          interactions: _entry.interactions,
          markdownTheme: widget.theme,
          linkHandler: widget.linkHandler,
          exporting: widget.host.exporting,
          onAsk: widget.host.binding.onAsk,
        );
}
