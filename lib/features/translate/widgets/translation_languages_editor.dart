import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/translation_language.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../settings/widgets/language_select_sheet.dart';

class TranslationLanguagesEditor extends StatefulWidget {
  const TranslationLanguagesEditor({
    super.key,
    required this.onSaved,
    required this.builder,
    this.compact = false,
  });

  final VoidCallback onSaved;
  final bool compact;
  final Widget Function(BuildContext context, Widget body, VoidCallback? onSave)
  builder;

  @override
  State<TranslationLanguagesEditor> createState() =>
      _TranslationLanguagesEditorState();
}

class _TranslationLanguagesEditorState
    extends State<TranslationLanguagesEditor> {
  late final _settings = context.read<SettingsProvider>();
  late final _selected = _settings.visibleTranslationLanguages.toList();
  bool _saving = false;
  bool _saveFailed = false;

  bool get _canSave => !_saving && _selected.isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await _settings.setVisibleTranslationLanguages(
        _selected.map((language) => language.code),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() => _selected.insert(newIndex, _selected.removeAt(oldIndex)));
  }

  Widget _row(LanguageOption language, {int? index, required bool last}) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final visible = index != null;
    final label = languageDisplayName(l10n, language.code);
    final compact = widget.compact;

    void toggle(bool enabled) {
      if (_saving || enabled == _selected.contains(language)) return;
      setState(() {
        if (enabled) {
          _selected.add(language);
        } else {
          _selected.remove(language);
        }
      });
    }

    return Column(
      key: ValueKey(language.code),
      children: [
        Row(
          children: [
            Expanded(
              child: IosNavRow(
                leading: ExcludeSemantics(
                  child: Text(
                    language.flag,
                    style: TextStyle(fontSize: compact ? 16 : 18),
                  ),
                ),
                label: label,
                labelMaxLines: 2,
                padding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: compact ? 8 : 12,
                ),
                focusable: true,
                onTap: _saving ? null : () => toggle(!visible),
                trailing: const SizedBox.shrink(),
              ),
            ),
            if (index != null)
              ReorderableDragStartListener(
                index: index,
                enabled: !_saving,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox(
                    width: 32,
                    height: compact ? 36 : 44,
                    child: Icon(
                      Lucide.GripVertical,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            IosSwitch(
              value: visible,
              onChanged: _saving ? null : toggle,
              semanticLabel: label,
              width: compact ? 34 : 38,
              height: compact ? 20 : 22,
              hitTestSize: compact ? 36 : 44,
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (!last) const IosRowDivider(indent: 52),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final hidden = supportedLanguages
        .where((language) => !_selected.contains(language))
        .toList();
    final status = _selected.isEmpty
        ? l10n.translationLanguageManagerKeepOne
        : _saveFailed
        ? l10n.translationLanguageManagerSaveFailed
        : null;

    return widget.builder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosSectionFooter(
                text: l10n.translationLanguageManagerHint,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Text(
                status,
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),
          Flexible(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              primary: false,
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => ColoredBox(
                color: context.appColors.surfaceCard,
                child: child,
              ),
              header: _selected.isEmpty
                  ? null
                  : IosSectionHeader(
                      text: l10n.translationLanguageManagerShown,
                      first: true,
                    ),
              itemCount: _selected.length,
              itemBuilder: (context, index) => _row(
                _selected[index],
                index: index,
                last: index == _selected.length - 1,
              ),
              onReorderItem: _reorder,
              footer: hidden.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IosSectionHeader(
                          text: l10n.translationLanguageManagerHidden,
                        ),
                        for (var index = 0; index < hidden.length; index++)
                          _row(hidden[index], last: index == hidden.length - 1),
                      ],
                    ),
            ),
          ),
        ],
      ),
      _canSave ? _save : null,
    );
  }
}
