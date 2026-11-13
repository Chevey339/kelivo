import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/attachment_retention.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import 'custom_theme_widgets.dart';

class AttachmentRetentionSetting extends StatefulWidget {
  const AttachmentRetentionSetting({super.key, required this.onChanged});
  final Future<void> Function() onChanged;

  @override
  State<AttachmentRetentionSetting> createState() =>
      _AttachmentRetentionSettingState();
}

class _AttachmentRetentionSettingState
    extends State<AttachmentRetentionSetting> {
  bool _saving = false;

  Future<void> _edit() async {
    final settings = context.read<SettingsProvider>();
    final chat = context.read<ChatService?>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: '${settings.attachmentRetentionDays}',
    );
    int? result;
    try {
      result = await showAppDialog<int>(
        context,
        maxWidth: 420,
        child: StatefulBuilder(
          builder: (ctx, update) {
            final value = int.tryParse(controller.text);
            final valid =
                value != null &&
                value >= 0 &&
                value <= AttachmentRetention.maxDays;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDialogHeader(title: l10n.storageAttachmentRetention),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IosFormTextField(
                            key: const ValueKey('attachment-retention-days'),
                            label: l10n.storageAttachmentRetentionDays,
                            controller: controller,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            selectAllOnFocus: true,
                            onChanged: (_) => update(() {}),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.storageAttachmentRetentionHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IosTileButton(
                                label: l10n.homePageCancel,
                                icon: Lucide.X,
                                onTap: () => Navigator.of(ctx).pop(),
                              ),
                              const SizedBox(width: 10),
                              IosTileButton(
                                label: l10n.assistantEditEmojiDialogSave,
                                icon: Lucide.Check,
                                enabled: valid,
                                onTap: () => Navigator.of(ctx).pop(value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await settings.setAttachmentRetentionDays(result);
      await chat?.runAssetMaintenance();
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.storageSpaceClearFailed('$error'),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = context.watch<SettingsProvider>().attachmentRetentionDays;
    final l10n = AppLocalizations.of(context)!;
    return SectionCard(
      child: IosNavRow(
        key: const ValueKey('attachment-retention-setting'),
        icon: Lucide.Timer,
        label: l10n.storageAttachmentRetention,
        subtitle: days == 0
            ? l10n.storageAttachmentRetentionImmediately
            : l10n.storageAttachmentRetentionAfterDays(days),
        onTap: _saving ? null : _edit,
      ),
    );
  }
}
