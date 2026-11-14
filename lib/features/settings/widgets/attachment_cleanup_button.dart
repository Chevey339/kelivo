import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/attachment_retention.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import 'custom_theme_widgets.dart';

class AttachmentCleanupButton extends StatefulWidget {
  const AttachmentCleanupButton({
    super.key,
    required this.onChanged,
    this.size = 20,
    this.minSize = 44,
  });
  final Future<void> Function() onChanged;
  final double size;
  final double minSize;

  @override
  State<AttachmentCleanupButton> createState() =>
      _AttachmentCleanupButtonState();
}

class _AttachmentCleanupButtonState extends State<AttachmentCleanupButton> {
  bool _saving = false;

  Future<void> _edit() async {
    final settings = context.read<SettingsProvider>();
    final chat = context.read<ChatService?>();
    final l10n = AppLocalizations.of(context)!;
    var immediate = settings.attachmentRetentionDays == 0;
    final controller = TextEditingController(
      text:
          '${immediate ? AttachmentRetention.defaultDays : settings.attachmentRetentionDays}',
    );
    int? selectedDays() {
      if (immediate) return 0;
      final value = int.tryParse(controller.text);
      return value != null && value > 0 && value <= AttachmentRetention.maxDays
          ? value
          : null;
    }

    int? result;
    try {
      result = await showAppDialog<int>(
        context,
        maxWidth: 420,
        waitForExit: true,
        child: StatefulBuilder(
          builder: (ctx, update) {
            final valid = selectedDays() != null;
            final cs = Theme.of(ctx).colorScheme;
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.storageAttachmentRetentionHint,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SegmentedTabs(
                            index: immediate ? 0 : 1,
                            tabs: [
                              SegmentedTab(
                                label:
                                    l10n.storageAttachmentRetentionImmediately,
                              ),
                              SegmentedTab(
                                label: l10n.storageAttachmentRetentionDelayed,
                              ),
                            ],
                            onChanged: (index) {
                              FocusScope.of(ctx).unfocus();
                              update(() => immediate = index == 0);
                            },
                          ),
                          if (!immediate) ...[
                            const SizedBox(height: 12),
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
                            if (!valid)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  l10n.storageAttachmentRetentionInvalidDays,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.error,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            l10n.storageAttachmentProtectedHint,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IosTextButton(
                                label: l10n.homePageCancel,
                                color: cs.onSurfaceVariant,
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                              const SizedBox(width: 12),
                              IosTileButton(
                                label: l10n.assistantEditEmojiDialogSave,
                                icon: Lucide.Check,
                                backgroundColor: cs.primary,
                                borderColor: Colors.transparent,
                                enabled: valid,
                                onTap: () {
                                  final value = selectedDays();
                                  if (value != null) {
                                    Navigator.of(ctx).pop(value);
                                  }
                                },
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
      controller.dispose();
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
    final l10n = AppLocalizations.of(context)!;
    return IosIconButton(
      key: const ValueKey('attachment-cleanup-settings'),
      icon: Lucide.Settings2,
      size: widget.size,
      minSize: widget.minSize,
      tooltip: l10n.storageAttachmentRetention,
      semanticLabel: l10n.storageAttachmentRetention,
      enabled: !_saving,
      onTap: _saving ? null : _edit,
    );
  }
}
