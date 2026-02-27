part of 'assistant_settings_edit_page.dart';

class _CustomRequestTab extends StatelessWidget {
  const _CustomRequestTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;

    Widget card({required Widget child}) => Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        20,
        8,
      ), // Increased right padding
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          boxShadow: isDark ? [] : AppShadows.soft,
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );

    void addHeader() {
      final list = List<Map<String, String>>.of(a.customHeaders);
      list.add({'name': '', 'value': ''});
      context.read<AssistantProvider>().updateAssistant(
        a.copyWith(customHeaders: list),
      );
    }

    void removeHeader(int index) {
      final list = List<Map<String, String>>.of(a.customHeaders);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customHeaders: list),
        );
      }
    }

    void updateHeader(int index, {String? name, String? value}) {
      final list = List<Map<String, String>>.of(a.customHeaders);
      if (index >= 0 && index < list.length) {
        final cur = Map<String, String>.from(list[index]);
        if (name != null) cur['name'] = name;
        if (value != null) cur['value'] = value;
        list[index] = cur;
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customHeaders: list),
        );
      }
    }

    void addBody() {
      final list = List<Map<String, String>>.of(a.customBody);
      list.add({'key': '', 'value': ''});
      context.read<AssistantProvider>().updateAssistant(
        a.copyWith(customBody: list),
      );
    }

    void removeBody(int index) {
      final list = List<Map<String, String>>.of(a.customBody);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customBody: list),
        );
      }
    }

    void updateBody(int index, {String? key, String? value}) {
      final list = List<Map<String, String>>.of(a.customBody);
      if (index >= 0 && index < list.length) {
        final cur = Map<String, String>.from(list[index]);
        if (key != null) cur['key'] = key;
        if (value != null) cur['value'] = value;
        list[index] = cur;
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customBody: list),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16), // Reduced top padding
      children: [
        // Headers
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.assistantEditCustomHeadersTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TactileRow(
                      onTap: addHeader,
                      pressedScale: 0.97,
                      builder: (pressed) {
                        final color = pressed
                            ? cs.primary.withOpacity(0.7)
                            : cs.primary;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Lucide.Plus, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              l10n.assistantEditCustomHeadersAdd,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < a.customHeaders.length; i++) ...[
                _HeaderRow(
                  index: i,
                  name: a.customHeaders[i]['name'] ?? '',
                  value: a.customHeaders[i]['value'] ?? '',
                  onChanged: (k, v) => updateHeader(i, name: k, value: v),
                  onDelete: () => removeHeader(i),
                ),
                const SizedBox(height: 10),
              ],
              if (a.customHeaders.isEmpty)
                Text(
                  l10n.assistantEditCustomHeadersEmpty,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),

        // Body
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.assistantEditCustomBodyTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TactileRow(
                      onTap: addBody,
                      pressedScale: 0.97,
                      builder: (pressed) {
                        final color = pressed
                            ? cs.primary.withOpacity(0.7)
                            : cs.primary;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Lucide.Plus, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              l10n.assistantEditCustomBodyAdd,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < a.customBody.length; i++) ...[
                _BodyRow(
                  index: i,
                  keyName: a.customBody[i]['key'] ?? '',
                  value: a.customBody[i]['value'] ?? '',
                  onChanged: (k, v) => updateBody(i, key: k, value: v),
                  onDelete: () => removeBody(i),
                ),
                const SizedBox(height: 10),
              ],
              if (a.customBody.isEmpty)
                Text(
                  l10n.assistantEditCustomBodyEmpty,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    required this.index,
    required this.name,
    required this.value,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final String name;
  final String value;
  final void Function(String name, String value) onChanged;
  final VoidCallback onDelete;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valCtrl;
  late final FocusNode _nameFocus;
  late final FocusNode _valFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _valCtrl = TextEditingController(text: widget.value);
    _nameFocus = FocusNode();
    _valFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _HeaderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Avoid resetting controller text while the field is focused to prevent cursor jump.
    if (oldWidget.name != widget.name && !_nameFocus.hasFocus) {
      _nameCtrl.text = widget.name;
    }
    if (oldWidget.value != widget.value && !_valFocus.hasFocus) {
      _valCtrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    _nameFocus.dispose();
    _valFocus.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                decoration: _dec(context, l10n.assistantEditHeaderNameLabel),
                onChanged: (v) => widget.onChanged(v, _valCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            _TactileIconButton(
              icon: Lucide.Trash2,
              color: cs.error,
              size: 20,
              onTap: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valCtrl,
          focusNode: _valFocus,
          decoration: _dec(context, l10n.assistantEditHeaderValueLabel),
          onChanged: (v) => widget.onChanged(_nameCtrl.text, v),
        ),
      ],
    );
  }
}

class _BodyRow extends StatefulWidget {
  const _BodyRow({
    required this.index,
    required this.keyName,
    required this.value,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final String keyName;
  final String value;
  final void Function(String key, String value) onChanged;
  final VoidCallback onDelete;

  @override
  State<_BodyRow> createState() => _BodyRowState();
}

class _BodyRowState extends State<_BodyRow> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;
  late final FocusNode _keyFocus;
  late final FocusNode _valFocus;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.keyName);
    _valCtrl = TextEditingController(text: widget.value);
    _keyFocus = FocusNode();
    _valFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _BodyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Avoid resetting controller text while the field is focused to prevent cursor jump.
    if (oldWidget.keyName != widget.keyName && !_keyFocus.hasFocus) {
      _keyCtrl.text = widget.keyName;
    }
    if (oldWidget.value != widget.value && !_valFocus.hasFocus) {
      _valCtrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    _keyFocus.dispose();
    _valFocus.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
      ),
      alignLabelWithHint: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyCtrl,
                focusNode: _keyFocus,
                decoration: _dec(context, l10n.assistantEditBodyKeyLabel),
                onChanged: (v) => widget.onChanged(v, _valCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            _TactileIconButton(
              icon: Lucide.Trash2,
              color: cs.error,
              size: 20,
              onTap: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valCtrl,
          focusNode: _valFocus,
          minLines: 3,
          maxLines: 6,
          decoration: _dec(context, l10n.assistantEditBodyValueLabel),
          onChanged: (v) => widget.onChanged(_keyCtrl.text, v),
        ),
      ],
    );
  }
}
