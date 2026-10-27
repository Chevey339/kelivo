import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_semantic_colors.dart';

enum TrailingKind { clear, eye, reset, lock, none }

class ProviderInputRow extends StatefulWidget {
  const ProviderInputRow({
    super.key,
    this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.enabled = true,
    this.helper,
    this.helperRich,
    this.errorText,
    this.trailing = TrailingKind.clear,
    this.mono = false,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
    this.onTrailingTap,
    this.desktop = false,
    this.onSubmitted,
  });

  final String? label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool enabled;
  final String? helper;
  final Widget? helperRich;
  final String? errorText;
  final TrailingKind trailing;
  final bool mono;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTrailingTap;
  final ValueChanged<String>? onSubmitted;
  final bool desktop;

  @override
  State<ProviderInputRow> createState() => _ProviderInputRowState();
}

class _ProviderInputRowState extends State<ProviderInputRow>
    with WidgetsBindingObserver {
  late final FocusNode _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  final _rowKey = GlobalKey();
  final _helperKey = GlobalKey();
  double _helperHeight = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ProviderInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus).removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    _ensureVisible();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    _refresh();
    _ensureVisible();
  }

  @override
  void didChangeMetrics() => _ensureVisible();

  void _ensureVisible() {
    if (widget.desktop || !_focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      final helper = _helperKey.currentContext?.findRenderObject();
      final height = helper is RenderBox && helper.hasSize
          ? helper.size.height
          : 0.0;
      if (height != _helperHeight) setState(() => _helperHeight = height);
      final rowContext = _rowKey.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 1,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus.dispose();
    widget.controller.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasError = widget.errorText != null;
    final radius = BorderRadius.circular(widget.desktop ? 10 : 14);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
    Widget? suffix;
    if (!widget.enabled || widget.trailing == TrailingKind.lock) {
      suffix = Icon(
        Lucide.Lock,
        size: 16,
        color: cs.onSurface.withValues(alpha: 0.45),
      );
    } else if (widget.trailing == TrailingKind.eye) {
      suffix = IconButton(
        tooltip: widget.obscure
            ? l10n.providerDetailPageShowTooltip
            : l10n.providerDetailPageHideTooltip,
        onPressed: widget.onTrailingTap,
        icon: Icon(widget.obscure ? Lucide.Eye : Lucide.EyeOff, size: 18),
      );
    } else if (_focus.hasFocus &&
        widget.controller.text.isNotEmpty &&
        widget.trailing != TrailingKind.none) {
      suffix = IconButton(
        tooltip: l10n.providerDetailPageClearTooltip,
        onPressed: () {
          widget.controller.clear();
          widget.onChanged?.call('');
          _focus.requestFocus();
        },
        icon: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.onSurface.withValues(alpha: 0.28),
          ),
          child: Icon(Lucide.X, size: 12, color: cs.surface),
        ),
      );
    } else if (widget.trailing == TrailingKind.reset &&
        widget.controller.text.isEmpty) {
      suffix = IconButton(
        tooltip: l10n.providerDetailPageRestoreDefaultTooltip,
        onPressed: widget.onTrailingTap,
        icon: Icon(Lucide.RotateCcw, size: 18, color: cs.primary),
      );
    }
    final left = widget.desktop ? 2.0 : 12.0;
    return Column(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: EdgeInsets.only(left: left),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
                fontWeight: widget.desktop ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          scrollPadding: EdgeInsets.fromLTRB(20, 20, 20, 20 + _helperHeight),
          enabled: widget.enabled,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(
            fontSize: 14,
            fontFamily: widget.mono ? 'monospace' : null,
            color: cs.onSurface.withValues(alpha: widget.enabled ? 1 : 0.45),
          ),
          decoration: InputDecoration(
            isDense: widget.desktop,
            hintText: widget.hint,
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.32)),
            filled: true,
            fillColor: widget.desktop || !widget.enabled
                ? context.appColors.surfaceFill
                : context.appColors.surfaceCard,
            enabledBorder: border(
              hasError
                  ? cs.error
                  : cs.onSurface.withValues(alpha: widget.desktop ? 0.1 : 0.12),
              hasError ? 1.5 : (widget.desktop ? 0.6 : 1),
            ),
            disabledBorder: border(cs.onSurface.withValues(alpha: 0.12), 1),
            focusedBorder: border(
              hasError ? cs.error : cs.primary.withValues(alpha: 0.75),
              1.5,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.desktop ? 10 : 12,
            ),
            suffixIcon: suffix == null
                ? null
                : SizedBox(width: 36, height: 36, child: suffix),
            suffixIconColor: cs.onSurface.withValues(alpha: 0.55),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ),
        if (hasError || widget.helper != null || widget.helperRich != null)
          Padding(
            key: _helperKey,
            padding: EdgeInsets.only(left: left, right: left, top: 5),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              child: hasError
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Lucide.CircleAlert,
                            size: 13,
                            color: cs.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ],
                    )
                  : widget.helperRich ?? Text(widget.helper!),
            ),
          ),
      ],
    );
  }
}
