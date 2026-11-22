import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/translation_language.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../settings/widgets/custom_theme_widgets.dart';
import '../../settings/widgets/language_select_sheet.dart';

class TranslationLanguagesButton extends StatelessWidget {
  const TranslationLanguagesButton({
    super.key,
    required this.enabled,
    this.minSize,
  });

  final bool enabled;
  final double? minSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IosIconButton(
      icon: Lucide.ListChecks,
      minSize: minSize,
      tooltip: l10n.translationLanguageManagerTitle,
      enabled: enabled,
      onTap: () => showAppDialog<void>(
        context,
        child: _TranslationLanguagesDialog(
          settings: context.read<SettingsProvider>(),
        ),
      ),
    );
  }
}

class _TranslationLanguagesDialog extends StatefulWidget {
  const _TranslationLanguagesDialog({required this.settings});

  final SettingsProvider settings;

  @override
  State<_TranslationLanguagesDialog> createState() =>
      _TranslationLanguagesDialogState();
}

class _TranslationLanguagesDialogState
    extends State<_TranslationLanguagesDialog> {
  late final _selected = widget.settings.visibleTranslationLanguages.toList();
  bool _saving = false;
  bool _saveFailed = false;

  Future<void> _save() async {
    if (_saving || _selected.isEmpty) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.settings.setVisibleTranslationLanguages(
        _selected.map((language) => language.code),
      );
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      } else {
        setState(() => _saving = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final language = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, language);
    });
  }

  Widget _row(LanguageOption language, {int? index}) {
    final l10n = AppLocalizations.of(context)!;
    final label = languageDisplayName(l10n, language.code);
    return Padding(
      key: ValueKey(language.code),
      padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
      child: Row(
        children: [
          IosCheckbox(
            value: index != null,
            hitTestSize: 44,
            semanticLabel: label,
            onChanged: _saving
                ? null
                : (visible) => setState(() {
                    if (visible) {
                      _selected.add(language);
                    } else {
                      _selected.remove(language);
                    }
                  }),
          ),
          Text(language.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (index != null)
            ReorderableDragStartListener(
              index: index,
              enabled: !_saving,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(Lucide.GripVertical, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final status = _selected.isEmpty
        ? l10n.translationLanguageManagerKeepOne
        : _saveFailed
        ? l10n.translationLanguageManagerSaveFailed
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogHeader(title: l10n.translationLanguageManagerTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.translationLanguageManagerHint,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            itemCount: _selected.length,
            itemBuilder: (context, index) =>
                _row(_selected[index], index: index),
            onReorderItem: _reorder,
            footer: Column(
              children: [
                for (final language in supportedLanguages)
                  if (!_selected.contains(language)) _row(language),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(status, style: TextStyle(color: cs.error)),
                ),
              IosTileButton(
                icon: Lucide.Check,
                label: MaterialLocalizations.of(context).saveButtonLabel,
                enabled: !_saving && _selected.isNotEmpty,
                onTap: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
