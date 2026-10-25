import '../text/ui_number.dart';
import '../runtime/ui_numeric_step.dart';
import 'genui_control_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'genui_interactions.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';
import 'genui_field_frame.dart';

class GenUiTextInput extends StatefulWidget {
  const GenUiTextInput({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiTextInput> createState() => _GenUiTextInputState();
}

class _GenUiTextInputState extends State<GenUiTextInput> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _unregister;
  bool _syncing = false;
  TextEditingValue? _previous;
  bool get _number => widget.node.declaration.component == 'NumberField';
  Map<String, Object?> get props =>
      _scope?.controller.surface.nodes[widget.id]?.properties ??
      widget.node.properties;
  String _committed() {
    final value = props['bind'];
    return value == null
        ? ''
        : _number
        ? genUiNumber(value as num)
        : value as String;
  }

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _committed());
    _previous = _text.value;
    _text.addListener(_edit);
    _focus.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (_scope?.controller != scope.controller ||
        _scope?.registrationOwner != scope.registrationOwner) {
      _unsubscribe?.call();
      _unregister?.call();
      _unsubscribe = scope.controller.listen(widget.id, () {
        if (mounted) {
          _sync();
          setState(() {});
        }
      });
      _unregister = scope.registerFocus(widget.id, _focus, context);
    }
    _scope = scope;
    _sync();
  }

  @override
  void didUpdateWidget(GenUiTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_scope == null || !_scope!.controller.surface.accepts(widget.token)) {
      return;
    }
    final draft = _scope!.controller.draft(widget.id);
    final current =
        _scope!.controller.surface.nodes[widget.id]?.properties['bind'];
    final value =
        draft?.text ??
        (current == null
            ? ''
            : _number
            ? genUiNumber(current as num)
            : current as String);
    if (_text.text == value) return;
    _syncing = true;
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _previous = _text.value;
    _syncing = false;
  }

  void _edit() {
    final value = _text.value;
    final previous = _previous;
    _previous = value;
    if (_syncing || !mounted || _scope == null || _scope!.readOnly) return;
    if (previous?.text == value.text &&
        previous?.composing == value.composing) {
      return;
    }
    _scope!.controller.editText(
      widget.id,
      UiFieldDraft(
        value.text,
        composing: value.composing.isValid && !value.composing.isCollapsed,
      ),
      token: widget.token,
    );
  }

  void _focusChanged() {
    if (!mounted || _scope == null) return;
    setState(() {});
    if (_scope!.readOnly) return;
    if (_focus.hasFocus) {
      _scope!.controller.surface.noteInteraction(token: widget.token);
    } else {
      // A user leaving the field ends composition; never clear it during typing.
      if (!_text.value.composing.isCollapsed) _text.clearComposing();
      _scope!.controller.editText(
        widget.id,
        UiFieldDraft(_text.text),
        token: widget.token,
        finish: true,
      );
    }
  }

  void _step(int direction) {
    final scope = _scope!;
    if (scope.readOnly || !scope.controller.surface.accepts(widget.token)) {
      return;
    }
    final min = props['min'] as num?;
    final max = props['max'] as num?;
    num value = uiNumericStep(
      props['bind'] as num? ?? min ?? 0,
      props['step'] as num,
      direction,
    );
    if (min != null && value < min) value = min;
    if (max != null && value > max) value = max;
    if (value.isFinite) {
      scope.controller.setValue(widget.id, value, token: widget.token);
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unregister?.call();
    final controller = _scope?.controller;
    final token = widget.token;
    final draft = controller?.draft(widget.id);
    if (draft?.composing == true) {
      final id = widget.id;
      // A conditional field can unmount before the platform emits its final
      // composition update. Finish only the retained draft after this tree has
      // settled; inputs still require an active edit or an explicit submit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller!.endComposition(id, draft!, token: token);
      });
    }
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _text.removeListener(_edit);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope!;
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = props['label'] as String;
    final multiline = !_number && props['multiline'] == true;
    final enabled = scope.controller.tree.enabled[widget.id] == true;
    final issue = scope.controller.issue(widget.id);
    final error = issue == null ? null : genUiFieldIssueMessage(l10n, issue);
    final min = props['min'] as num?, max = props['max'] as num?;
    final range = min != null && max != null
        ? l10n.genuiNumberRange(genUiNumber(min), genUiNumber(max))
        : min != null
        ? l10n.genuiNumberMinimum(genUiNumber(min))
        : max != null
        ? l10n.genuiNumberMaximum(genUiNumber(max))
        : null;
    final value = props['bind'];
    return GenUiFieldFrame(
      label: label,
      requiredField: props['required'] == true,
      error: error,
      helper: range,
      counter: multiline
          ? l10n.genuiCharacterCount(
              _text.text.runes.length,
              (props['maxLength'] as num).toInt(),
            )
          : null,
      child: Semantics(
        label: label,
        hint: [
          if (props['required'] == true) l10n.genuiFieldRequired,
          if (range != null) range,
          if (error != null) error,
        ].join('. '),
        readOnly: scope.readOnly,
        child: ExcludeFocus(
          excluding: scope.readOnly || !enabled,
          child: IgnorePointer(
            ignoring: scope.readOnly,
            child: GenUiControlRegion(
              child: IosFormTextField(
                label: '',
                compact: true,
                controller: _text,
                focusNode: _focus,
                inlineLabel: false,
                outerPadding: EdgeInsets.zero,
                enabled: enabled,
                readOnly: scope.readOnly,
                maxLines: multiline ? 6 : 1,
                minLines: multiline ? 2 : null,
                hintText: props['placeholder'] as String?,
                textStyle: theme.input.copyWith(
                  color: enabled ? theme.ink : theme.disabledInk,
                  fontFeatures: _number
                      ? const [FontFeature.tabularFigures()]
                      : null,
                ),
                textDirection: _number ? TextDirection.ltr : null,
                textAlign: TextAlign.start,
                keyboardType: _number
                    ? const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      )
                    : multiline
                    ? TextInputType.multiline
                    : TextInputType.text,
                textInputAction: multiline
                    ? TextInputAction.newline
                    : TextInputAction.done,
                autocorrect: !_number,
                enableSuggestions: !_number,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    8192,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.truncateAfterCompositionEnds,
                  ),
                ],
                fieldDecoration: theme.fieldDecoration(
                  focused: _focus.hasFocus,
                  invalid: error != null,
                ),
                onSubmitted: multiline
                    ? null
                    : (_) {
                        scope.controller.blur(widget.id, token: widget.token);
                        scope.submit(context, widget.id, token: widget.token);
                      },
                suffixIconConstraints: _number
                    ? const BoxConstraints(maxWidth: 144)
                    : null,
                suffix: _number
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (props['unit'] case final String unit)
                            Flexible(
                              child: Text(
                                unit,
                                style: theme.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          IosIconButton(
                            icon: LucideIcons.minus,
                            size: 16,
                            minSize: 44,
                            visualSize: 28,
                            tooltip: l10n.genuiDecrease(label),
                            color: theme.primary,
                            enabled:
                                enabled &&
                                (value is! num || min == null || value > min),
                            onTap: () => _step(-1),
                          ),
                          IosIconButton(
                            icon: LucideIcons.plus,
                            size: 16,
                            minSize: 44,
                            visualSize: 28,
                            tooltip: l10n.genuiIncrease(label),
                            color: theme.primary,
                            enabled:
                                enabled &&
                                (value is! num || max == null || value < max),
                            onTap: () => _step(1),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
