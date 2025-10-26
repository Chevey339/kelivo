import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';

Future<void> showImagePreviewSheet(BuildContext context, {required File file}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: _ImagePreviewSheet(file: file),
    ),
  );
}

class _ImagePreviewSheet extends StatefulWidget {
  const _ImagePreviewSheet({required this.file});
  final File file;

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  final DraggableScrollableController _ctrl = DraggableScrollableController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Rect _shareAnchorRect(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    } catch (_) {}
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    return Rect.fromCenter(center: center, width: 1, height: 1);
  }

  Future<void> _onShare(BuildContext context) async {
    final filename = widget.file.uri.pathSegments.isNotEmpty
        ? widget.file.uri.pathSegments.last
        : 'image.png';
    try {
      final result = await Share.shareXFiles(
        [XFile(widget.file.path, mimeType: 'image/png', name: filename)],
        sharePositionOrigin: _shareAnchorRect(context),
      );
      // Close only if sharing succeeds (when the platform reports it)
      if (result.status == ShareResultStatus.success && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final Uint8List bytes = await widget.file.readAsBytes();
      final name = 'kelivo-${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaverPlus.saveImage(bytes, quality: 100, name: name);
      bool success = false;
      if (result is Map) {
        final isSuccess = result['isSuccess'] == true || result['isSuccess'] == 1;
        final filePath = result['filePath'] ?? result['file_path'];
        success = isSuccess || (filePath is String && filePath.isNotEmpty);
      }
      if (success) {
        showAppSnackBar(
          context,
          message: l10n.imagePreviewSheetSaveSuccess,
          type: NotificationType.success,
        );
        // Auto-close the preview sheet after successful save
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        showAppSnackBar(
          context,
          message: l10n.imagePreviewSheetSaveFailed('unknown'),
          type: NotificationType.error,
        );
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.imagePreviewSheetSaveFailed('$e'),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      controller: _ctrl,
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.8,
      minChildSize: 0.4,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Stack(
          children: [
            // Scrollable image preview
            Positioned.fill(
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: sc,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Card(
                                  elevation: 0,
                                  color: cs.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: cs.outline.withOpacity(0.08)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: kIsWeb
                                      ? const SizedBox.shrink() // Web does not support Image.file
                                      : Image.file(
                                          widget.file,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                                const SizedBox(height: 80), // leave space for action bar overlap, outside the card
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom action bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -2)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      // Left small square share button (no ripple)
                      Builder(
                        builder: (btnCtx) => SizedBox(
                          width: 48,
                          height: 48,
                          child: IosCardPress(
                            onTap: () => _onShare(btnCtx),
                            borderRadius: BorderRadius.circular(12),
                            baseColor: cs.surface,
                            pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.10,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outline.withOpacity(0.25)),
                              ),
                              child: Center(
                                child: Icon(Lucide.MoreVertical, color: cs.onSurface.withOpacity(0.9)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right main save button (no ripple)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: IosCardPress(
                            onTap: _saving ? null : _onSave,
                            borderRadius: BorderRadius.circular(12),
                            baseColor: cs.primary,
                            pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _saving
                                      ? const SizedBox(
                                          key: ValueKey('saving'),
                                          width: 18,
                                          height: 18,
                                          child: CupertinoActivityIndicator(radius: 9),
                                        )
                                      : Row(
                                          key: const ValueKey('ready'),
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Lucide.Download, color: cs.onPrimary),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.imagePreviewSheetSaveImage,
                                              style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
