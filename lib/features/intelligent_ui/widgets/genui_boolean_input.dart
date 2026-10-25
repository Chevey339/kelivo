import 'genui_control_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'genui_field_frame.dart';
import 'genui_interactions.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

class GenUiBooleanInput extends StatefulWidget {
  const GenUiBooleanInput({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiBooleanInput> createState() => _GenUiBooleanInputState();
}

class _GenUiBooleanInputState extends State<GenUiBooleanInput> {
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _unregister;
  final _focus = FocusNode();
  bool _focused = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller ||
        scope.registrationOwner != _scope?.registrationOwner) {
      _unsubscribe?.call();
      _unregister?.call();
      _unsubscribe = scope.controller.listen(widget.id, () {
        if (mounted) setState(() {});
      });
      _unregister = scope.registerFocus(widget.id, _focus, context);
    }
    _scope = scope;
  }

  void _set(bool value) {
    final scope = _scope!;
    if (!scope.readOnly && scope.controller.surface.accepts(widget.token)) {
      _focus.requestFocus();
      scope.controller.setValue(widget.id, value, token: widget.token);
    }
  }

  void _toggle() {
    final value =
        _scope!.controller.surface.nodes[widget.id]?.properties['bind'];
    if (value is bool) _set(!value);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unregister?.call();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scope = _scope!;
    final props = widget.node.properties;
    final label = props['label'] as String;
    final value = props['bind'] as bool;
    final required = props['required'] == true;
    final enabled = scope.controller.tree.enabled[widget.id] == true;
    final interactive = enabled && !scope.readOnly;
    final isSwitch = widget.node.declaration.component == 'Switch';
    final issue = scope.controller.issue(widget.id);
    final error = issue == null ? null : genUiFieldIssueMessage(l10n, issue);
    final control = isSwitch
        ? IosSwitch(
            value: value,
            onChanged: enabled ? (_) => _toggle() : null,
            activeColor: theme.primary,
            inactiveColor: theme.fill,
            enableHaptics: false,
            hitTestSize: 44,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
          )
        : IosCheckbox(
            value: value,
            onChanged: enabled ? (_) => _toggle() : null,
            activeColor: theme.primary,
            checkmarkColor: theme.onPrimary,
            borderColor: error != null ? theme.error : theme.hairlineStrong,
            enableHaptics: false,
            hitTestSize: 44,
          );
    final text = Expanded(
      child: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: enabled ? theme.error : theme.disabledInk,
                ),
              ),
          ],
        ),
        style: theme.body.copyWith(
          color: enabled ? theme.ink : theme.disabledInk,
        ),
      ),
    );
    return GenUiFieldFrame(
      label: '',
      error: error,
      child: GenUiControlRegion(
        child: FocusableActionDetector(
          focusNode: _focus,
          enabled: interactive,
          onFocusChange: (focused) {
            if (focused) {
              scope.controller.surface.noteInteraction(token: widget.token);
            }
          },
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (interactive) _toggle();
                return null;
              },
            ),
          },
          child: Semantics(
            label: label,
            enabled: interactive,
            checked: isSwitch ? null : value,
            toggled: isSwitch ? value : null,
            hint: [
              if (required) l10n.genuiFieldRequired,
              if (error != null) error,
            ].join('. '),
            onTap: interactive ? _toggle : null,
            child: ExcludeSemantics(
              child: IgnorePointer(
                ignoring: scope.readOnly,
                child: MouseRegion(
                  cursor: interactive
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: interactive ? _toggle : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          theme.controlRadius,
                        ),
                        border: Border.all(
                          color: _focused ? theme.primary : theme.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: isSwitch
                            ? [text, SizedBox(width: theme.xs), control]
                            : [control, SizedBox(width: theme.xs), text],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
