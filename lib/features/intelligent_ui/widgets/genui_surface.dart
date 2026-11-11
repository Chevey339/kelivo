import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'genui_diagnostic_source.dart';
import 'genui_motion.dart';
import 'genui_control_region.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'genui_content.dart';
import 'genui_interactions.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'genui_localizations.dart';
import 'genui_node.dart';
import 'genui_theme.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';

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
    this.expandFocusNode,
    this.onExport,
    this.onRepair,
    this.onRetrySave,
    this.exporting = false,
    this.expanded = false,
    this.showHeader = true,
    this.interactions,
    this.onAsk,
    this.onAttach,
  });
  final UiSurfaceController controller;
  final String? title;
  final ms.MarkstreamTheme? markdownTheme;
  final ms.LinkHandler? linkHandler;
  final Future<void> Function()? onExpand;
  final FocusNode? expandFocusNode;
  final Future<void> Function()? onExport;
  final VoidCallback? onRepair;
  final VoidCallback? onRetrySave;
  final bool exporting;
  final bool expanded;
  final bool showHeader;
  final UiInteractionController? interactions;
  final GenUiAskHandler? onAsk;
  final Future<void> Function(UiAttachIntent)? onAttach;

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    markdownTheme: markdownTheme,
    opaque: exporting || expanded,
    child: GenUiInteractionHost(
      surface: controller,
      interactions: interactions,
      onAsk: onAsk,
      exporting: exporting,
      child: _SurfaceBody(surface: this),
    ),
  );
}

class _SurfaceBody extends StatefulWidget {
  const _SurfaceBody({required this.surface});
  final GenUiSurface surface;
  @override
  State<_SurfaceBody> createState() => _SurfaceBodyState();
}

class _SurfaceBodyState extends State<_SurfaceBody>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _sourceFocus = FocusNode(debugLabel: 'GenUI source');
  final _localExpandFocus = FocusNode(debugLabel: 'GenUI expand');
  FocusNode get _expandFocus =>
      widget.surface.expandFocusNode ?? _localExpandFocus;
  final _localMoreFocus = FocusNode(debugLabel: 'GenUI more');
  FocusNode get _moreFocus =>
      widget.surface.showHeader ? _localMoreFocus : _expandFocus;
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
    if (mounted && next != _chrome) {
      _syncMotion();
      setState(() => _chrome = next);
    }
  }

  void _syncMotion() {
    if (controller.phase == SurfacePhase.streaming &&
        !MediaQuery.disableAnimationsOf(context) &&
        !widget.surface.exporting) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
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
    _syncMotion();
  }

  @override
  void dispose() {
    _unsubscribe();
    _motion.dispose();
    _sourceFocus.dispose();
    _localExpandFocus.dispose();
    _localMoreFocus.dispose();
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
        opaque: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.genuiViewSource),
            Flexible(
              child: SingleChildScrollView(
                child: AppSelectionArea(
                  copyByteLimit: UiBudgets.copyBytes,
                  child: Padding(
                    padding: EdgeInsets.all(GenUiTheme.of(context).sm),
                    child: controller.phase == SurfacePhase.invalid
                        ? GenUiDiagnosticSource(
                            source: source,
                            errorLines: {
                              for (final d
                                  in controller.parsed.program.diagnostics)
                                d.line,
                            },
                          )
                        : GenUiSource(source: source),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      (widget.surface.showHeader ? _sourceFocus : _moreFocus).requestFocus();
    }
  }

  Future<void> _showMore() async {
    final l10n = AppLocalizations.of(context)!;
    final token = controller.token;
    final onAttach = widget.surface.onAttach;
    final action = await showAppDialog<String>(
      context,
      maxWidth: 360,
      child: Builder(
        builder: (dialogContext) => GenUiThemeScope(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDialogHeader(title: l10n.genuiMore),
                if (!widget.surface.showHeader) ...[
                  IosTextButton(
                    label: l10n.genuiViewSource,
                    icon: LucideIcons.codeXml,
                    color: GenUiTheme.of(dialogContext).ink,
                    mainAxisAlignment: MainAxisAlignment.start,
                    onPressed: () => Navigator.of(dialogContext).pop('source'),
                  ),
                  if (widget.surface.onExpand != null)
                    IosTextButton(
                      label: l10n.genuiExpand,
                      icon: LucideIcons.expand,
                      color: GenUiTheme.of(dialogContext).ink,
                      mainAxisAlignment: MainAxisAlignment.start,
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('expand'),
                    ),
                ],
                if (widget.surface.onAttach != null && !controller.readOnly)
                  IosTextButton(
                    label: l10n.genuiAttachState,
                    icon: LucideIcons.paperclip,
                    color: GenUiTheme.of(dialogContext).ink,
                    mainAxisAlignment: MainAxisAlignment.start,
                    onPressed: () => Navigator.of(dialogContext).pop('attach'),
                  ),
                if (widget.surface.onExport != null)
                  IosTextButton(
                    label: l10n.genuiExportSnapshot,
                    icon: LucideIcons.image,
                    color: GenUiTheme.of(dialogContext).ink,
                    mainAxisAlignment: MainAxisAlignment.start,
                    onPressed: () => Navigator.of(dialogContext).pop('export'),
                  ),
                IosTextButton(
                  label: l10n.genuiReset,
                  icon: LucideIcons.rotateCcw,
                  color: GenUiTheme.of(dialogContext).secondaryInk,
                  mainAxisAlignment: MainAxisAlignment.start,
                  onPressed: controller.readOnly
                      ? null
                      : () => Navigator.of(dialogContext).pop('reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'export' && !controller.accepts(token)) {
      showAppSnackBar(
        context,
        message: l10n.genuiTextFailed,
        type: NotificationType.error,
      );
      _moreFocus.requestFocus();
      return;
    }
    if (action == 'source') {
      await _showSource();
    } else if (action == 'expand') {
      await _expand();
    } else if (action == 'attach') {
      final result = await GenUiInteractions.of(
        context,
      ).captureForAttach(context, token: token);
      if (!mounted) return;
      if (result.attachment case final intent?) {
        await onAttach?.call(intent);
        return; // Successful staging owns composer focus.
      } else if (result.form?.firstField != null) {
        return; // Keep focus at the invalid field.
      }
    } else if (action == 'export') {
      await widget.surface.onExport?.call();
    } else if (action == 'reset') {
      controller.reset(token: token);
      controller.flushQuietly();
    }
    if (mounted) _moreFocus.requestFocus();
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
          visualSize: 28,
          color: theme.captionInk,
          tooltip: l10n.genuiViewSource,
          focusNode: _sourceFocus,
          onTap: _showSource,
        ),
        if (!surface.expanded)
          IosIconButton(
            icon: LucideIcons.expand,
            size: 16,
            minSize: 44,
            visualSize: 28,
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
          visualSize: 28,
          color: theme.captionInk,
          tooltip: l10n.genuiMore,
          focusNode: _moreFocus,
          onTap: _showMore,
        ),
      ],
    );
    Widget heading() => Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            LucideIcons.panelsTopLeft,
            size: 16,
            color: theme.secondaryInk,
          ),
        ),
        SizedBox(width: theme.xs),
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              title,
              style: theme.header.copyWith(color: theme.secondaryInk),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            : l10n.genuiSomeValuesUnavailable,
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
    return GenUiMotion(
      animation: _motion,
      child: Semantics(
        container: true,
        label: title,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (surface.showHeader)
                  Container(
                    key: const ValueKey('genui-surface-header'),
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: EdgeInsetsDirectional.only(
                      start: theme.sm,
                      end: theme.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.headerFill,
                      border: Border(bottom: BorderSide(color: theme.hairline)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < 480 ||
                            MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                        if (compact) {
                          final inlineStatus =
                              status.length == 1 &&
                              constraints.maxWidth >= 320 &&
                              MediaQuery.textScalerOf(context).scale(1) < 1.3;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: heading()),
                                  if (inlineStatus) status.single,
                                  if (actions)
                                    GenUiControlRegion(child: buttons),
                                ],
                              ),
                              if (status.isNotEmpty && !inlineStatus)
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
                            if (actions) GenUiControlRegion(child: buttons),
                          ],
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    ResponsiveHelper.isMobile(context) ? 14 : theme.md,
                    theme.sm,
                    ResponsiveHelper.isMobile(context) ? 14 : theme.md,
                    !surface.showHeader && actions ? 0 : theme.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!surface.showHeader && status.isNotEmpty) ...[
                        Wrap(
                          spacing: theme.xs,
                          runSpacing: theme.xxs,
                          children: status,
                        ),
                        SizedBox(height: theme.xs),
                      ],
                      if (invalid) ...[
                        GenUiCallout(
                          title: l10n.genuiInvalidTitle,
                          text: diagnostic != null
                              ? '${genUiDiagnosticMessage(l10n, diagnostic)} · ${l10n.genuiErrorLine(diagnostic.line)}'
                              : l10n.genuiNodeUnavailable,
                          tone: 'error',
                        ),
                        SizedBox(height: theme.sm),
                        GenUiDiagnosticSource(
                          source: controller.parsed.source,
                          errorLines: {
                            for (final d
                                in controller.parsed.program.diagnostics)
                              d.line,
                          },
                          exporting: surface.exporting,
                        ),
                        if (actions)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Tooltip(
                              message: surface.onRepair == null
                                  ? l10n.genuiActionUnavailable
                                  : l10n.genuiRepair,
                              child: GenUiControlRegion(
                                child: IosTextButton(
                                  label: l10n.genuiRepair,
                                  onPressed: surface.onRepair,
                                ),
                              ),
                            ),
                          ),
                      ] else
                        GenUiNode(
                          controller: controller,
                          id: 'root',
                          linkHandler: surface.linkHandler,
                        ),
                    ],
                  ),
                ),
                if (!surface.showHeader && actions)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: GenUiControlRegion(
                      child: IosIconButton(
                        key: const ValueKey('genui-immersive-more'),
                        icon: LucideIcons.ellipsis,
                        size: 16,
                        minSize: 44,
                        visualSize: 28,
                        color: theme.captionInk,
                        tooltip: l10n.genuiMore,
                        focusNode: _moreFocus,
                        onTap: _showMore,
                      ),
                    ),
                  ),
                if (footer != null)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      theme.sm,
                      0,
                      theme.sm,
                      theme.xs,
                    ),
                    child: footer,
                  ),
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
          if (action != null)
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: action!,
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneratingBadge extends StatelessWidget {
  const _GeneratingBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Semantics(
      liveRegion: true,
      label: text,
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
              text,
              style: theme.badge.copyWith(color: theme.onPrimaryContainer),
            ),
            SizedBox(width: theme.xxs),
            CustomPaint(
              size: const Size(18, 8),
              painter: _Dots(GenUiMotion.of(context), theme),
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
