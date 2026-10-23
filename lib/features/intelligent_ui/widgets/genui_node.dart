import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'genui_content.dart';
import 'genui_layout.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

/// One dependency subscription per node. The host owns the controller; widget
/// disposal only removes this observer, so off-screen messages retain state.
class GenUiNode extends StatefulWidget {
  const GenUiNode({
    super.key,
    required this.controller,
    required this.id,
    this.linkHandler,
  });
  final UiSurfaceController controller;
  final String id;
  final ms.LinkHandler? linkHandler;
  @override
  State<GenUiNode> createState() => _GenUiNodeState();
}

class _GenUiNodeState extends State<GenUiNode> {
  late void Function() _unsubscribe;
  void _subscribe() =>
      _unsubscribe = widget.controller.listenNode(widget.id, () {
        if (mounted) setState(() {});
      });
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(GenUiNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.id != widget.id) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final node = controller.nodes[widget.id];
    if (node?.pending == true ||
        (node == null &&
            (controller.parsed.program.pendingSymbols.contains(widget.id) ||
                controller.phase == SurfacePhase.streaming ||
                controller.phase == SurfacePhase.interrupted))) {
      return GenUiPendingNode(
        id: widget.id,
        component: node?.declaration.component,
      );
    }
    if (node == null || !node.valid) {
      final diagnostics =
          node?.diagnostics ??
          controller.parsed.program.diagnostics
              .where((d) => d.symbol == widget.id)
              .toList();
      return GenUiNodeError(
        id: widget.id,
        diagnostic:
            diagnostics.firstOrNull ??
            UiDiagnostic(
              UiDiagnosticCode.missingReference,
              line: 1,
              symbol: widget.id,
            ),
      );
    }
    if (!node.visible) return const SizedBox.shrink();
    final props = node.properties;
    final key = ValueKey((controller, widget.id, controller.token.epoch));
    Widget children(Widget Function(List<Widget>) builder) => _GenUiChildren(
      key: key,
      controller: controller,
      ids: (props['children'] as List).cast<String>(),
      linkHandler: widget.linkHandler,
      builder: builder,
    );
    return switch (node.declaration.component) {
      'Column' => children(
        (items) => GenUiColumn(gap: props['gap'] as String, children: items),
      ),
      'Row' => children(
        (items) => GenUiRow(
          gap: props['gap'] as String,
          distribution: props['distribution'] as String,
          children: items,
        ),
      ),
      'Section' => children(
        (items) => GenUiSection(
          title: props['title'] as String,
          subtitle: props['subtitle'] as String?,
          tone: props['tone'] as String,
          children: items,
        ),
      ),
      'Divider' => GenUiDivider(key: key, label: props['label'] as String?),
      'Text' => GenUiText(
        key: key,
        text: props['text'] as String,
        variant: props['variant'] as String?,
      ),
      'Markdown' => GenUiMarkdown(
        key: key,
        text: props['text'] as String,
        linkHandler: widget.linkHandler,
      ),
      'Formula' => GenUiFormula(
        key: key,
        tex: props['tex'] as String,
        label: props['label'] as String?,
      ),
      'Metric' => GenUiMetric(
        key: key,
        label: props['label'] as String,
        value: props['value'] as num?,
        unit: props['unit'] as String?,
        digits: (props['digits'] as num?)?.toInt(),
        trend: props['trend'] as num?,
      ),
      'Badge' => Align(
        alignment: AlignmentDirectional.centerStart,
        child: GenUiBadge(
          key: key,
          text: props['text'] as String,
          tone: props['tone'] as String,
        ),
      ),
      'Callout' => GenUiCallout(
        key: key,
        text: props['text'] as String,
        title: props['title'] as String?,
        tone: props['tone'] as String,
      ),
      _ => GenUiCallout(
        key: key,
        text: AppLocalizations.of(context)!.genuiNodeUnavailable,
        title: node.declaration.component,
        tone: 'error',
      ),
    };
  }
}

/// Layout depends on child visibility, not each child's value. Filtering here
/// removes hidden-field gaps without rebuilding ancestors on slider updates.
class _GenUiChildren extends StatefulWidget {
  const _GenUiChildren({
    super.key,
    required this.controller,
    required this.ids,
    required this.builder,
    this.linkHandler,
  });
  final UiSurfaceController controller;
  final List<String> ids;
  final Widget Function(List<Widget>) builder;
  final ms.LinkHandler? linkHandler;
  @override
  State<_GenUiChildren> createState() => _GenUiChildrenState();
}

class _GenUiChildrenState extends State<_GenUiChildren> {
  final _subscriptions = <void Function()>[];
  final _visibility = <String, bool>{};
  bool _visible(String id) {
    final node = widget.controller.nodes[id];
    return node == null || !node.valid || node.visible;
  }

  void _subscribe() {
    _visibility.clear();
    for (final id in widget.ids) {
      _visibility[id] = _visible(id);
      _subscriptions.add(
        widget.controller.listenNode(id, () {
          final value = _visible(id);
          if (mounted && _visibility[id] != value) {
            setState(() => _visibility[id] = value);
          }
        }),
      );
    }
  }

  void _unsubscribe() {
    for (final stop in _subscriptions) {
      stop();
    }
    _subscriptions.clear();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_GenUiChildren oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.ids != widget.ids) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder([
    for (final id in widget.ids)
      if (_visibility[id] != false)
        GenUiNode(
          key: ValueKey(id),
          controller: widget.controller,
          id: id,
          linkHandler: widget.linkHandler,
        ),
  ]);
}

String _displayId(String id) =>
    id.length <= 80 ? id : '${id.substring(0, 80)}…';

class GenUiPendingNode extends StatelessWidget {
  const GenUiPendingNode({super.key, required this.id, this.component});
  final String id;
  final String? component;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final height = switch (component) {
      'Chart' => 200.0,
      'DataTable' => 160.0,
      'Button' => 36.0,
      _ => 64.0,
    };
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.all(theme.sm),
      decoration: BoxDecoration(
        color: theme.cardFill,
        border: Border.all(color: theme.hairlineStrong),
        borderRadius: BorderRadius.circular(theme.controlRadius),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              LucideIcons.loaderCircle,
              size: 14,
              color: theme.captionInk,
            ),
          ),
          SizedBox(width: theme.xs),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.genuiPendingNode(_displayId(id)),
              style: theme.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class GenUiNodeError extends StatelessWidget {
  const GenUiNodeError({super.key, required this.id, required this.diagnostic});
  final String id;
  final UiDiagnostic diagnostic;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(theme.sm),
      decoration: BoxDecoration(
        color: theme.errorWash,
        borderRadius: BorderRadius.circular(theme.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(LucideIcons.circleAlert, size: 16, color: theme.error),
          ),
          SizedBox(width: theme.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayId(id),
                  style: theme.header.copyWith(color: theme.error),
                ),
                SizedBox(height: theme.xxs),
                Text(
                  genUiDiagnosticMessage(l10n, diagnostic),
                  style: theme.body,
                ),
                SizedBox(height: theme.xxs),
                Text(
                  l10n.genuiErrorLine(diagnostic.line),
                  style: theme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
