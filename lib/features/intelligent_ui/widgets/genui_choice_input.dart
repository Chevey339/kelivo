import 'genui_control_region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'genui_segments.dart';
import 'genui_field_frame.dart';
import 'genui_interactions.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

class GenUiChoiceInput extends StatefulWidget {
  const GenUiChoiceInput({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiChoiceInput> createState() => _GenUiChoiceInputState();
}

class _GenUiChoiceInputState extends State<GenUiChoiceInput> {
  final _focus = FocusNode();
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _unregister;
  bool _open = false;
  ModalRoute<DesktopSelectOption<Object?>>? _sheetRoute;
  bool get _enabled =>
      _scope!.controller.surface.accepts(widget.token) &&
      _scope!.controller.tree.enabled[widget.id] == true;
  bool get _interactive => _enabled && !_scope!.readOnly;
  Map<String, Object?> get _props =>
      _scope?.controller.surface.nodes[widget.id]?.properties ??
      widget.node.properties;
  List<DesktopSelectOption<Object?>> get _options => [
    for (final entry in _props['options'] as List)
      DesktopSelectOption(
        value: (entry as Map)['value'],
        label: entry['label'] as String,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _scope?.controller.surface.noteInteraction(token: widget.token);
    }
    if (mounted) setState(() {});
  }

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

  @override
  void dispose() {
    _unsubscribe?.call();
    _unregister?.call();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    final route = _sheetRoute;
    final navigator = route?.navigator;
    if (route != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
    super.dispose();
  }

  void _set(Object? value) {
    if (!mounted || !_interactive) return;
    _scope!.controller.setValue(widget.id, value, token: widget.token);
  }

  Future<void> _showChoices() async {
    if (!_interactive || _open) return;
    final options = _options;
    final token = widget.token;
    final label = _props['label'] as String;
    final value = _props['bind'];
    _scope!.controller.surface.noteInteraction(token: token);
    setState(() => _open = true);
    final selected = await showFormSheet<DesktopSelectOption<Object?>>(
      context,
      builder: (context) {
        _sheetRoute = ModalRoute.of<DesktopSelectOption<Object?>>(context);
        return GenUiThemeScope(
          child: _ChoiceSheet(label: label, options: options, value: value),
        );
      },
    );
    _sheetRoute = null;
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null && _interactive) {
      _scope!.controller.setValue(widget.id, selected.value, token: token);
    }
    _focus.requestFocus();
  }

  KeyEventResult _radioKey(FocusNode _, KeyEvent event) {
    if (!_interactive || event is KeyUpEvent) return KeyEventResult.ignored;
    final options = _options;
    if (options.isEmpty) return KeyEventResult.ignored;
    final index = options.indexWhere((o) => o.value == _props['bind']);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    int move(int direction) => index < 0
        ? (direction < 0 ? options.length - 1 : 0)
        : index + direction;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => move(rtl ? 1 : -1),
      LogicalKeyboardKey.arrowRight => move(rtl ? -1 : 1),
      LogicalKeyboardKey.arrowDown => move(1),
      LogicalKeyboardKey.arrowUp => move(-1),
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => options.length - 1,
      LogicalKeyboardKey.space ||
      LogicalKeyboardKey.enter => index < 0 ? 0 : index,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    _set(options[next % options.length].value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = _props['label'] as String;
    final options = _options;
    final selectedIndex = options.indexWhere((o) => o.value == _props['bind']);
    final selectedLabel = selectedIndex < 0
        ? (_props['placeholder'] as String? ?? l10n.genuiChooseOption)
        : options[selectedIndex].label;
    final issue = _scope!.controller.issue(widget.id);
    final error = issue == null ? null : genUiFieldIssueMessage(l10n, issue);
    final hint = [
      if (_props['required'] == true) l10n.genuiFieldRequired,
      if (error != null) error,
    ].join('. ');
    final decoration = theme.fieldDecoration(
      focused: _focus.hasFocus,
      invalid: error != null,
    );
    Widget control;
    if (widget.node.declaration.component == 'RadioGroup') {
      control = Focus(
        focusNode: _focus,
        canRequestFocus: _interactive,
        onKeyEvent: _radioKey,
        child: Semantics(
          label: label,
          value: selectedIndex < 0 ? null : selectedLabel,
          hint: hint,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              var longest = 0.0;
              var singleLine = true;
              for (final option in options) {
                final painter = TextPainter(
                  text: TextSpan(text: option.label, style: theme.header),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                )..layout();
                if (painter.computeLineMetrics().length > 1) singleLine = false;
                if (painter.width > longest) longest = painter.width;
                painter.dispose();
              }
              final segments =
                  singleLine &&
                  options.isNotEmpty &&
                  options.length <= 4 &&
                  scaler.scale(1) < 1.3 &&
                  (longest + 24) * options.length +
                          8 +
                          6 * (options.length - 1) <=
                      constraints.maxWidth;
              return segments
                  ? GenUiSegments(
                      labels: [for (final option in options) option.label],
                      index: selectedIndex,
                      onChanged: (index) {
                        _focus.requestFocus();
                        _set(options[index].value);
                      },
                      enabled: _interactive,
                      radioGroup: true,
                      visualEnabled: _enabled,
                      expand: true,
                      focused: _focus.hasFocus,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < options.length; i++)
                          _ChoiceRow(
                            label: options[i].label,
                            selected: i == selectedIndex,
                            enabled: _enabled,
                            interactive: _interactive,
                            onTap: () {
                              _focus.requestFocus();
                              _set(options[i].value);
                            },
                          ),
                      ],
                    );
            },
          ),
        ),
      );
    } else {
      final desktop =
          ResponsiveHelper.isDesktop(context) ||
          const {
            TargetPlatform.macOS,
            TargetPlatform.windows,
            TargetPlatform.linux,
          }.contains(defaultTargetPlatform);
      if (desktop) {
        control = GenUiFieldSurface(
          decoration: decoration,
          child: DesktopSelectDropdown<Object?>(
            value: _props['bind'],
            options: options,
            onSelected: _set,
            enabled: _interactive,
            focusNode: _focus,
            placeholder: selectedLabel,
            semanticLabel: label,
            semanticHint: hint,
            minHeight: 44,
            maxLabelWidth: double.infinity,
            embedded: true,
            triggerFillColor: theme.transparent,
            triggerForegroundColor: theme.ink,
            menuBackgroundColor: theme.popover,
          ),
        );
      } else {
        control = FocusableActionDetector(
          focusNode: _focus,
          enabled: _interactive,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _showChoices();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            label: label,
            value: selectedLabel,
            hint: hint,
            enabled: _interactive,
            expanded: _open,
            onTap: _interactive ? _showChoices : null,
            child: ExcludeSemantics(
              child: IosCardPress(
                onTap: _interactive ? _showChoices : null,
                haptics: false,
                baseColor: theme.transparent,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: GenUiFieldSurface(
                  decoration: decoration,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.sm,
                      vertical: theme.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedLabel,
                            style: theme.input.copyWith(
                              color: !_enabled
                                  ? theme.disabledInk
                                  : selectedIndex < 0
                                  ? theme.captionInk
                                  : theme.ink,
                            ),
                          ),
                        ),
                        SizedBox(width: theme.xs),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: theme.captionInk,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return GenUiFieldFrame(
      label: label,
      requiredField: _props['required'] == true,
      error: error,
      child: GenUiControlRegion(child: control),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.interactive,
    required this.onTap,
    this.focused = false,
  });
  final String label;
  final bool selected, enabled, interactive, focused;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Semantics(
      label: label,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: interactive,
      onTap: interactive ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? onTap : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.controlRadius),
              border: Border.all(
                color: focused ? theme.primary : theme.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                IgnorePointer(
                  child: IosCheckbox(
                    value: selected,
                    onChanged: enabled ? (_) {} : null,
                    activeColor: theme.primary,
                    checkmarkColor: theme.onPrimary,
                    borderColor: theme.hairlineStrong,
                    hitTestSize: 44,
                    enableHaptics: false,
                  ),
                ),
                SizedBox(width: theme.xs),
                Expanded(
                  child: Text(
                    label,
                    style: theme.body.copyWith(
                      color: enabled ? theme.ink : theme.disabledInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.label,
    required this.options,
    required this.value,
  });
  final String label;
  final List<DesktopSelectOption<Object?>> options;
  final Object? value;
  @override
  Widget build(BuildContext context) => FocusScope(
    onKeyEvent: (node, event) {
      if (event is KeyUpEvent) return KeyEventResult.ignored;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
          Navigator.pop(context);
        case LogicalKeyboardKey.arrowDown:
          node.nextFocus();
        case LogicalKeyboardKey.arrowUp:
          node.previousFocus();
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    },
    child: FormSheet(
      title: label,
      actions: IosTextButton(
        label: AppLocalizations.of(context)!.homePageCancel,
        onPressed: () => Navigator.pop(context),
      ),
      children: [
        for (var i = 0; i < options.length; i++)
          _ChoiceSheetRow(
            option: options[i],
            selected: options[i].value == value,
            autofocus:
                options[i].value == value ||
                (i == 0 && !options.any((o) => o.value == value)),
          ),
      ],
    ),
  );
}

class _ChoiceSheetRow extends StatefulWidget {
  const _ChoiceSheetRow({
    required this.option,
    required this.selected,
    required this.autofocus,
  });
  final DesktopSelectOption<Object?> option;
  final bool selected, autofocus;
  @override
  State<_ChoiceSheetRow> createState() => _ChoiceSheetRowState();
}

class _ChoiceSheetRowState extends State<_ChoiceSheetRow> {
  bool _focused = false;
  void _select() => Navigator.pop(context, widget.option);
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: widget.autofocus,
    onShowFocusHighlight: (value) => setState(() => _focused = value),
    onFocusChange: (focused) {
      if (focused) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Scrollable.ensureVisible(context, alignment: .5);
        });
      }
    },
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          _select();
          return null;
        },
      ),
    },
    child: _ChoiceRow(
      label: widget.option.label,
      selected: widget.selected,
      enabled: true,
      interactive: true,
      focused: _focused,
      onTap: _select,
    ),
  );
}
