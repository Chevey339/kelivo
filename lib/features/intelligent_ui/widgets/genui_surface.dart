import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'genui_content.dart';
import 'genui_localizations.dart';
import 'genui_node.dart';
import 'genui_theme.dart';

/// Native card chrome. The host retains controller ownership across message
/// rebuilds and supplies actions only when their integration is available.
class GenUiSurface extends StatelessWidget {
  const GenUiSurface({
    super.key,
    required this.controller,
    this.title,
    this.markdownTheme,
    this.linkHandler,
    this.onExpand,
    this.onRepair,
    this.onRetrySave,
    this.exporting = false,
  });
  final UiSurfaceController controller;
  final String? title;
  final ms.MarkstreamTheme? markdownTheme;
  final ms.LinkHandler? linkHandler;
  final Future<void> Function()? onExpand;
  final VoidCallback? onRepair;
  final VoidCallback? onRetrySave;
  final bool exporting;

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    markdownTheme: markdownTheme,
    child: _SurfaceBody(surface: this),
  );
}

class _SurfaceBody extends StatefulWidget {
  const _SurfaceBody({required this.surface});
  final GenUiSurface surface;
  @override
  State<_SurfaceBody> createState() => _SurfaceBodyState();
}

class _SurfaceBodyState extends State<_SurfaceBody> {
  final _sourceFocus = FocusNode(debugLabel: 'GenUI source');
  final _expandFocus = FocusNode(debugLabel: 'GenUI expand');
  final _moreFocus = FocusNode(debugLabel: 'GenUI more');
  final _subscriptions = <VoidCallback>[];
  Object? _chrome;
  UiSurfaceController get controller => widget.surface.controller;
  int get _failedNodes =>
      controller.nodes.values.where((n) => !n.valid && !n.pending).length;

  Object _chromeState() => (
    controller.parsed,
    controller.phase,
    controller.readOnly,
    controller.saveFailed,
    _failedNodes,
  );
  void _refresh() {
    final next = _chromeState();
    if (mounted && next != _chrome) setState(() => _chrome = next);
  }

  void _subscribe() {
    _chrome = _chromeState();
    _subscriptions.addAll([
      controller.listenStatus(_refresh),
      controller.listenState(_refresh),
      // Source updates are published even if the phase stays unchanged.
      controller.listenNode('root', _refresh),
    ]);
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
  void didUpdateWidget(_SurfaceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface.controller != controller) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _sourceFocus.dispose();
    _expandFocus.dispose();
    _moreFocus.dispose();
    super.dispose();
  }

  Future<void> _showSource() async {
    final source = controller.parsed.source;
    final markdown = widget.surface.markdownTheme;
    final l10n = AppLocalizations.of(context)!;
    await showAppDialog<void>(
      context,
      maxWidth: 720,
      child: GenUiThemeScope(
        markdownTheme: markdown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.genuiViewSource),
            Flexible(
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Padding(
                    padding: EdgeInsets.all(GenUiTheme.of(context).sm),
                    child: GenUiSource(source: source),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) _sourceFocus.requestFocus();
  }

  Future<void> _showMore() async {
    final l10n = AppLocalizations.of(context)!;
    final token = controller.token;
    final reset = await showAppDialog<bool>(
      context,
      child: GenUiThemeScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.genuiMore),
            IosTextButton(
              label: l10n.genuiReset,
              icon: LucideIcons.rotateCcw,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (reset == true) controller.reset(token: token);
    _moreFocus.requestFocus();
  }

  Future<void> _expand() async {
    await widget.surface.onExpand?.call();
    if (mounted) _expandFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final surface = widget.surface;
    final phase = controller.phase;
    final title = surface.title ?? l10n.genuiSurfaceTitle;
    final invalid = phase == SurfacePhase.invalid;
    final interrupted = phase == SurfacePhase.interrupted;
    final streaming = phase == SurfacePhase.streaming;
    final errors = phase == SurfacePhase.completeWithErrors;
    final actions = !surface.exporting;
    final diagnostic = controller.parsed.program.diagnostics.firstOrNull;
    final canReset =
        !controller.readOnly &&
        controller.parsed.program.declarations.isNotEmpty;
    final status = <Widget>[
      if (streaming) _GeneratingBadge(text: l10n.genuiStatusStreaming),
      if (interrupted)
        GenUiBadge(text: l10n.genuiStatusInterrupted, tone: 'warning'),
      if (controller.saveFailed && actions)
        IosIconButton(
          tooltip: l10n.genuiStatusUnsavedRetry,
          semanticLabel: l10n.genuiStatusUnsaved,
          minSize: 44,
          padding: EdgeInsets.zero,
          onTap: surface.onRetrySave,
          enabled: surface.onRetrySave != null,
          builder: (_) => ExcludeSemantics(
            child: GenUiBadge(text: l10n.genuiStatusUnsaved, tone: 'warning'),
          ),
        ),
    ];
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IosIconButton(
          icon: LucideIcons.codeXml,
          size: 16,
          minSize: 44,
          color: theme.captionInk,
          tooltip: l10n.genuiViewSource,
          focusNode: _sourceFocus,
          onTap: _showSource,
        ),
        IosIconButton(
          icon: LucideIcons.expand,
          size: 16,
          minSize: 44,
          color: theme.captionInk,
          tooltip: l10n.genuiExpand,
          focusNode: _expandFocus,
          enabled: surface.onExpand != null,
          onTap: surface.onExpand != null ? _expand : null,
        ),
        IosIconButton(
          icon: LucideIcons.ellipsis,
          size: 16,
          minSize: 44,
          color: theme.captionInk,
          tooltip: l10n.genuiMore,
          focusNode: _moreFocus,
          enabled: canReset,
          onTap: canReset ? _showMore : null,
        ),
      ],
    );
    Widget heading() => Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            LucideIcons.panelsTopLeft,
            size: 16,
            color: theme.primary,
          ),
        ),
        SizedBox(width: theme.xs),
        Expanded(
          child: ExcludeSemantics(child: Text(title, style: theme.header)),
        ),
      ],
    );
    Widget? footer;
    if (streaming) {
      footer = _Footer(
        icon: LucideIcons.lockKeyhole,
        text: l10n.genuiReadOnlyUntilComplete,
      );
    } else if (interrupted) {
      footer = _Footer(
        icon: LucideIcons.circlePause,
        text: l10n.genuiStatusInterrupted,
        action: actions
            ? IosTextButton(label: l10n.genuiViewSource, onPressed: _showSource)
            : null,
      );
    } else if (errors) {
      footer = _Footer(
        icon: LucideIcons.triangleAlert,
        text: _failedNodes > 0
            ? l10n.genuiNodesFailed(_failedNodes)
            : l10n.genuiValueUnavailable,
        action: actions && surface.onRepair != null
            ? IosTextButton(
                label: l10n.genuiRepair,
                onPressed: surface.onRepair,
              )
            : null,
      );
    } else if (surface.exporting || (!invalid && controller.readOnly)) {
      footer = _Footer(
        icon: LucideIcons.lockKeyhole,
        text: l10n.genuiReadOnlySnapshot,
      );
    }
    return Semantics(
      container: true,
      label: title,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.hairline),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 480 ||
                        MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: heading()),
                              if (actions) buttons,
                            ],
                          ),
                          if (status.isNotEmpty)
                            Wrap(
                              spacing: theme.xs,
                              runSpacing: theme.xxs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: status,
                            ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading()),
                        ...status,
                        if (actions) buttons,
                      ],
                    );
                  },
                ),
                SizedBox(height: theme.sm),
                if (invalid) ...[
                  GenUiCallout(
                    title: l10n.genuiInvalidTitle,
                    text: diagnostic != null
                        ? '${genUiDiagnosticMessage(l10n, diagnostic)} · ${l10n.genuiErrorLine(diagnostic.line)}'
                        : l10n.genuiNodeUnavailable,
                    tone: 'error',
                  ),
                  SizedBox(height: theme.sm),
                  GenUiSource(
                    source: controller.parsed.source,
                    exporting: surface.exporting,
                  ),
                  if (actions && surface.onRepair != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IosTextButton(
                        label: l10n.genuiRepair,
                        onPressed: surface.onRepair,
                      ),
                    ),
                ] else
                  GenUiNode(
                    controller: controller,
                    id: 'root',
                    linkHandler: surface.linkHandler,
                  ),
                if (footer != null) ...[SizedBox(height: theme.sm), footer],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Container(
      padding: EdgeInsetsDirectional.only(top: theme.xs),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.hairline)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 14, color: theme.captionInk),
          ),
          SizedBox(width: theme.xs),
          Expanded(child: Text(text, style: theme.caption)),
          if (action != null) Flexible(child: action!),
        ],
      ),
    );
  }
}

class _GeneratingBadge extends StatefulWidget {
  const _GeneratingBadge({required this.text});
  final String text;
  @override
  State<_GeneratingBadge> createState() => _GeneratingBadgeState();
}

class _GeneratingBadgeState extends State<_GeneratingBadge>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Semantics(
      liveRegion: true,
      label: widget.text,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.xs,
          vertical: theme.xxs,
        ),
        decoration: BoxDecoration(
          color: theme.primaryContainer,
          borderRadius: BorderRadius.circular(theme.capsuleRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: theme.badge.copyWith(color: theme.onPrimaryContainer),
            ),
            SizedBox(width: theme.xxs),
            CustomPaint(
              size: const Size(18, 8),
              painter: _Dots(_animation, theme),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  _Dots(this.animation, this.theme) : super(repaint: animation);
  final Animation<double> animation;
  final GenUiTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    final active = (animation.value * 3).floor().clamp(0, 2);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(3 + i * 6, size.height / 2),
        1.5,
        Paint()
          ..color = i == active ? theme.onPrimaryContainer : theme.captionInk,
      );
    }
  }

  @override
  bool shouldRepaint(_Dots oldDelegate) => oldDelegate.theme != theme;
}
