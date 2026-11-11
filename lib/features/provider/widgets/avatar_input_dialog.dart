import 'package:flutter/material.dart';

import '../../../core/models/avatar_config.dart';
import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../utils/brand_assets.dart';

Future<AvatarConfig?> showAvatarInputDialog(
  BuildContext context, {
  required AvatarType type,
  required bool desktop,
  AvatarConfig? initial,
  String keyPrefix = 'avatar-input',
}) => showDialog<AvatarConfig>(
  context: context,
  builder: (_) => _AvatarInputDialog(
    type: type,
    initial: initial,
    desktop: desktop,
    keyPrefix: keyPrefix,
  ),
);

class _AvatarInputDialog extends StatefulWidget {
  const _AvatarInputDialog({
    required this.type,
    required this.desktop,
    required this.keyPrefix,
    this.initial,
  });
  final AvatarType type;
  final bool desktop;
  final String keyPrefix;
  final AvatarConfig? initial;

  @override
  State<_AvatarInputDialog> createState() => _AvatarInputDialogState();
}

class _AvatarInputDialogState extends State<_AvatarInputDialog> {
  late final _text = TextEditingController(
    text: widget.initial?.type == widget.type ? widget.initial!.value : '',
  );
  late bool _monochrome = widget.initial?.monochrome ?? false;
  bool _invalid = false;
  bool get _lobehub => widget.type == AvatarType.lobehub;

  bool get _valid {
    final value = _text.text.trim();
    if (_lobehub) return BrandAssets.lobehubIconUrls(value).isNotEmpty;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _submit() {
    if (!_valid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(
      AvatarConfig(
        type: widget.type,
        value: _lobehub ? _text.text.trim().toLowerCase() : _text.text.trim(),
        monochrome: _lobehub && _monochrome,
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DesktopFormDialog(
        key: ValueKey('${widget.keyPrefix}-dialog'),
        constraints: BoxConstraints(maxWidth: widget.desktop ? 420 : 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesktopFormDialogHeader(
                title: _lobehub
                    ? l10n.providerAvatarLobehubDialogTitle
                    : l10n.sideDrawerImageUrlDialogTitle,
                closeTooltip: l10n.sideDrawerCancel,
                onClose: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    IosFormTextField(
                      key: ValueKey('${widget.keyPrefix}-field'),
                      label: '',
                      controller: _text,
                      inlineLabel: false,
                      outerPadding: EdgeInsets.zero,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      hintText: _lobehub
                          ? l10n.providerAvatarLobehubDialogHint
                          : l10n.sideDrawerImageUrlDialogHint,
                      onChanged: (_) => setState(() => _invalid = false),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_invalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.avatarInputInvalid,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_lobehub) ...[
                      const SizedBox(height: 12),
                      SegmentedTabs(
                        tabs: [
                          SegmentedTab(label: l10n.avatarColor),
                          SegmentedTab(label: l10n.avatarMonochrome),
                        ],
                        index: _monochrome ? 1 : 0,
                        onChanged: (index) =>
                            setState(() => _monochrome = index == 1),
                      ),
                    ],
                  ],
                ),
              ),
              DesktopFormDialogFooter(
                primaryLabel: l10n.sideDrawerSave,
                primaryKey: ValueKey('${widget.keyPrefix}-save'),
                onPrimary: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
