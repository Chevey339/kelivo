import 'dart:async';

import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

typedef ProviderRequestRowsChanged =
    Future<void> Function(List<Map<String, String>> rows);

class ProviderCustomRequestEditor extends StatelessWidget {
  const ProviderCustomRequestEditor({
    super.key,
    required this.headers,
    required this.body,
    required this.onHeadersChanged,
    required this.onBodyChanged,
    this.showHeader = true,
    this.showSectionTitles = true,
    this.showHeadersSection = true,
    this.showBodySection = true,
  });

  final List<Map<String, String>> headers;
  final List<Map<String, String>> body;
  final ProviderRequestRowsChanged onHeadersChanged;
  final ProviderRequestRowsChanged onBodyChanged;
  final bool showHeader;
  final bool showSectionTitles;
  final bool showHeadersSection;
  final bool showBodySection;

  void _addHeader() {
    unawaited(
      onHeadersChanged([
        ...headers.map(Map<String, String>.from),
        <String, String>{'name': '', 'value': ''},
      ]),
    );
  }

  void _addBody() {
    unawaited(
      onBodyChanged([
        ...body.map(Map<String, String>.from),
        <String, String>{'key': '', 'value': ''},
      ]),
    );
  }

  void _updateHeader(int index, String name, String value) {
    final rows = headers.map(Map<String, String>.from).toList();
    rows[index] = <String, String>{'name': name, 'value': value};
    unawaited(onHeadersChanged(rows));
  }

  void _updateBody(int index, String key, String value) {
    final rows = body.map(Map<String, String>.from).toList();
    rows[index] = <String, String>{'key': key, 'value': value};
    unawaited(onBodyChanged(rows));
  }

  void _removeHeader(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final rows = headers.map(Map<String, String>.from).toList()
      ..removeAt(index);
    unawaited(onHeadersChanged(rows));
  }

  void _removeBody(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final rows = body.map(Map<String, String>.from).toList()..removeAt(index);
    unawaited(onBodyChanged(rows));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('provider-custom-request-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(
            l10n.providerDetailPageCustomRequestTitle,
            style: TextStyle(fontSize: 14, fontWeight: AppFontWeights.semibold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.providerDetailPageCustomRequestDescription,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (showHeadersSection)
          _RequestSection(
            title: showSectionTitles
                ? l10n.modelDetailSheetCustomHeadersTitle
                : null,
            addLabel: l10n.modelDetailSheetAddHeader,
            addKey: const ValueKey('provider-custom-header-add'),
            onAdd: _addHeader,
            children: [
              for (var i = 0; i < headers.length; i++)
                _RequestRow(
                  key: ValueKey('provider-custom-header-row-$i'),
                  index: i,
                  fieldPrefix: 'header',
                  name: headers[i]['name'] ?? '',
                  value: headers[i]['value'] ?? '',
                  nameHint: l10n.modelDetailSheetHeaderKeyHint,
                  valueHint: l10n.modelDetailSheetHeaderValueHint,
                  onChanged: (name, value) => _updateHeader(i, name, value),
                  onDelete: () => _removeHeader(i),
                ),
            ],
          ),
        if (showHeadersSection && showBodySection) const SizedBox(height: 12),
        if (showBodySection)
          _RequestSection(
            title: showSectionTitles
                ? l10n.modelDetailSheetCustomBodyTitle
                : null,
            addLabel: l10n.modelDetailSheetAddBody,
            addKey: const ValueKey('provider-custom-body-add'),
            onAdd: _addBody,
            children: [
              for (var i = 0; i < body.length; i++)
                _RequestRow(
                  key: ValueKey('provider-custom-body-row-$i'),
                  index: i,
                  fieldPrefix: 'body',
                  name: body[i]['key'] ?? '',
                  value: body[i]['value'] ?? '',
                  nameHint: l10n.modelDetailSheetBodyKeyHint,
                  valueHint: l10n.modelDetailSheetBodyJsonHint,
                  multilineValue: true,
                  onChanged: (key, value) => _updateBody(i, key, value),
                  onDelete: () => _removeBody(i),
                ),
            ],
          ),
      ],
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.title,
    required this.addLabel,
    required this.addKey,
    required this.onAdd,
    required this.children,
  });

  final String? title;
  final String addLabel;
  final Key addKey;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 440 && title != null;
        final titleWidget = title == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              );
        final addButton = IosTileButton(
          key: addKey,
          label: addLabel,
          icon: Lucide.Plus,
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          onTap: onAdd,
        );

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: titleWidget!),
                  const SizedBox(width: 12),
                  addButton,
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...children,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titleWidget != null) ...[
              titleWidget,
              const SizedBox(height: 8),
            ],
            ...children,
            addButton,
          ],
        );
      },
    );
  }
}

class _RequestRow extends StatefulWidget {
  const _RequestRow({
    super.key,
    required this.index,
    required this.fieldPrefix,
    required this.name,
    required this.value,
    required this.nameHint,
    required this.valueHint,
    required this.onChanged,
    required this.onDelete,
    this.multilineValue = false,
  });

  final int index;
  final String fieldPrefix;
  final String name;
  final String value;
  final String nameHint;
  final String valueHint;
  final bool multilineValue;
  final void Function(String name, String value) onChanged;
  final VoidCallback onDelete;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final FocusNode _nameFocus;
  late final FocusNode _valueFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _valueController = TextEditingController(text: widget.value);
    _nameFocus = FocusNode();
    _valueFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _RequestRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && !_nameFocus.hasFocus) {
      _nameController.text = widget.name;
    }
    if (oldWidget.value != widget.value && !_valueFocus.hasFocus) {
      _valueController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _nameFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(_nameController.text, _valueController.text);
  }

  InputDecoration _decoration(BuildContext context, String hint) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: context.appColors.surfaceFill,
      hintStyle: TextStyle(
        fontSize: 14,
        color: cs.onSurface.withValues(alpha: 0.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.12),
          width: 0.6,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.12),
          width: 0.6,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deleteTooltip = MaterialLocalizations.of(context).deleteButtonTooltip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameField = TextField(
            key: ValueKey(
              'provider-custom-${widget.fieldPrefix}-name-${widget.index}',
            ),
            controller: _nameController,
            focusNode: _nameFocus,
            style: const TextStyle(fontSize: 14),
            decoration: _decoration(context, widget.nameHint),
            onChanged: (_) => _notifyChanged(),
          );
          final valueField = TextField(
            key: ValueKey(
              'provider-custom-${widget.fieldPrefix}-value-${widget.index}',
            ),
            controller: _valueController,
            focusNode: _valueFocus,
            style: const TextStyle(fontSize: 14),
            minLines: widget.multilineValue ? 2 : 1,
            maxLines: widget.multilineValue ? 5 : 1,
            decoration: _decoration(context, widget.valueHint),
            onChanged: (_) => _notifyChanged(),
          );
          final deleteButton = IosIconButton(
            key: ValueKey(
              'provider-custom-${widget.fieldPrefix}-delete-${widget.index}',
            ),
            icon: Lucide.Trash2,
            size: 18,
            minSize: 44,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.62),
            semanticLabel: deleteTooltip,
            onTap: widget.onDelete,
          );

          if (constraints.maxWidth >= 440) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: nameField),
                const SizedBox(width: 8),
                Expanded(flex: 6, child: valueField),
                const SizedBox(width: 4),
                deleteButton,
              ],
            );
          }

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nameField),
                  const SizedBox(width: 4),
                  deleteButton,
                ],
              ),
              const SizedBox(height: 8),
              valueField,
            ],
          );
        },
      ),
    );
  }
}
