import 'package:flutter/material.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'genui_interactions.dart';
import 'genui_theme.dart';

class GenUiForm extends StatelessWidget {
  const GenUiForm({
    super.key,
    required this.id,
    required this.children,
    this.title,
  });
  final String id;
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title?.isNotEmpty == true) ...[
          Semantics(
            header: true,
            child: Text(title!, style: theme.sectionTitle),
          ),
          SizedBox(height: theme.sm),
        ],
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: theme.sm + theme.xxs / 2),
          children[i],
        ],
        _FormSummary(id: id),
      ],
    );
  }
}

class _FormSummary extends StatefulWidget {
  const _FormSummary({required this.id});
  final String id;
  @override
  State<_FormSummary> createState() => _FormSummaryState();
}

class _FormSummaryState extends State<_FormSummary> {
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe;
  Object? _summary;
  Object _read() {
    final i = _scope!.controller;
    if (!i.submitted(widget.id)) return false;
    final check = i.checkForm(widget.id);
    return (
      check.issues.length,
      check.unavailable.isNotEmpty,
      check.issues.any((e) => e.error == UiFieldError.composing),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller) {
      _unsubscribe?.call();
      _scope = scope;
      _unsubscribe = scope.controller.listen(widget.id, () {
        final next = _read();
        if (mounted && next != _summary) setState(() => _summary = next);
      });
    }
    _scope = scope;
    _summary = _read();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _summary;
    if (value is! (int, bool, bool) || value == (0, false, false)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = GenUiTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          value.$2
              ? l10n.genuiFormUnavailable
              : value.$3
              ? l10n.genuiFinishComposing
              : l10n.genuiFormErrorsLeft(value.$1),
          style: theme.caption.copyWith(color: theme.error),
        ),
      ),
    );
  }
}
