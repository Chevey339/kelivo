import 'genui_control_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'genui_interactions.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

class GenUiButton extends StatefulWidget {
  const GenUiButton({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiButton> createState() => _GenUiButtonState();
}

class _GenUiButtonState extends State<GenUiButton> {
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _unregisterAction;
  bool _focused = false, _busy = false;
  String? _error;
  String? get _form => widget.node.properties['form'] as String?;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller ||
        scope.registrationOwner != _scope?.registrationOwner) {
      _scope = scope;
      _unregisterAction?.call();
      _unregisterAction = scope.registerAction(widget.id, _activate);
      _subscribe();
    }
    _scope = scope;
  }

  void _subscribe() {
    _unsubscribe?.call();
    _unsubscribe = _form == null
        ? null
        : _scope!.controller.listen(_form!, () {
            if (mounted) setState(() {});
          });
  }

  @override
  void didUpdateWidget(GenUiButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.properties['form'] != _form) _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unregisterAction?.call();
    super.dispose();
  }

  String? _reason(AppLocalizations l10n) {
    final scope = _scope!;
    if (scope.readOnly) {
      return switch (scope.controller.surface.phase) {
        SurfacePhase.streaming => l10n.genuiReadOnlyUntilComplete,
        SurfacePhase.interrupted => l10n.genuiStatusInterrupted,
        _ => l10n.genuiReadOnlySnapshot,
      };
    }
    if (!widget.node.valid) {
      final diagnostic = widget.node.diagnostics.firstOrNull;
      return diagnostic == null
          ? l10n.genuiNodeUnavailable
          : diagnostic.code == UiDiagnosticCode.dependency &&
                diagnostic.detail.isNotEmpty
          ? l10n.genuiActionDisabledDep(diagnostic.detail)
          : genUiDiagnosticMessage(l10n, diagnostic);
    }
    if (scope.controller.tree.enabled[widget.id] != true) {
      return l10n.genuiActionDisabled;
    }
    if (_form case final form?) {
      if (scope.controller.tree.enabled[form] != true ||
          scope.controller.tree.visible[form] != true) {
        return l10n.genuiActionDisabled;
      }
      final invalid = scope.controller.checkForm(form).unavailable.firstOrNull;
      if (invalid != null) return l10n.genuiActionDisabledDep(invalid);
    }
    if (widget.node.declaration.arguments['action'] is UiAsk &&
        scope.onAsk == null) {
      return l10n.genuiActionUnavailable;
    }
    return null;
  }

  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_busy || _reason(l10n) != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _scope!.activate(
        context,
        widget.id,
        token: widget.token,
      );
      if (mounted && result.block != null && result.form == null) {
        setState(() => _error = l10n.genuiActionUnavailable);
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.genuiActionUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope!;
    if (scope.exporting) return const SizedBox.shrink();
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = widget.node.properties['label'] as String;
    final reason = _reason(l10n);
    final enabled = reason == null && !_busy;
    final variant = widget.node.properties['variant'] as String? ?? 'tonal';
    final visualEnabled = reason == null || scope.readOnly;
    final background = !visualEnabled
        ? theme.fill
        : variant == 'primary'
        ? theme.primary
        : variant == 'plain'
        ? theme.transparent
        : theme.fill;
    final foreground = visualEnabled
        ? variant == 'primary'
              ? theme.onPrimary
              : theme.ink
        : theme.disabledInk;
    Widget button = FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (enabled) _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        hint: reason,
        onTap: enabled ? _activate : null,
        child: ExcludeSemantics(
          child: IosCardPress(
            haptics: false,
            onTap: enabled ? _activate : null,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            baseColor: theme.transparent,
            pressedScale: 0.98,
            borderRadius: BorderRadius.circular(theme.controlRadius),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.xxs),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
                padding: EdgeInsets.symmetric(
                  horizontal: theme.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(theme.controlRadius),
                  border: Border.all(
                    color: _focused ? theme.primary : theme.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    style: theme.header.copyWith(color: foreground),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (reason != null) {
      button = Tooltip(
        message: reason,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenUiControlRegion(child: button),
        if (!scope.readOnly && (reason != null || _error != null)) ...[
          SizedBox(height: theme.xxs),
          if (reason != null)
            ExcludeSemantics(child: Text(reason, style: theme.caption))
          else
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: theme.caption.copyWith(color: theme.error),
              ),
            ),
        ],
      ],
    );
  }
}
